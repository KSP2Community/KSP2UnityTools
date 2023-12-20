using System.Collections.Generic;
using ksp2community.ksp2unitytools.editor.Editor;
using UnityEditor;
using UnityEngine;
using UnityEngine.Windows;
using Directory = System.IO.Directory;

namespace ksp2community.ksp2unitytools.editor
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


        private static Dictionary<string, PersistentDictionary> StoredDictionaries = new();
        
        
        public static PersistentDictionary GetDictionary(string dictionaryName)
        {
            if (StoredDictionaries.TryGetValue(dictionaryName, out var result)) return result;
            if (!Directory.Exists("Assets/KSP2UTData")) Directory.CreateDirectory("Assets/KSP2UTData");
            if (!File.Exists($"Assets/KSP2UTData/{dictionaryName}.asset"))
            {
                var dict = StoredDictionaries[dictionaryName] = ScriptableObject.CreateInstance<PersistentDictionary>();
                AssetDatabase.CreateAsset(dict, $"Assets/KSP2UTData/{dictionaryName}.asset");
                AssetDatabase.SaveAssets();
                return dict;
            }
            else
            {
                return StoredDictionaries[dictionaryName] =
                    AssetDatabase.LoadAssetAtPath<PersistentDictionary>($"Assets/KSP2UTData/{dictionaryName}.asset");
            }
        }

    }

}