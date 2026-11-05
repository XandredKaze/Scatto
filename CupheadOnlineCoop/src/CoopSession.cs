using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Threading;
using CupheadOnlineCoop.Inputs;
using CupheadOnlineCoop.Net;
using CupheadOnlineCoop.Patches;
using CupheadOnlineCoop.Sync;
using Rewired;
using UnityEngine;

namespace CupheadOnlineCoop
{
    public enum NetMode { Off, Host, Client }

    internal sealed class CoopSettings
    {
        public NetMode Mode;
        public string HostAddress;
        public int Port;
        public int InputDelay;
        public int Player1RewiredId;
        public int Player2RewiredId;
        public int LocalDeviceRewiredId;
        public int StallTimeoutMs;
        public int SceneWaitTimeoutMs;
        public bool FixedTimestep;
        public bool Checksum;
        public int ChecksumInterval;
        public string ChecksumTypes;
        public bool SyncSave;
        public string SaveDirectory;
        public string SaveFilePattern;
        public int HostSaveSlot;
        public int ClientSaveSlot;
    }

    /// <summary>
    /// Il cuore della mod: "lockstep" degli input.
    ///
    /// Entrambi i giocatori eseguono la STESSA partita in locale. A ogni frame ciascuno:
    ///   1. legge il proprio controller e lo registra per il frame (attuale + InputDelay);
    ///   2. lo invia all'altro (con gli ultimi frame ripetuti, contro la perdita di pacchetti);
    ///   3. aspetta di avere l'input dell'altro per il frame attuale;
    ///   4. fa vedere al gioco, tramite le patch Rewired, l'input di P1 e P2 identico su entrambi i PC.
    /// L'host controlla Cuphead (P1), il client controlla Mugman (P2).
    ///
    /// Se il gioco fosse perfettamente deterministico, questo basterebbe a tenere le due partite
    /// identiche. Cuphead non lo è del tutto: per questo fissiamo il timestep, sincronizziamo il seed
    /// di UnityEngine.Random a ogni scena e controlliamo periodicamente un checksum dello stato.
    ///
    /// "Epoca" = segmento tra due caricamenti di scena. A ogni scena il contatore di frame riparte da 0,
    /// così i tempi di caricamento diversi tra i due PC non sfasano la sincronizzazione.
    /// </summary>
    internal sealed class CoopSession : IDisposable
    {
        private readonly CoopSettings cfg;
        private readonly UdpTransport net;
        private readonly PacketWriter pw = new PacketWriter();
        private readonly EndPoint hostEndPoint;
        private readonly StateChecksum checksum;

        public NetMode Mode { get { return cfg.Mode; } }
        public InputMap Map { get; private set; }
        public bool Connected { get; private set; }
        public string Status { get; private set; }

        public int Epoch { get; private set; }
        public int SimFrame { get; private set; }
        public int RemoteEpoch { get; private set; }
        public int InputDelay { get; private set; }
        public int PredictedFrames { get; private set; }
        public long StalledMs { get; private set; }
        public int Desyncs { get; private set; }
        public string LastDesync { get; private set; }
        /// <summary>Slot del menu da scegliere su questo PC (1-3).</summary>
        public int SaveSlot { get { return cfg.Mode == NetMode.Host ? cfg.HostSaveSlot : cfg.ClientSaveSlot; } }
        /// <summary>Progresso del download del salvataggio (client), -1 se non in corso.</summary>
        public float SaveDownloadProgress { get { return saveRx == null ? -1f : saveRx.Progress; } }
        public float SecondsSinceLastPacket { get { return Time.realtimeSinceStartup - lastRecvTime; } }

        private int seed;
        private int lastUnityFrame = -1;
        private float nextHelloTime;
        private float lastRecvTime;
        private long sceneWaitSpentMs;
        private InputBuffer local;
        private readonly Dictionary<int, InputBuffer> remoteByEpoch = new Dictionary<int, InputBuffer>();
        private readonly Dictionary<int, uint> localChecks = new Dictionary<int, uint>();
        private readonly Dictionary<int, uint> remoteChecks = new Dictionary<int, uint>();
        private readonly string savePath;
        private uint mySaveHash;
        private SaveReceiver saveRx;

        public CoopSession(CoopSettings settings)
        {
            cfg = settings;
            SimFrame = -1;
            RemoteEpoch = -1;
            InputDelay = Mathf.Clamp(cfg.InputDelay, 0, 30);

            if (cfg.Mode == NetMode.Host)
            {
                net = new UdpTransport(cfg.Port);
                seed = Environment.TickCount;
                Status = "In attesa di un client sulla porta UDP " + cfg.Port + "...";
            }
            else
            {
                net = new UdpTransport(0);
                hostEndPoint = UdpTransport.Resolve(cfg.HostAddress, cfg.Port);
                net.Remote = hostEndPoint;
                Status = "Connessione a " + hostEndPoint + "...";
            }
            if (cfg.Checksum) checksum = new StateChecksum(cfg.ChecksumTypes);
            if (cfg.SyncSave)
            {
                savePath = SaveSync.SlotPath(SaveSync.SaveDirectory(cfg.SaveDirectory), cfg.SaveFilePattern, SaveSlot);
                mySaveHash = SaveSync.Hash(SaveSync.TryRead(savePath));
                Plugin.Log.LogInfo("Salvataggio sincronizzato: " + savePath + (mySaveHash == 0 ? " (vuoto)" : " (hash " + mySaveHash.ToString("X8") + ")"));
            }
            Plugin.Log.LogInfo(Status);
        }

        public void Dispose()
        {
            if (Connected && cfg.FixedTimestep) Time.captureFramerate = 0;
            net.Dispose();
        }

        // ================================================================ ciclo per frame

        /// <summary>Chiamato da Plugin.Update ogni frame.</summary>
        public void Update()
        {
            if (Map == null)
            {
                Map = InputMap.TryBuild();
                if (Map == null) return;
                Plugin.Log.LogInfo("Azioni Rewired (" + Map.Count + ", hash " + Map.Hash.ToString("X8") + "): " + Map.Describe());
            }

            Poll();

            if (!Connected)
            {
                if (cfg.Mode == NetMode.Client && Time.realtimeSinceStartup >= nextHelloTime)
                {
                    nextHelloTime = Time.realtimeSinceStartup + 0.5f;
                    BinaryWriter w = pw.Begin(PacketType.Hello);
                    w.Write(Protocol.Version);
                    w.Write(Map.Hash);
                    w.Write(cfg.SyncSave);
                    w.Write(mySaveHash);
                    net.Send(pw.Buffer, pw.Length, hostEndPoint);
                }
                return;
            }

            EnsureFrame();
        }

        /// <summary>Chiamato da Plugin.LateUpdate: lo stato del frame è ormai definitivo.</summary>
        public void LateUpdate()
        {
            if (!Connected || checksum == null || SimFrame <= 0) return;
            if (SimFrame % Math.Max(1, cfg.ChecksumInterval) != 0) return;

            uint h = checksum.Compute();
            localChecks[SimFrame] = h;
            BinaryWriter w = pw.Begin(PacketType.Checksum);
            w.Write(Epoch);
            w.Write(SimFrame);
            w.Write(h);
            net.Send(pw.Buffer, pw.Length);
            CompareChecksum(SimFrame);
        }

        public void OnSceneLoaded(string sceneName)
        {
            if (!Connected) return;
            Epoch++;
            ResetEpoch();
            UnityEngine.Random.InitState(unchecked(seed + Epoch * 7919));
            Plugin.Log.LogInfo("Scena '" + sceneName + "' caricata: inizio epoca " + Epoch);
        }

        /// <summary>
        /// Avanza la simulazione di un frame (una sola volta per frame Unity): legge il controller
        /// locale, invia l'input e attende quello remoto.
        /// </summary>
        private void EnsureFrame()
        {
            if (!Connected || Map == null) return;
            int uf = Time.frameCount;
            if (uf == lastUnityFrame) return;
            lastUnityFrame = uf;
            SimFrame++;

            InputFrame mine;
            RewiredPatches.Bypass = true;
            try { mine = Map.Capture(ReInput.players.GetPlayer(cfg.LocalDeviceRewiredId)); }
            finally { RewiredPatches.Bypass = false; }
            local.Set(SimFrame + InputDelay, mine);

            SendInputs();
            WaitForRemote();
        }

        /// <summary>
        /// Usato dalle patch: se questo giocatore Rewired è P1 o P2, restituisce l'input sincronizzato.
        /// </summary>
        public bool TryGetOverride(int rewiredPlayerId, out InputFrame cur, out InputFrame prev)
        {
            cur = prev = default(InputFrame);
            if (!Connected || Map == null) return false;

            bool isP1 = rewiredPlayerId == cfg.Player1RewiredId;
            bool isP2 = rewiredPlayerId == cfg.Player2RewiredId;
            if (!isP1 && !isP2) return false;

            EnsureFrame();
            bool mineIsP1 = cfg.Mode == NetMode.Host;
            InputBuffer buf = isP1 == mineIsP1 ? local : RemoteBuffer(Epoch);
            cur = buf.Get(SimFrame);
            prev = buf.Get(SimFrame - 1);
            return true;
        }

        // ================================================================ lockstep

        private void ResetEpoch()
        {
            SimFrame = -1;
            lastUnityFrame = Time.frameCount; // il frame 0 dell'epoca inizia dal prossimo frame Unity
            sceneWaitSpentMs = 0;
            local = new InputBuffer(Map.AxisCount);
            localChecks.Clear();
            remoteChecks.Clear();
            var old = new List<int>();
            foreach (int e in remoteByEpoch.Keys) if (e < Epoch) old.Add(e);
            foreach (int e in old) remoteByEpoch.Remove(e);
        }

        private InputBuffer RemoteBuffer(int epoch)
        {
            InputBuffer b;
            if (!remoteByEpoch.TryGetValue(epoch, out b))
            {
                b = new InputBuffer(Map.AxisCount);
                remoteByEpoch[epoch] = b;
            }
            return b;
        }

        private void SendInputs()
        {
            int newest = SimFrame + InputDelay;
            int oldest = Math.Max(0, newest - Protocol.Redundancy + 1);
            BinaryWriter w = pw.Begin(PacketType.Input);
            w.Write(Epoch);
            w.Write((byte)(newest - oldest + 1));
            for (int f = newest; f >= oldest; f--)
            {
                w.Write(f);
                local.Get(f).Write(w, Map.AxisCount);
            }
            net.Send(pw.Buffer, pw.Length);
        }

        private void WaitForRemote()
        {
            if (SimFrame < InputDelay) return; // i primi frame di ogni epoca sono vuoti per definizione
            InputBuffer rb = RemoteBuffer(Epoch);
            if (rb.Has(SimFrame)) return;

            // L'altro è già nella scena successiva (noi stiamo ancora caricando): non aspettiamo.
            // L'altro è ancora nella scena precedente: aspettiamo che finisca di caricare, con un budget.
            int timeout;
            if (RemoteEpoch > Epoch) timeout = 0;
            else if (RemoteEpoch < Epoch && sceneWaitSpentMs < cfg.SceneWaitTimeoutMs) timeout = cfg.SceneWaitTimeoutMs;
            else timeout = cfg.StallTimeoutMs;

            Stopwatch sw = Stopwatch.StartNew();
            long lastSend = 0;
            while (sw.ElapsedMilliseconds < timeout)
            {
                Thread.Sleep(1);
                Poll();
                if (rb.Has(SimFrame)) break;
                if (RemoteEpoch > Epoch) break;
                if (sw.ElapsedMilliseconds - lastSend >= 15)
                {
                    lastSend = sw.ElapsedMilliseconds;
                    SendInputs(); // l'altro potrebbe aver perso i nostri pacchetti
                }
            }
            StalledMs += sw.ElapsedMilliseconds;
            if (RemoteEpoch < Epoch) sceneWaitSpentMs += sw.ElapsedMilliseconds;

            if (!rb.Has(SimFrame))
            {
                // Predizione: ripetiamo l'ultimo input noto. Può causare desync.
                rb.Set(SimFrame, rb.LastKnownUpTo(SimFrame - 1));
                PredictedFrames++;
            }
        }

        // ================================================================ rete

        private void Poll()
        {
            byte[] data;
            int len;
            EndPoint from;
            while (net.TryReceive(out data, out len, out from))
            {
                try
                {
                    using (var r = new BinaryReader(new MemoryStream(data, 0, len, false)))
                        Handle(r, from);
                }
                catch (EndOfStreamException)
                {
                    Plugin.Log.LogWarning("Pacchetto troncato da " + from);
                }
            }
        }

        private void Handle(BinaryReader r, EndPoint from)
        {
            PacketType type;
            if (!Protocol.TryReadHeader(r, out type)) return;

            bool fromPeer = net.Remote != null && net.Remote.Equals(from);
            if (fromPeer) lastRecvTime = Time.realtimeSinceStartup;

            switch (type)
            {
                case PacketType.Hello:
                    if (cfg.Mode == NetMode.Host) HandleHello(r, from);
                    break;
                case PacketType.Welcome:
                    if (cfg.Mode == NetMode.Client && fromPeer) HandleWelcome(r);
                    break;
                case PacketType.Reject:
                    if (cfg.Mode == NetMode.Client && fromPeer)
                    {
                        Status = "Connessione rifiutata: " + r.ReadString();
                        Plugin.Log.LogError(Status);
                        nextHelloTime = float.MaxValue;
                    }
                    break;
                case PacketType.SaveInfo:
                    if (cfg.Mode == NetMode.Client && fromPeer && !Connected) HandleSaveInfo(r);
                    break;
                case PacketType.SaveChunk:
                    if (cfg.Mode == NetMode.Client && fromPeer && !Connected) HandleSaveChunk(r);
                    break;
                case PacketType.Input:
                    if (Connected && fromPeer) HandleInput(r);
                    break;
                case PacketType.Checksum:
                    if (Connected && fromPeer)
                    {
                        int epoch = r.ReadInt32(), frame = r.ReadInt32();
                        uint h = r.ReadUInt32();
                        if (epoch == Epoch)
                        {
                            remoteChecks[frame] = h;
                            CompareChecksum(frame);
                        }
                    }
                    break;
            }
        }

        private void HandleHello(BinaryReader r, EndPoint from)
        {
            int version = r.ReadInt32();
            uint hash = r.ReadUInt32();
            bool clientSyncSave = r.ReadBoolean();
            uint clientSaveHash = r.ReadUInt32();

            if (Connected && !from.Equals(net.Remote))
            {
                Reject(from, "la partita ha già due giocatori");
                return;
            }
            if (version != Protocol.Version)
            {
                Reject(from, "versione della mod diversa (host " + Protocol.Version + ", client " + version + ")");
                return;
            }
            if (hash != Map.Hash)
            {
                Reject(from, "versione del gioco diversa (azioni Rewired non corrispondono)");
                return;
            }

            if (cfg.SyncSave != clientSyncSave)
            {
                Reject(from, "SyncSave deve essere uguale su host e client");
                return;
            }
            if (cfg.SyncSave && !Connected)
            {
                byte[] save = SaveSync.TryRead(savePath);
                uint hostSaveHash = SaveSync.Hash(save);
                if (hostSaveHash != clientSaveHash)
                {
                    if (save == null)
                    {
                        Reject(from, "l'host non ha un salvataggio nello slot " + cfg.HostSaveSlot +
                                     " ma il client sì: svuota lo slot " + cfg.ClientSaveSlot + " del client, o usa uno slot pieno sull'host");
                        return;
                    }
                    SendSave(from, save, hostSaveHash);
                    return; // il client si riconnetterà dopo il riavvio
                }
            }

            net.Remote = from;
            lastRecvTime = Time.realtimeSinceStartup;
            BinaryWriter w = pw.Begin(PacketType.Welcome);
            w.Write(Protocol.Version);
            w.Write(Map.Hash);
            w.Write(seed);
            w.Write(InputDelay);
            net.Send(pw.Buffer, pw.Length);

            if (!Connected) StartSync("Client connesso: " + from);
        }

        private void HandleWelcome(BinaryReader r)
        {
            if (Connected) return;
            r.ReadInt32(); // versione (già verificata dall'host)
            r.ReadUInt32();
            seed = r.ReadInt32();
            InputDelay = r.ReadInt32(); // l'input delay lo decide l'host
            StartSync("Connesso all'host " + net.Remote);
        }

        // ---------------------------------------------------------------- salvataggio

        private void SendSave(EndPoint to, byte[] save, uint hash)
        {
            BinaryWriter w = pw.Begin(PacketType.SaveInfo);
            w.Write(hash);
            w.Write(save.Length);
            net.Send(pw.Buffer, pw.Length, to);

            // Il client ripete Hello ogni 0,5 s finché non ha tutto: inviamo ogni volta tutti i pezzi
            // (un save di Cuphead è qualche decina di KB, quindi va bene così).
            int n = SaveSync.ChunkCount(save.Length);
            for (int i = 0; i < n; i++)
            {
                int offset = i * SaveSync.ChunkSize;
                int len = Math.Min(SaveSync.ChunkSize, save.Length - offset);
                w = pw.Begin(PacketType.SaveChunk);
                w.Write(hash);
                w.Write(i);
                w.Write((ushort)len);
                w.Write(save, offset, len);
                net.Send(pw.Buffer, pw.Length, to);
            }
            Status = "Invio del salvataggio al client " + to + " (" + save.Length + " byte)...";
        }

        private void HandleSaveInfo(BinaryReader r)
        {
            uint hash = r.ReadUInt32();
            int length = r.ReadInt32();
            if (length <= 0 || length > 16 * 1024 * 1024) return;
            if (saveRx == null || saveRx.Hash != hash)
            {
                saveRx = new SaveReceiver(hash, length);
                Status = "Il tuo slot " + cfg.ClientSaveSlot + " è diverso da quello dell'host: scarico il suo salvataggio...";
                Plugin.Log.LogInfo(Status);
            }
        }

        private void HandleSaveChunk(BinaryReader r)
        {
            uint hash = r.ReadUInt32();
            int index = r.ReadInt32();
            int len = r.ReadUInt16();
            byte[] chunk = r.ReadBytes(len);
            if (saveRx == null || saveRx.Hash != hash || saveRx.Complete) return;
            saveRx.Add(index, chunk);
            if (!saveRx.Complete) return;

            if (SaveSync.Hash(saveRx.Data) != hash)
            {
                Plugin.Log.LogWarning("Salvataggio ricevuto corrotto, lo riscarico.");
                saveRx = null;
                return;
            }
            try
            {
                SaveSync.WriteWithBackup(savePath, saveRx.Data);
                mySaveHash = hash;
                nextHelloTime = float.MaxValue; // non riconnettersi in questa esecuzione
                Status = "Salvataggio dell'host copiato nello slot " + cfg.ClientSaveSlot +
                         ". RIAVVIA CUPHEAD, poi riconnettiti e scegli lo slot " + cfg.ClientSaveSlot + ".";
                Plugin.Log.LogInfo(Status);
            }
            catch (Exception e)
            {
                Status = "Errore nello scrivere il salvataggio: " + e.Message;
                Plugin.Log.LogError(Status);
                nextHelloTime = float.MaxValue;
            }
        }

        private void Reject(EndPoint to, string reason)
        {
            Plugin.Log.LogWarning("Rifiuto " + to + ": " + reason);
            BinaryWriter w = pw.Begin(PacketType.Reject);
            w.Write(reason);
            net.Send(pw.Buffer, pw.Length, to);
        }

        private void HandleInput(BinaryReader r)
        {
            int epoch = r.ReadInt32();
            int count = r.ReadByte();
            if (epoch > RemoteEpoch) RemoteEpoch = epoch;
            if (epoch < Epoch) return; // input di una scena che abbiamo già lasciato

            InputBuffer rb = RemoteBuffer(epoch);
            for (int i = 0; i < count; i++)
            {
                int frame = r.ReadInt32();
                InputFrame f = InputFrame.Read(r, Map.AxisCount);
                // non sovrascriviamo i frame già presenti (inclusi quelli predetti e già usati)
                if (!rb.Has(frame)) rb.Set(frame, f);
            }
        }

        private void StartSync(string message)
        {
            Connected = true;
            Status = message;
            Plugin.Log.LogInfo(message + " (seed " + seed + ", input delay " + InputDelay + ")");

            if (cfg.FixedTimestep)
            {
                // Ogni frame avanza esattamente di 1/60 s su entrambi i PC, anche durante le attese.
                QualitySettings.vSyncCount = 0;
                Application.targetFrameRate = 60;
                Time.captureFramerate = 60;
            }

            Epoch = 0;
            RemoteEpoch = Math.Max(RemoteEpoch, 0);
            ResetEpoch();
            UnityEngine.Random.InitState(seed);
        }

        private void CompareChecksum(int frame)
        {
            uint a, b;
            if (!localChecks.TryGetValue(frame, out a) || !remoteChecks.TryGetValue(frame, out b)) return;
            localChecks.Remove(frame);
            remoteChecks.Remove(frame);
            if (a == b) return;

            Desyncs++;
            LastDesync = "epoca " + Epoch + ", frame " + frame;
            Plugin.Log.LogWarning("DESYNC rilevato (" + LastDesync + "): " + a.ToString("X8") + " != " + b.ToString("X8"));
        }
    }
}
