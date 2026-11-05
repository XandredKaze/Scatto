using System.IO;

namespace CupheadOnlineCoop.Inputs
{
    /// <summary>
    /// Lo stato completo dell'input di UN giocatore in UN frame.
    /// Ogni azione Rewired occupa uno "slot" (vedi <see cref="InputMap"/>):
    ///  - bit in <see cref="Pos"/>  = GetButton(azione)
    ///  - bit in <see cref="Neg"/>  = GetNegativeButton(azione)
    ///  - <see cref="Axes"/>        = valore degli assi, quantizzato a -127..127
    /// </summary>
    public struct InputFrame
    {
        public ulong Pos;
        public ulong Neg;
        public sbyte[] Axes;

        public static InputFrame Empty(int axisCount)
        {
            return new InputFrame { Axes = new sbyte[axisCount] };
        }

        public bool IsEmpty
        {
            get
            {
                if (Pos != 0 || Neg != 0) return false;
                if (Axes != null)
                    for (int i = 0; i < Axes.Length; i++)
                        if (Axes[i] != 0) return false;
                return true;
            }
        }

        public bool GetPos(int slot) { return (Pos & (1UL << slot)) != 0; }
        public bool GetNeg(int slot) { return (Neg & (1UL << slot)) != 0; }

        public float GetAxis(int axisIndex)
        {
            if (Axes == null || axisIndex < 0 || axisIndex >= Axes.Length) return 0f;
            return Axes[axisIndex] / 127f;
        }

        public static sbyte QuantizeAxis(float v)
        {
            if (v > 1f) v = 1f;
            if (v < -1f) v = -1f;
            return (sbyte)System.Math.Round(v * 127f);
        }

        public void Write(BinaryWriter w, int axisCount)
        {
            w.Write(Pos);
            w.Write(Neg);
            for (int i = 0; i < axisCount; i++)
                w.Write(Axes != null && i < Axes.Length ? Axes[i] : (sbyte)0);
        }

        public static InputFrame Read(BinaryReader r, int axisCount)
        {
            var f = new InputFrame { Pos = r.ReadUInt64(), Neg = r.ReadUInt64(), Axes = new sbyte[axisCount] };
            for (int i = 0; i < axisCount; i++) f.Axes[i] = r.ReadSByte();
            return f;
        }
    }
}
