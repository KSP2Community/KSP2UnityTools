using Editor.Editor;
using KSP2UT.KSP2UnityTools;
using UnityEditor;
using UnityEngine;
using UnityEngine.Windows;

namespace Editor.KSP2UnityTools.Editor
{
    public static class KSP2UnityToolsManager
    {
        public static readonly KSP2UnityToolsSettings Settings;
        public static readonly ModInfo ProjectModInfo;

        static KSP2UnityToolsManager()
        {
            if (!File.Exists("Assets/KSP2UTSettings.asset"))
            {
                Settings = ScriptableObject.CreateInstance<KSP2UnityToolsSettings>();
                AssetDatabase.CreateAsset(Settings, "Assets/KSP2UTSettings.asset");
                AssetDatabase.SaveAssets();
            }
            else
            {
                Settings = AssetDatabase.LoadAssetAtPath<KSP2UnityToolsSettings>("Assets/KSP2UTSettings.asset");
            }
            if (!File.Exists("Assets/KSP2ModInfo.asset"))
            {
                ProjectModInfo = ScriptableObject.CreateInstance<ModInfo>();
                AssetDatabase.CreateAsset(ProjectModInfo, "Assets/KSP2ModInfo.asset");
                AssetDatabase.SaveAssets();
            }
            else
            {
                ProjectModInfo = AssetDatabase.LoadAssetAtPath<ModInfo>("Assets/KSP2ModInfo.asset");
            }
            
        }

    }

}