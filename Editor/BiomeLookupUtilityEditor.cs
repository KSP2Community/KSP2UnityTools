using System;
using System.Collections.Generic;
using System.IO;
using KSP.Rendering.Planets;
using ksp2community.ksp2unitytools.editor.ScriptableObjects;
using UnityEditor;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor
{
    [CustomEditor(typeof(BiomeLookupUtility))]
    public class BiomeLookupUtilityEditor : UnityEditor.Editor
    {
        private static PersistentDictionary _hashMapNames;
        private static PersistentDictionary _lutNames;

        private static PersistentDictionary HashMapNames =>
            _hashMapNames ??= KSP2UnityToolsManager.GetDictionary("HashMapNames");

        private static PersistentDictionary LutNames => _lutNames ??= KSP2UnityToolsManager.GetDictionary("LUTNames");
        private BiomeLookupUtility Target => target as BiomeLookupUtility;
        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
            GUILayout.Label("Hash Map Saving", EditorStyles.boldLabel);
            var hashMapName = HashMapNames.TryGetValue(Target.name, out var newHashMapName)
                ? newHashMapName
                : $"{Target.name} Hashmap";
            HashMapNames[Target.name] = hashMapName = EditorGUILayout.TextField("Hash Map Name", hashMapName);
            var lutName = LutNames.TryGetValue(Target.name, out var newLutName) ? newLutName : $"{Target.name} LUT";
            LutNames[Target.name] = lutName = EditorGUILayout.TextField("LUT Name", lutName);
            if (GUILayout.Button("Bake"))
            {
                try
                {
                    var path = AssetDatabase.GetAssetPath(Target);
                    if (path == "")
                    {
                        path = "Assets";
                    }
                    else if (Path.GetExtension(path) != "")
                    {
                        path = path.Replace(Path.GetFileName(AssetDatabase.GetAssetPath(Selection.activeObject)), "");
                    }

                    var lut = CreateInstance<BiomeTextureColorLookupTable>();
                    lut.BiomeLookupPairs = new List<BiomeLookupEditorPair>();
                    var hashmap = CreateInstance<BiomeLookupHashTable>();

                    for (var i = 0; i < Target.colorMapping.Count; i++)
                    {
                        EditorUtility.DisplayProgressBar("Baking Biome Map",
                            $"Building Color LUT {i + 1}/{Target.colorMapping.Count}",
                            (i + 1) / (float)Target.colorMapping.Count);
                        lut.BiomeLookupPairs.Add(new BiomeLookupEditorPair
                        {
                            name = Target.colorMapping[i].name,
                            color = Target.colorMapping[i].color,
                        });
                    }

                    AssetDatabase.CreateAsset(lut, AssetDatabase.GenerateUniqueAssetPath(path + $"/{lutName}.asset"));
                    for (var y = 0; y < 256; y++)
                    {
                        var baseIndex = y * 256;

                        for (var x = 0; x < 256; x++)
                        {
                            var index = y * 256;
                            EditorUtility.DisplayProgressBar("Baking Biome Map",
                                $"Building Hashmap (x = {x:03}/255, y = {y:03}/255)", index / 65535.0f);
                            hashmap.Cells[index] = new BiomeLookupHashCell
                            {
                                BiomeChunks = Target.GetCell(x, y)
                            };
                        }
                    }

                    AssetDatabase.CreateAsset(hashmap,
                        AssetDatabase.GenerateUniqueAssetPath(path + $"/{hashMapName}.asset"));
                }
                finally
                {
                    EditorUtility.ClearProgressBar();
                    AssetDatabase.Refresh();
                }
            }
        }
    }
}