using System;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;

namespace Doorstop
{
    /// <summary>
    /// Punto d'ingresso chiamato da Unity Doorstop (winhttp.dll) all'avvio del gioco,
    /// PRIMA che Unity sia inizializzato. Qui non si possono usare le API di Unity:
    /// registriamo solo il caricamento delle nostre dipendenze e passiamo al Loader.
    /// </summary>
    public static class Entrypoint
    {
        public static void Start()
        {
            // 0Harmony.dll sta nella cartella della mod, non in Cuphead_Data/Managed:
            // insegniamo a Mono a trovarla. Va fatto prima di toccare qualunque tipo di Harmony,
            // per questo Boot() è in un metodo separato e non inlinato.
            AppDomain.CurrentDomain.AssemblyResolve += ResolveFromModFolder;
            Boot();
        }

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static void Boot()
        {
            CupheadOnlineCoop.Loader.Boot();
        }

        private static Assembly ResolveFromModFolder(object sender, ResolveEventArgs args)
        {
            string name = new AssemblyName(args.Name).Name;
            string dir = Path.GetDirectoryName(typeof(Entrypoint).Assembly.Location);
            string path = Path.Combine(dir, name + ".dll");
            return File.Exists(path) ? Assembly.LoadFrom(path) : null;
        }
    }
}
