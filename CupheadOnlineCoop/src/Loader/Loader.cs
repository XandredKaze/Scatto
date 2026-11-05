using System;
using System.IO;
using CupheadOnlineCoop.Patches;
using HarmonyLib;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace CupheadOnlineCoop
{
    /// <summary>Stato globale della mod (al posto di quello che prima forniva BepInEx).</summary>
    public static class Plugin
    {
        public const string Guid = "scatto.cuphead.onlinecoop";
        public const string Name = "Cuphead Online Coop";
        public const string Version = "0.2.0";

        internal static ModLog Log = new ModLog(null);
        internal static ModConfig Config;
        internal static CoopSession Session;
        internal static string ModDir;
    }

    /// <summary>
    /// Avvio della mod senza BepInEx:
    ///  1. Doorstop chiama <see cref="Boot"/> prima che Unity sia pronto: apriamo log e configurazione
    ///     e ci mettiamo in ascolto del primo caricamento di scena (un evento puramente managed).
    ///  2. Al primo caricamento di scena Unity è pronto: applichiamo le patch Harmony e creiamo
    ///     un GameObject persistente con <see cref="CoopBehaviour"/> (Update, LateUpdate, HUD).
    /// </summary>
    internal static class Loader
    {
        private static bool started;

        public static void Boot()
        {
            try
            {
                Plugin.ModDir = Path.GetDirectoryName(typeof(Loader).Assembly.Location);
                Plugin.Log = new ModLog(Path.Combine(Plugin.ModDir, "CupheadOnlineCoop.log"));
                Plugin.Log.LogInfo(Plugin.Name + " " + Plugin.Version + " caricato da Doorstop (" + Plugin.ModDir + ")");
                Plugin.Config = new ModConfig(Path.Combine(Plugin.ModDir, "CupheadOnlineCoop.ini"));
                SceneManager.sceneLoaded += OnFirstSceneLoaded;
            }
            catch (Exception e)
            {
                Plugin.Log.LogError("Avvio fallito: " + e);
            }
        }

        private static void OnFirstSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            if (started) return;
            started = true;
            SceneManager.sceneLoaded -= OnFirstSceneLoaded;
            try
            {
                Plugin.Log.UnityReady = true;
                RewiredPatches.Apply(new Harmony(Plugin.Guid));

                var go = new GameObject("CupheadOnlineCoop");
                UnityEngine.Object.DontDestroyOnLoad(go);
                go.hideFlags = HideFlags.HideAndDontSave;
                go.AddComponent<CoopBehaviour>();
            }
            catch (Exception e)
            {
                Plugin.Log.LogError("Inizializzazione fallita: " + e);
            }
        }
    }

    /// <summary>Log su file (CupheadOnlineCoop.log nella cartella della mod) e nel log di Unity.</summary>
    internal sealed class ModLog
    {
        private readonly string path;
        private readonly object sync = new object();
        public bool UnityReady;

        public ModLog(string path)
        {
            this.path = path;
            if (path == null) return;
            try { File.WriteAllText(path, ""); } catch (Exception) { }
        }

        public void LogInfo(object msg) { Write("INFO", msg); }
        public void LogWarning(object msg) { Write("WARN", msg); }
        public void LogError(object msg) { Write("ERRORE", msg); }

        private void Write(string level, object msg)
        {
            string line = "[" + DateTime.Now.ToString("HH:mm:ss.fff") + "] [" + level + "] " + msg;
            if (path != null)
            {
                lock (sync)
                {
                    try { File.AppendAllText(path, line + Environment.NewLine); } catch (Exception) { }
                }
            }
            if (UnityReady) Debug.Log("[CupheadOnlineCoop] " + line);
        }
    }
}
