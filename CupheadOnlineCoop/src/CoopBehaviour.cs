using System;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace CupheadOnlineCoop
{
    /// <summary>
    /// Componente persistente creato dal Loader: fa girare la sessione a ogni frame e disegna l'HUD.
    /// </summary>
    internal sealed class CoopBehaviour : MonoBehaviour
    {
        private bool showHud;
        private KeyCode hudKey, reconnectKey;
        private bool loggedError;

        private void Awake()
        {
            SceneManager.sceneLoaded += OnSceneLoaded;
            StartSession();
        }

        private void StartSession()
        {
            StopSession();
            ModConfig c = Plugin.Config;
            c.Reload();
            showHud = c.GetBool("ShowHud", true);
            hudKey = c.GetEnum("HudKey", KeyCode.F8);
            reconnectKey = c.GetEnum("ReconnectKey", KeyCode.F9);
            loggedError = false;

            NetMode mode = c.GetEnum("Mode", NetMode.Off);
            if (mode == NetMode.Off)
            {
                Plugin.Log.LogInfo("Mode = Off: imposta Host o Client in CupheadOnlineCoop.ini");
                return;
            }
            try
            {
                Plugin.Session = new CoopSession(new CoopSettings
                {
                    Mode = mode,
                    HostAddress = c.GetString("HostAddress", "127.0.0.1"),
                    Port = c.GetInt("Port", 7777, 1, 65535),
                    InputDelay = c.GetInt("InputDelay", 3, 0, 30),
                    Player1RewiredId = c.GetInt("Player1RewiredId", 0),
                    Player2RewiredId = c.GetInt("Player2RewiredId", 1),
                    LocalDeviceRewiredId = c.GetInt("LocalDeviceRewiredId", 0),
                    StallTimeoutMs = c.GetInt("StallTimeoutMs", 250, 0, 10000),
                    SceneWaitTimeoutMs = c.GetInt("SceneWaitTimeoutMs", 15000, 0, 120000),
                    FixedTimestep = c.GetBool("FixedTimestep", true),
                    Checksum = c.GetBool("ChecksumEnabled", true),
                    ChecksumInterval = c.GetInt("ChecksumIntervalFrames", 60, 1, 3600),
                    ChecksumTypes = c.GetString("ChecksumTypes", "AbstractPlayerController,MapPlayerController"),
                    SyncSave = c.GetBool("SyncSave", true),
                    SaveDirectory = c.GetString("SaveDirectory", ""),
                    SaveFilePattern = c.GetString("SaveFilePattern", "cuphead_player_data_v1_slot_{0}.sav"),
                    HostSaveSlot = c.GetInt("HostSaveSlot", 1, 1, 3),
                    ClientSaveSlot = c.GetInt("ClientSaveSlot", 3, 1, 3),
                });
            }
            catch (Exception e)
            {
                Plugin.Log.LogError("Impossibile avviare la sessione: " + e);
                Plugin.Session = null;
            }
        }

        private static void StopSession()
        {
            if (Plugin.Session == null) return;
            Plugin.Session.Dispose();
            Plugin.Session = null;
        }

        private void OnSceneLoaded(Scene scene, LoadSceneMode loadMode)
        {
            if (Plugin.Session != null) Plugin.Session.OnSceneLoaded(scene.name);
        }

        private void Update()
        {
            if (UnityEngine.Input.GetKeyDown(hudKey)) showHud = !showHud;
            if (UnityEngine.Input.GetKeyDown(reconnectKey)) StartSession();

            if (Plugin.Session == null) return;
            try { Plugin.Session.Update(); }
            catch (Exception e) { LogOnce(e); }
        }

        private void LateUpdate()
        {
            if (Plugin.Session == null) return;
            try { Plugin.Session.LateUpdate(); }
            catch (Exception e) { LogOnce(e); }
        }

        private void LogOnce(Exception e)
        {
            if (!loggedError) Plugin.Log.LogError("Errore nella sessione: " + e);
            loggedError = true;
        }

        private void OnGUI()
        {
            CoopSession s = Plugin.Session;
            if (s == null || !showHud) return;

            string text = Plugin.Name + " [" + s.Mode + "]\n" + s.Status;
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
