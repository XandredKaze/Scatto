using System;
using System.Collections.Generic;
using HarmonyLib;
using UnityEngine;

namespace CupheadOnlineCoop.Sync
{
    /// <summary>
    /// Calcola un'impronta dello stato di gioco (per ora: posizioni dei giocatori) per accorgersi
    /// quando le due partite divergono (desync). I tipi da osservare si trovano per nome via
    /// reflection, così la mod compila anche senza riferimenti diretti ad Assembly-CSharp.
    /// </summary>
    internal sealed class StateChecksum
    {
        private readonly List<Type> types = new List<Type>();

        public int LastObjectCount { get; private set; }

        public StateChecksum(string typeNamesCsv)
        {
            foreach (string raw in (typeNamesCsv ?? "").Split(','))
            {
                string name = raw.Trim();
                if (name.Length == 0) continue;
                Type t = AccessTools.TypeByName(name);
                if (t != null && typeof(Component).IsAssignableFrom(t))
                    types.Add(t);
                else
                    Plugin.Log.LogWarning("Checksum: tipo '" + name + "' non trovato o non è un Component.");
            }
        }

        public uint Compute()
        {
            var values = new List<long>();
            foreach (Type t in types)
            {
                foreach (UnityEngine.Object o in UnityEngine.Object.FindObjectsOfType(t))
                {
                    var c = o as Component;
                    if (c == null) continue;
                    Vector3 p = c.transform.position;
                    // quantizziamo a 1/4 di unità: differenze più piccole non contano come desync
                    long x = (long)Math.Round(p.x * 4f), y = (long)Math.Round(p.y * 4f);
                    values.Add((x << 32) ^ (y & 0xFFFFFFFF));
                }
            }
            values.Sort(); // FindObjectsOfType non garantisce l'ordine
            LastObjectCount = values.Count;

            uint h = 2166136261;
            foreach (long v in values)
                for (int i = 0; i < 8; i++)
                {
                    h ^= (uint)((v >> (i * 8)) & 0xFF);
                    h *= 16777619;
                }
            return h;
        }
    }
}
