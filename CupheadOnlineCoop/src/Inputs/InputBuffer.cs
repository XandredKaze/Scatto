using System.Collections.Generic;

namespace CupheadOnlineCoop.Inputs
{
    /// <summary>
    /// Input di un giocatore indicizzati per frame di simulazione, all'interno di una "epoca"
    /// (un'epoca ricomincia da 0 a ogni caricamento di scena).
    /// </summary>
    public sealed class InputBuffer
    {
        private const int Keep = 240; // frame tenuti in memoria (~4 s a 60 fps)

        private readonly Dictionary<int, InputFrame> frames = new Dictionary<int, InputFrame>();
        private readonly int axisCount;

        public int Latest { get; private set; }

        public InputBuffer(int axisCount)
        {
            this.axisCount = axisCount;
            Latest = -1;
        }

        public void Set(int frame, InputFrame input)
        {
            frames[frame] = input;
            if (frame > Latest)
            {
                Latest = frame;
                Prune(frame - Keep);
            }
        }

        public bool Has(int frame) { return frames.ContainsKey(frame); }

        public bool TryGet(int frame, out InputFrame input) { return frames.TryGetValue(frame, out input); }

        /// <summary>Input del frame, oppure input vuoto se non c'è.</summary>
        public InputFrame Get(int frame)
        {
            InputFrame f;
            return frames.TryGetValue(frame, out f) ? f : InputFrame.Empty(axisCount);
        }

        /// <summary>Ultimo input noto con frame &lt;= frame richiesto (per la predizione).</summary>
        public InputFrame LastKnownUpTo(int frame)
        {
            for (int f = frame; f >= 0 && f > frame - Keep; f--)
            {
                InputFrame i;
                if (frames.TryGetValue(f, out i)) return i;
            }
            return InputFrame.Empty(axisCount);
        }

        private void Prune(int olderThan)
        {
            if (frames.Count < Keep * 2) return;
            var old = new List<int>();
            foreach (int k in frames.Keys) if (k < olderThan) old.Add(k);
            foreach (int k in old) frames.Remove(k);
        }
    }
}
