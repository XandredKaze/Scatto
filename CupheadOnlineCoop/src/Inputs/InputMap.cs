using System.Collections.Generic;
using Rewired;

namespace CupheadOnlineCoop.Inputs
{
    /// <summary>
    /// Tabella delle azioni Rewired del gioco (Jump, Shoot, Dash, assi di movimento...).
    /// Viene costruita leggendo ReInput.mapping.Actions, così non dobbiamo conoscere
    /// a priori gli ID delle azioni di Cuphead. Entrambi i giocatori devono avere
    /// la stessa tabella: lo verifichiamo confrontando <see cref="Hash"/> nell'handshake.
    /// </summary>
    public sealed class InputMap
    {
        public const int MaxActions = 64;

        public readonly int[] ActionIds;      // slot -> actionId
        public readonly string[] ActionNames; // slot -> nome
        public readonly int[] AxisIndex;      // slot -> indice asse (-1 se è un pulsante)
        public readonly int AxisCount;
        public readonly uint Hash;

        private readonly Dictionary<int, int> slotByActionId = new Dictionary<int, int>();
        private readonly Dictionary<string, int> slotByName = new Dictionary<string, int>();

        private InputMap(List<InputAction> actions)
        {
            int n = actions.Count;
            ActionIds = new int[n];
            ActionNames = new string[n];
            AxisIndex = new int[n];

            uint h = 2166136261; // FNV-1a
            int axes = 0;
            for (int slot = 0; slot < n; slot++)
            {
                InputAction a = actions[slot];
                ActionIds[slot] = a.id;
                ActionNames[slot] = a.name ?? "";
                AxisIndex[slot] = a.type == InputActionType.Axis ? axes++ : -1;
                slotByActionId[a.id] = slot;
                if (!string.IsNullOrEmpty(a.name)) slotByName[a.name] = slot;

                h = Fnv(h, (uint)a.id);
                h = Fnv(h, (uint)a.type);
                foreach (char c in ActionNames[slot]) h = Fnv(h, c);
            }
            AxisCount = axes;
            Hash = h;
        }

        private static uint Fnv(uint h, uint v)
        {
            h ^= v;
            return h * 16777619;
        }

        public int Count { get { return ActionIds.Length; } }

        public int SlotOf(int actionId)
        {
            int s;
            return slotByActionId.TryGetValue(actionId, out s) ? s : -1;
        }

        public int SlotOf(string actionName)
        {
            int s;
            return actionName != null && slotByName.TryGetValue(actionName, out s) ? s : -1;
        }

        /// <summary>Restituisce null se Rewired non è ancora pronto.</summary>
        public static InputMap TryBuild()
        {
            if (!ReInput.isReady) return null;
            var list = new List<InputAction>();
            foreach (InputAction a in ReInput.mapping.Actions)
            {
                if (list.Count >= MaxActions)
                {
                    Plugin.Log.LogWarning("Più di " + MaxActions + " azioni Rewired: le restanti vengono ignorate.");
                    break;
                }
                list.Add(a);
            }
            list.Sort((x, y) => x.id.CompareTo(y.id));
            return new InputMap(list);
        }

        /// <summary>
        /// Legge lo stato REALE (non sovrascritto dalla rete) di un giocatore Rewired.
        /// Va chiamato con <see cref="Patches.RewiredPatches.Bypass"/> attivo.
        /// </summary>
        public InputFrame Capture(Player p)
        {
            var f = InputFrame.Empty(AxisCount);
            if (p == null) return f;
            for (int slot = 0; slot < ActionIds.Length; slot++)
            {
                int id = ActionIds[slot];
                if (p.GetButton(id)) f.Pos |= 1UL << slot;
                if (hasNegativeButton && TryGetNegativeButton(p, id)) f.Neg |= 1UL << slot;
                int ax = AxisIndex[slot];
                if (ax >= 0) f.Axes[ax] = InputFrame.QuantizeAxis(p.GetAxis(id));
            }
            return f;
        }

        private static bool hasNegativeButton = true;

        // In un metodo separato: se questa versione di Rewired non ha GetNegativeButton,
        // l'errore (MissingMethodException) nasce qui e possiamo semplicemente farne a meno.
        [System.Runtime.CompilerServices.MethodImpl(System.Runtime.CompilerServices.MethodImplOptions.NoInlining)]
        private static bool NegativeButton(Player p, int id) { return p.GetNegativeButton(id); }

        private static bool TryGetNegativeButton(Player p, int id)
        {
            try { return NegativeButton(p, id); }
            catch (System.MissingMethodException)
            {
                hasNegativeButton = false;
                Plugin.Log.LogWarning("Rewired senza GetNegativeButton: uso solo GetButton/GetAxis.");
                return false;
            }
        }

        public string Describe()
        {
            var parts = new string[ActionIds.Length];
            for (int i = 0; i < ActionIds.Length; i++)
                parts[i] = ActionIds[i] + ":" + ActionNames[i] + (AxisIndex[i] >= 0 ? "(asse)" : "");
            return string.Join(", ", parts);
        }
    }
}
