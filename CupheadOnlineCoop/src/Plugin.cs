using System;
using BepInEx;
using BepInEx.Configuration;
using BepInEx.Logging;
using CupheadOnlineCoop.Patches;
using HarmonyLib;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace CupheadOnlineCoop
{
    [BepInPlugin(Guid, Name, Version)]
    public class Plugin : BaseUnityPlugin
    {
        public const string Guid = "scatto.cuphead.onlinecoop";
        public const string Name = "Cuphead Online Coop";
        public const string Version = "0.1.0";

        internal static ManualLogSource Log;
        internal static CoopSession Session;

        private ConfigEntry<NetMode> mode;
        private ConfigEntry<string> hostAddress;
        private ConfigEntry<int> port;
        private ConfigEntry<int> inputDelay;
        private ConfigEntry<int> p1RewiredId;
        private ConfigEntry<int> p2RewiredId;
        private ConfigEntry<int> localDeviceRewiredId;
        private ConfigEntry<int> stallTimeoutMs;
        private ConfigEntry<int> sceneWaitTimeoutMs;
        private ConfigEntry<bool> fixedTimestep;
        private ConfigEntry<bool> checksumEnabled;
        private ConfigEntry<int> checksumInterval;
        private ConfigEntry<string> checksumTypes;
        private ConfigEntry<bool> syncSave;
        private ConfigEntry<string> saveDirectory;
        private ConfigEntry<string> saveFilePattern;
        private ConfigEntry<int> hostSaveSlot;
        private ConfigEntry<int> clientSaveSlot;
        private ConfigEntry<bool> showHud;
        private ConfigEntry<KeyCode> hudKey;
        private ConfigEntry<KeyCode> reconnectKey;

        private Harmony harmony;
        private bool loggedUpdateError;

        private void Awake()
        {
            Log = Logger;

            mode = Config.Bind("Rete", "Mode", NetMode.Off,
                "Off = mod disattivata, Host = ospiti la partita (giochi Cuphead), Client = ti colleghi all'host (giochi Mugman).");
            hostAddress = Config.Bind("Rete", "HostAddress", "127.0.0.1",
                "Solo client: IP o nome dell'host (es. IP pubblico, oppure IP Tailscale/ZeroTier/Radmin VPN).");
            port = Config.Bind("Rete", "Port", 7777, "Porta UDP. Sull'host va aperta/inoltrata se non usate una VPN.");
            inputDelay = Config.Bind("Rete", "InputDelay", 3,
                "Solo host: frame di ritardo dell'input (1 frame = 16,7 ms). Più alto = meno scatti con ping alto, ma comandi meno reattivi.");

            p1RewiredId = Config.Bind("Avanzate", "Player1RewiredId", 0, "ID del giocatore Rewired usato da Cuphead per il giocatore 1.");
            p2RewiredId = Config.Bind("Avanzate", "Player2RewiredId", 1, "ID del giocatore Rewired usato da Cuphead per il giocatore 2.");
            localDeviceRewiredId = Config.Bind("Avanzate", "LocalDeviceRewiredId", 0,
                "Giocatore Rewired da cui leggere il TUO controller (di solito 0 anche sul client).");
            stallTimeoutMs = Config.Bind("Avanzate", "StallTimeoutMs", 250,
                "Quanto aspettare l'input dell'altro per ogni frame prima di 'indovinarlo' (rischio desync).");
            sceneWaitTimeoutMs = Config.Bind("Avanzate", "SceneWaitTimeoutMs", 15000,
                "Quanto aspettare l'altro giocatore quando finisce di caricare una scena dopo di te.");
            fixedTimestep = Config.Bind("Avanzate", "FixedTimestep", true,
                "Forza 60 fps e passo di tempo fisso (Time.captureFramerate). Necessario perché le due partite restino uguali.");

            checksumEnabled = Config.Bind("Desync", "Enabled", true, "Confronta periodicamente lo stato delle due partite e segnala i desync.");
            checksumInterval = Config.Bind("Desync", "IntervalFrames", 60, "Ogni quanti frame confrontare lo stato.");
            checksumTypes = Config.Bind("Desync", "Types", "AbstractPlayerController,MapPlayerController",
                "Componenti (nomi di classi di Assembly-CSharp, separati da virgola) di cui confrontare la posizione.");

            syncSave = Config.Bind("Salvataggio", "SyncSave", true,
                "Il client gioca con una copia esatta del salvataggio dell'host. Senza, lo stato della mappa " +
                "(es. il ponte di legno dell'Isola Inkwell 1) è diverso sui due PC e si va in desync.");
            saveDirectory = Config.Bind("Salvataggio", "SaveDirectory", "",
                "Cartella dei salvataggi di Cuphead. Vuoto = %AppData%\\Cuphead.");
            saveFilePattern = Config.Bind("Salvataggio", "SaveFilePattern", "cuphead_player_data_v1_slot_{0}.sav",
                "Nome dei file di salvataggio; {0} = indice dello slot partendo da 0.");
            hostSaveSlot = Config.Bind("Salvataggio", "HostSaveSlot", 1,
                new ConfigDescription("Solo host: lo slot (1-3) con cui giocherete.", new AcceptableValueRange<int>(1, 3)));
            clientSaveSlot = Config.Bind("Salvataggio", "ClientSaveSlot", 3,
                new ConfigDescription("Solo client: lo slot (1-3) dove copiare il save dell'host. Il contenuto attuale viene salvato in un backup.",
                    new AcceptableValueRange<int>(1, 3)));

            showHud = Config.Bind("Interfaccia", "ShowHud", true, "Mostra lo stato della connessione in alto a sinistra.");
            hudKey = Config.Bind("Interfaccia", "HudKey", KeyCode.F8, "Mostra/nasconde lo stato.");
            reconnectKey = Config.Bind("Interfaccia", "ReconnectKey", KeyCode.F9, "Chiude e riapre la sessione (rilegge la configurazione).");

            harmony = new Harmony(Guid);
            RewiredPatches.Apply(harmony);
            SceneManager.sceneLoaded += OnSceneLoaded;

            StartSession();
        }

        private void StartSession()
        {
            StopSession();
            Config.Reload();
            if (mode.Value == NetMode.Off)
            {
                Log.LogInfo("Mode = Off: imposta Host o Client in BepInEx/config/" + Guid + ".cfg");
                return;
            }
            try
            {
                Session = new CoopSession(new CoopSettings
                {
                    Mode = mode.Value,
                    HostAddress = hostAddress.Value,
                    Port = port.Value,
                    InputDelay = inputDelay.Value,
                    Player1RewiredId = p1RewiredId.Value,
                    Player2RewiredId = p2RewiredId.Value,
                    LocalDeviceRewiredId = localDeviceRewiredId.Value,
                    StallTimeoutMs = stallTimeoutMs.Value,
                    SceneWaitTimeoutMs = sceneWaitTimeoutMs.Value,
                    FixedTimestep = fixedTimestep.Value,
                    Checksum = checksumEnabled.Value,
                    ChecksumInterval = checksumInterval.Value,
                    ChecksumTypes = checksumTypes.Value,
                    SyncSave = syncSave.Value,
                    SaveDirectory = saveDirectory.Value,
                    SaveFilePattern = saveFilePattern.Value,
                    HostSaveSlot = hostSaveSlot.Value,
                    ClientSaveSlot = clientSaveSlot.Value,
                });
            }
            catch (Exception e)
            {
                Log.LogError("Impossibile avviare la sessione: " + e);
                Session = null;
            }
        }

        private void StopSession()
        {
            if (Session == null) return;
            Session.Dispose();
            Session = null;
        }

        private void OnSceneLoaded(Scene scene, LoadSceneMode loadMode)
        {
            if (Session != null) Session.OnSceneLoaded(scene.name);
        }

        private void Update()
        {
            if (UnityEngine.Input.GetKeyDown(hudKey.Value)) showHud.Value = !showHud.Value;
            if (UnityEngine.Input.GetKeyDown(reconnectKey.Value)) StartSession();

            if (Session == null) return;
            try { Session.Update(); }
            catch (Exception e)
            {
                if (!loggedUpdateError) Log.LogError("Errore nella sessione: " + e);
                loggedUpdateError = true;
            }
        }

        private void LateUpdate()
        {
            if (Session == null) return;
            try { Session.LateUpdate(); }
            catch (Exception e)
            {
                if (!loggedUpdateError) Log.LogError("Errore nella sessione: " + e);
                loggedUpdateError = true;
            }
        }

        private void OnGUI()
        {
            if (Session == null || !showHud.Value) return;
            CoopSession s = Session;

            string text = Name + " [" + s.Mode + "]\n" + s.Status;
            if (s.SaveDownloadProgress >= 0f && !s.Connected)
                text += "\nDownload salvataggio: " + Mathf.RoundToInt(s.SaveDownloadProgress * 100f) + "%";
            if (s.Connected)
            {
                text += "\nScegli lo slot " + s.SaveSlot + " | epoca " + s.Epoch + " | frame " + s.SimFrame +
                        " | ritardo " + s.InputDelay + " | attesa " + s.StalledMs + " ms | predetti " + s.PredictedFrames;
                if (s.SecondsSinceLastPacket > 3f)
                    text += "\nNessun pacchetto dall'altro giocatore da " + Mathf.RoundToInt(s.SecondsSinceLastPacket) + " s";
                if (s.Desyncs > 0)
                    text += "\nDESYNC: " + s.Desyncs + " (ultimo: " + s.LastDesync + ")";
            }

            GUI.Box(new Rect(8, 8, 560, 22 + 18 * text.Split('\n').Length), "");
            GUI.Label(new Rect(16, 12, 548, 400), text);
        }

        private void OnDestroy()
        {
            SceneManager.sceneLoaded -= OnSceneLoaded;
            StopSession();
        }
    }
}
