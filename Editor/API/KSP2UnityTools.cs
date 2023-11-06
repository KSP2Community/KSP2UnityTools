using JetBrains.Annotations;

namespace ksp2community.ksp2unitytools.editor.API
{
    /// <summary>
    /// This is a global API for interfacing with KSP2 Unity Tools
    /// </summary>
    [PublicAPI]
    public static class KSP2UnityTools
    {
        /// <summary>
        /// The current mod ID for the project
        /// </summary>
        public static string CurrentModID => KSP2UnityToolsManager.ProjectModInfo.id;
        /// <summary>
        /// The sanitized mod ID for the project
        /// </summary>
        public static string CurrentSanitizedModID => KSP2UnityToolsManager.ProjectModInfo.SanitizedId;

        /// <summary>
        /// Ignore any files that have a certain name when copying files over to the built stuff
        /// </summary>
        /// <param name="filename">The s to ignore</param>
        public static void IgnoreFilesInCopy(params string[] filenames)
        {
            foreach (var filename in filenames)
            {
                KSP2UnityToolsManager.Settings.AddIgnoredFile(filename);
            }
        }

        /// <summary>
        /// Remove any previously ignored filenames from the ignore list
        /// </summary>
        /// <param name="filenames">The filenames to remove from the ignore list</param>
        public static void DontIgnoreFilesInCopy(params string[] filenames)
        {
            foreach (var filename in filenames)
            {
                KSP2UnityToolsManager.Settings.RemoveIgnoredFile(filename);
            }
        }
    }
}