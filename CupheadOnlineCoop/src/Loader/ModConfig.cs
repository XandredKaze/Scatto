using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;

namespace CupheadOnlineCoop
{
    /// <summary>
    /// Configurazione in un semplice file INI (CupheadOnlineCoop.ini nella cartella della mod).
    /// Se il file non esiste viene creato con i valori predefiniti e i commenti.
    /// Le sezioni [..] servono solo a leggibilità: le chiavi sono uniche.
    /// </summary>
    internal sealed class ModConfig
    {
        public const string DefaultIni =
@"; ================================================================
;  Cuphead Online Coop - configurazione
;  Modifica e salva, poi premi F9 nel gioco per riconnetterti.
; ================================================================

[Rete]
; Off = mod disattivata | Host = ospiti la partita (giochi Cuphead)
; Client = ti colleghi all'host (giochi Mugman)
Mode = Off
; Solo client: IP dell'host (IP pubblico, oppure IP Tailscale / ZeroTier / Radmin VPN)
HostAddress = 127.0.0.1
; Porta UDP. Sull'host va inoltrata nel router se non usate una VPN.
Port = 7777
; Solo host: frame di ritardo dell'input (1 frame = 16,7 ms).
; Più alto = meno scatti con ping alto, ma comandi meno reattivi.
InputDelay = 3

[Salvataggio]
; Il client gioca con una copia esatta del save dell'host. Senza, lo stato della mappa
; (es. il ponte di legno dell'Isola Inkwell 1) è diverso sui due PC e si va in desync.
SyncSave = true
; Cartella dei salvataggi. Vuoto = %AppData%\Cuphead
SaveDirectory =
; Nome dei file di salvataggio; {0} = indice dello slot partendo da 0
SaveFilePattern = cuphead_player_data_v1_slot_{0}.sav
; Solo host: slot (1-3) con cui giocherete
HostSaveSlot = 1
; Solo client: slot (1-3) dove copiare il save dell'host (il vecchio contenuto va in un backup)
ClientSaveSlot = 3

[Interfaccia]
ShowHud = true
; Mostra/nasconde lo stato della connessione
HudKey = F8
; Chiude e riapre la connessione rileggendo questo file
ReconnectKey = F9

[Desync]
; Confronta periodicamente lo stato delle due partite e segnala i desync
ChecksumEnabled = true
ChecksumIntervalFrames = 60
; Classi di Assembly-CSharp di cui confrontare la posizione
ChecksumTypes = AbstractPlayerController,MapPlayerController

[Avanzate]
Player1RewiredId = 0
Player2RewiredId = 1
; Giocatore Rewired da cui leggere il TUO controller (di solito 0 anche sul client)
LocalDeviceRewiredId = 0
; Quanto aspettare l'input dell'altro per ogni frame prima di 'indovinarlo' (rischio desync)
StallTimeoutMs = 250
; Quanto aspettare l'altro giocatore quando finisce di caricare una scena dopo di te
SceneWaitTimeoutMs = 15000
; Forza 60 fps e passo di tempo fisso: necessario perché le due partite restino uguali
FixedTimestep = true
";

        private readonly string path;
        private Dictionary<string, string> values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        public ModConfig(string path)
        {
            this.path = path;
            Reload();
        }

        public void Reload()
        {
            try
            {
                if (!File.Exists(path))
                {
                    File.WriteAllText(path, DefaultIni);
                    Plugin.Log.LogInfo("Creato " + path + ": impostalo e riavvia (o premi F9).");
                }
                values = Parse(File.ReadAllLines(path));
            }
            catch (Exception e)
            {
                Plugin.Log.LogError("Impossibile leggere " + path + ": " + e.Message + " (uso i valori predefiniti)");
                values = Parse(DefaultIni.Split('\n'));
            }
        }

        public static Dictionary<string, string> Parse(string[] lines)
        {
            var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (string raw in lines)
            {
                string line = raw.Trim();
                if (line.Length == 0 || line[0] == ';' || line[0] == '#' || line[0] == '[') continue;
                int eq = line.IndexOf('=');
                if (eq <= 0) continue;
                d[line.Substring(0, eq).Trim()] = line.Substring(eq + 1).Trim();
            }
            return d;
        }

        public string GetString(string key, string def)
        {
            string v;
            return values.TryGetValue(key, out v) ? v : def;
        }

        public int GetInt(string key, int def, int min = int.MinValue, int max = int.MaxValue)
        {
            int v;
            if (!int.TryParse(GetString(key, ""), NumberStyles.Integer, CultureInfo.InvariantCulture, out v)) return def;
            return Math.Max(min, Math.Min(max, v));
        }

        public bool GetBool(string key, bool def)
        {
            string v = GetString(key, "").ToLowerInvariant();
            if (v == "true" || v == "1" || v == "si" || v == "sì" || v == "yes") return true;
            if (v == "false" || v == "0" || v == "no") return false;
            return def;
        }

        public T GetEnum<T>(string key, T def)
        {
            string v = GetString(key, "");
            if (v.Length == 0) return def;
            try { return (T)Enum.Parse(typeof(T), v, true); }
            catch (Exception)
            {
                Plugin.Log.LogWarning("Valore non valido per " + key + ": '" + v + "', uso " + def);
                return def;
            }
        }
    }
}
