using System;
using System.IO;

namespace CupheadOnlineCoop.Sync
{
    /// <summary>
    /// Sincronizzazione del salvataggio.
    ///
    /// PERCHÉ: lo stato dell'overworld (es. il ponte di legno all'inizio dell'Isola Inkwell 1,
    /// scale, sentieri sbloccati, eventi già visti) viene dal file di salvataggio. Se host e client
    /// caricano save diversi, le due mappe sono diverse: oggetti che "spariscono" su un PC e,
    /// con il lockstep, desync immediato. Quindi il client deve giocare con una copia ESATTA
    /// del save dell'host.
    ///
    /// COME: l'host legge il file dello slot scelto e lo spedisce a pezzi via UDP. Il client lo
    /// scrive nel proprio slot dedicato (facendo prima un backup) e chiede di riavviare il gioco,
    /// perché Cuphead carica i salvataggi all'avvio. Al riavvio gli hash coincidono e si gioca.
    /// Il save principale del client non viene mai toccato (a meno di configurare lo stesso slot).
    /// </summary>
    internal static class SaveSync
    {
        public const int ChunkSize = 1000;

        public static string SaveDirectory(string configured)
        {
            if (!string.IsNullOrEmpty(configured)) return configured;
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Cuphead");
        }

        /// <param name="slot">slot come nel menu del gioco: 1, 2 o 3</param>
        public static string SlotPath(string dir, string pattern, int slot)
        {
            return Path.Combine(dir, string.Format(pattern, slot - 1));
        }

        public static byte[] TryRead(string path)
        {
            try { return File.Exists(path) ? File.ReadAllBytes(path) : null; }
            catch (Exception e)
            {
                Plugin.Log.LogWarning("Impossibile leggere il salvataggio " + path + ": " + e.Message);
                return null;
            }
        }

        /// <summary>Hash del contenuto; 0 = file assente.</summary>
        public static uint Hash(byte[] data)
        {
            if (data == null) return 0;
            uint h = 2166136261;
            foreach (byte b in data) { h ^= b; h *= 16777619; }
            return h == 0 ? 1u : h;
        }

        /// <summary>Scrive il save ricevuto, con backup del file esistente.</summary>
        public static void WriteWithBackup(string path, byte[] data)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            if (File.Exists(path))
            {
                string backup = path + ".coop-backup-" + DateTime.Now.ToString("yyyyMMdd-HHmmss");
                File.Copy(path, backup, false);
                Plugin.Log.LogInfo("Backup del salvataggio esistente: " + backup);
            }
            string tmp = path + ".coop-tmp";
            File.WriteAllBytes(tmp, data);
            if (File.Exists(path)) File.Delete(path);
            File.Move(tmp, path);
        }

        public static int ChunkCount(int length) { return (length + ChunkSize - 1) / ChunkSize; }
    }

    /// <summary>Ricompone sul client i pezzi del save inviati dall'host.</summary>
    internal sealed class SaveReceiver
    {
        public readonly uint Hash;
        private readonly byte[] data;
        private readonly bool[] got;
        private int received;

        public SaveReceiver(uint hash, int length)
        {
            Hash = hash;
            data = new byte[length];
            got = new bool[SaveSync.ChunkCount(length)];
        }

        public bool Complete { get { return received == got.Length; } }
        public float Progress { get { return got.Length == 0 ? 1f : (float)received / got.Length; } }

        public void Add(int index, byte[] chunk)
        {
            if (index < 0 || index >= got.Length || got[index]) return;
            int offset = index * SaveSync.ChunkSize;
            if (offset + chunk.Length > data.Length) return;
            Buffer.BlockCopy(chunk, 0, data, offset, chunk.Length);
            got[index] = true;
            received++;
        }

        public byte[] Data { get { return data; } }
    }
}
