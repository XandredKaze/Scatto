using System.IO;

namespace CupheadOnlineCoop.Net
{
    public enum PacketType : byte
    {
        /// <summary>client → host: [protocollo, hash azioni, syncSave, hash save]</summary>
        Hello = 1,
        /// <summary>host → client: [protocollo, hash azioni, seed, input delay]</summary>
        Welcome = 2,
        /// <summary>entrambi: [epoca, n, n × (frame, InputFrame)]</summary>
        Input = 3,
        /// <summary>entrambi: [epoca, frame, checksum stato]</summary>
        Checksum = 4,
        /// <summary>host → client: connessione rifiutata [motivo]</summary>
        Reject = 5,
        /// <summary>host → client: il save del client è diverso, arriva quello dell'host [hash, lunghezza]</summary>
        SaveInfo = 6,
        /// <summary>host → client: un pezzo del save [hash, indice, lunghezza, byte]</summary>
        SaveChunk = 7,
    }

    /// <summary>Piccolo helper per scrivere pacchetti riusando lo stesso buffer.</summary>
    public sealed class PacketWriter
    {
        private readonly MemoryStream stream = new MemoryStream(1024);
        public readonly BinaryWriter W;

        public PacketWriter() { W = new BinaryWriter(stream); }

        public BinaryWriter Begin(PacketType type)
        {
            stream.SetLength(0);
            stream.Position = 0;
            W.Write(Protocol.Magic);
            W.Write((byte)type);
            return W;
        }

        public byte[] Buffer { get { return stream.GetBuffer(); } }
        public int Length { get { return (int)stream.Length; } }
    }

    public static class Protocol
    {
        public const ushort Magic = 0xC0FE;
        public const int Version = 1;
        /// <summary>Quanti frame di input passati rimandiamo in ogni pacchetto (ridondanza contro la perdita).</summary>
        public const int Redundancy = 8;

        /// <summary>Legge l'intestazione; false se il pacchetto non è nostro.</summary>
        public static bool TryReadHeader(BinaryReader r, out PacketType type)
        {
            type = 0;
            if (r.BaseStream.Length < 3) return false;
            if (r.ReadUInt16() != Magic) return false;
            type = (PacketType)r.ReadByte();
            return true;
        }
    }
}
