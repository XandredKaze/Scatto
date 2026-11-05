using System;
using System.Reflection;
using CupheadOnlineCoop.Inputs;
using HarmonyLib;
using Rewired;

namespace CupheadOnlineCoop.Patches
{
    /// <summary>
    /// Cuphead legge i controlli tramite Rewired (Player.GetButton, GetAxis, ...).
    /// Intercettiamo quelle chiamate: quando la sessione online è attiva, per i giocatori 1 e 2
    /// restituiamo l'input sincronizzato via rete invece di quello del controller fisico.
    ///
    /// Patchiamo i metodi uno per uno (e non con [HarmonyPatch]) così, se un metodo non esiste
    /// nella versione di Rewired del gioco, lo saltiamo con un avviso invece di far fallire tutto.
    /// I prefix usano __0 (primo argomento) perché i nomi dei parametri in Rewired possono essere offuscati.
    /// </summary>
    internal static class RewiredPatches
    {
        /// <summary>Se true, le patch non fanno nulla: serve per leggere l'input reale del controller.</summary>
        public static bool Bypass;

        private enum Query { Button, ButtonDown, ButtonUp, NegButton, NegButtonDown, NegButtonUp, Axis }
        private enum AnyQuery { Any, AnyDown, AnyUp }

        public static void Apply(Harmony harmony)
        {
            int ok = 0;
            string[] perAction =
            {
                "GetButton", "GetButtonDown", "GetButtonUp",
                "GetNegativeButton", "GetNegativeButtonDown", "GetNegativeButtonUp",
                "GetAxis", "GetAxisRaw",
            };
            foreach (string m in perAction)
            {
                if (Patch(harmony, m, typeof(int), m + "_Int")) ok++;
                if (Patch(harmony, m, typeof(string), m + "_Str")) ok++;
            }
            foreach (string m in new[] { "GetAnyButton", "GetAnyButtonDown", "GetAnyButtonUp" })
                if (Patch(harmony, m, null, m)) ok++;

            Plugin.Log.LogInfo("Patch Rewired applicate: " + ok);
        }

        private static bool Patch(Harmony harmony, string name, Type param, string prefixName)
        {
            Type[] args = param == null ? Type.EmptyTypes : new[] { param };
            MethodInfo target = AccessTools.Method(typeof(Player), name, args);
            if (target == null)
            {
                Plugin.Log.LogWarning("Rewired.Player." + name + "(" + (param == null ? "" : param.Name) + ") non trovato, salto.");
                return false;
            }
            MethodInfo prefix = AccessTools.Method(typeof(RewiredPatches), prefixName);
            harmony.Patch(target, prefix: new HarmonyMethod(prefix));
            return true;
        }

        // ---------------------------------------------------------------- logica comune

        /// <returns>true se il valore è stato sovrascritto (quindi il metodo originale va saltato)</returns>
        private static bool Eval(Player p, Query q, int actionId, string actionName, out float value)
        {
            value = 0f;
            if (Bypass || p == null) return false;
            CoopSession s = Plugin.Session;
            InputFrame cur, prev;
            if (s == null || !s.TryGetOverride(p.id, out cur, out prev)) return false;

            InputMap map = s.Map;
            int slot = actionName != null ? map.SlotOf(actionName) : map.SlotOf(actionId);
            if (slot < 0) return true; // azione sconosciuta: per il giocatore in rete vale 0/false

            switch (q)
            {
                case Query.Button: value = B(cur.GetPos(slot)); break;
                case Query.ButtonDown: value = B(cur.GetPos(slot) && !prev.GetPos(slot)); break;
                case Query.ButtonUp: value = B(!cur.GetPos(slot) && prev.GetPos(slot)); break;
                case Query.NegButton: value = B(cur.GetNeg(slot)); break;
                case Query.NegButtonDown: value = B(cur.GetNeg(slot) && !prev.GetNeg(slot)); break;
                case Query.NegButtonUp: value = B(!cur.GetNeg(slot) && prev.GetNeg(slot)); break;
                case Query.Axis:
                    int ax = map.AxisIndex[slot];
                    if (ax >= 0) value = cur.GetAxis(ax);
                    else value = cur.GetPos(slot) ? 1f : cur.GetNeg(slot) ? -1f : 0f;
                    break;
            }
            return true;
        }

        private static float B(bool b) { return b ? 1f : 0f; }

        private static bool EvalBool(Player p, Query q, int id, string name, ref bool result)
        {
            float v;
            if (!Eval(p, q, id, name, out v)) return true; // esegui l'originale
            result = v != 0f;
            return false;
        }

        private static bool EvalFloat(Player p, Query q, int id, string name, ref float result)
        {
            float v;
            if (!Eval(p, q, id, name, out v)) return true;
            result = v;
            return false;
        }

        private static bool EvalAny(Player p, AnyQuery q, ref bool result)
        {
            if (Bypass || p == null) return true;
            CoopSession s = Plugin.Session;
            InputFrame cur, prev;
            if (s == null || !s.TryGetOverride(p.id, out cur, out prev)) return true;
            ulong now = cur.Pos | cur.Neg, before = prev.Pos | prev.Neg;
            switch (q)
            {
                case AnyQuery.Any: result = now != 0; break;
                case AnyQuery.AnyDown: result = (now & ~before) != 0; break;
                case AnyQuery.AnyUp: result = (before & ~now) != 0; break;
            }
            return false;
        }

        // ---------------------------------------------------------------- prefix Harmony

        private static bool GetButton_Int(Player __instance, int __0, ref bool __result) { return EvalBool(__instance, Query.Button, __0, null, ref __result); }
        private static bool GetButton_Str(Player __instance, string __0, ref bool __result) { return EvalBool(__instance, Query.Button, 0, __0 ?? "", ref __result); }
        private static bool GetButtonDown_Int(Player __instance, int __0, ref bool __result) { return EvalBool(__instance, Query.ButtonDown, __0, null, ref __result); }
        private static bool GetButtonDown_Str(Player __instance, string __0, ref bool __result) { return EvalBool(__instance, Query.ButtonDown, 0, __0 ?? "", ref __result); }
        private static bool GetButtonUp_Int(Player __instance, int __0, ref bool __result) { return EvalBool(__instance, Query.ButtonUp, __0, null, ref __result); }
        private static bool GetButtonUp_Str(Player __instance, string __0, ref bool __result) { return EvalBool(__instance, Query.ButtonUp, 0, __0 ?? "", ref __result); }

        private static bool GetNegativeButton_Int(Player __instance, int __0, ref bool __result) { return EvalBool(__instance, Query.NegButton, __0, null, ref __result); }
        private static bool GetNegativeButton_Str(Player __instance, string __0, ref bool __result) { return EvalBool(__instance, Query.NegButton, 0, __0 ?? "", ref __result); }
        private static bool GetNegativeButtonDown_Int(Player __instance, int __0, ref bool __result) { return EvalBool(__instance, Query.NegButtonDown, __0, null, ref __result); }
        private static bool GetNegativeButtonDown_Str(Player __instance, string __0, ref bool __result) { return EvalBool(__instance, Query.NegButtonDown, 0, __0 ?? "", ref __result); }
        private static bool GetNegativeButtonUp_Int(Player __instance, int __0, ref bool __result) { return EvalBool(__instance, Query.NegButtonUp, __0, null, ref __result); }
        private static bool GetNegativeButtonUp_Str(Player __instance, string __0, ref bool __result) { return EvalBool(__instance, Query.NegButtonUp, 0, __0 ?? "", ref __result); }

        private static bool GetAxis_Int(Player __instance, int __0, ref float __result) { return EvalFloat(__instance, Query.Axis, __0, null, ref __result); }
        private static bool GetAxis_Str(Player __instance, string __0, ref float __result) { return EvalFloat(__instance, Query.Axis, 0, __0 ?? "", ref __result); }
        private static bool GetAxisRaw_Int(Player __instance, int __0, ref float __result) { return EvalFloat(__instance, Query.Axis, __0, null, ref __result); }
        private static bool GetAxisRaw_Str(Player __instance, string __0, ref float __result) { return EvalFloat(__instance, Query.Axis, 0, __0 ?? "", ref __result); }

        private static bool GetAnyButton(Player __instance, ref bool __result) { return EvalAny(__instance, AnyQuery.Any, ref __result); }
        private static bool GetAnyButtonDown(Player __instance, ref bool __result) { return EvalAny(__instance, AnyQuery.AnyDown, ref __result); }
        private static bool GetAnyButtonUp(Player __instance, ref bool __result) { return EvalAny(__instance, AnyQuery.AnyUp, ref __result); }
    }
}
