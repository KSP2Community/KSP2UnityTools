using System.IO;
using KSP.Rendering.Planets;
using UnityEditor;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor
{
    public static class AssetCreation
    {
        [MenuItem("Tools/Create/Biome Lookup Hash Table")]
        public static void CreateBiomeLookupHashTable()
        {
            var path = AssetDatabase.GetAssetPath (Selection.activeObject);
            if (path == "")
            {
                path = "Assets";
            }
            else if (Path.GetExtension(path) != "")
            {
                path = path.Replace(Path.GetFileName (AssetDatabase.GetAssetPath (Selection.activeObject)), "");
            }

            var hashTable = ScriptableObject.CreateInstance<BiomeLookupHashTable>();
            AssetDatabase.CreateAsset(hashTable, AssetDatabase.GenerateUniqueAssetPath(path + "/New HashTable.asset"));
            AssetDatabase.Refresh();
        }
    }
}