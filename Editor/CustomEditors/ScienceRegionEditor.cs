using System.IO;
using KSP.Game.Science;
using KSP.IO;
using ksp2community.ksp2unitytools.editor.API;
using ksp2community.ksp2unitytools.editor.ScriptableObjects;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor.CustomEditors
{
    [CustomEditor(typeof(ScienceRegionData))]
    public class ScienceRegionEditor : UnityEditor.Editor
    {
        private static PersistentDictionary _bakedScienceRegionNames;
        private static PersistentDictionary _jsonNames;
        private static PersistentDictionary _discoverablesJsonNames;

        private static PersistentDictionary BakedScienceRegionNames => _bakedScienceRegionNames ??=
            KSP2UnityToolsManager.GetDictionary("BakedScienceRegionNames");

        private static PersistentDictionary JsonNames =>
            _jsonNames ??= KSP2UnityToolsManager.GetDictionary("JsonPaths");

        private static PersistentDictionary DiscoverablesJsonNames => _discoverablesJsonNames ??=
            KSP2UnityToolsManager.GetDictionary("DiscoverableJsonPaths");

        private ScienceRegionData Target => target as ScienceRegionData;

        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
            GUILayout.Label("Science Region Baking", EditorStyles.boldLabel);
            var jsonName = JsonNames.TryGetValue(Target.name, out var newJsonName)
                ? newJsonName
                : "%NAME%_science_regions";
            var discoverablesName = DiscoverablesJsonNames.TryGetValue(Target.name, out var newDiscoverablesName)
                ? newDiscoverablesName
                : "%NAME%_science_regions_discoverables";
            var bakedRegionsName = BakedScienceRegionNames.TryGetValue(Target.name, out var newBakedRegionName)
                ? newBakedRegionName
                : "%NAME%_baked_science_regions";
            JsonNames[Target.name] = jsonName = EditorGUILayout.TextField("Json Name", jsonName);
            DiscoverablesJsonNames[Target.name] = discoverablesName =
                EditorGUILayout.TextField("Discoverables Json Name", discoverablesName);
            BakedScienceRegionNames[Target.name] =
                bakedRegionsName = EditorGUILayout.TextField("Baked Region Name", bakedRegionsName);
            if (GUILayout.Button("Bake"))
            {
                jsonName = jsonName.Replace("%NAME%", Target.information.BodyName.ToLower());
                discoverablesName = discoverablesName.Replace("%NAME%", Target.information.BodyName.ToLower());
                bakedRegionsName = bakedRegionsName.Replace("%NAME%", Target.information.BodyName.ToLower());
                var path = AssetDatabase.GetAssetPath(Target);
                if (path == "")
                {
                    path = "Assets";
                }
                else if (Path.GetExtension(path) != "")
                {
                    path = path.Replace(Path.GetFileName(AssetDatabase.GetAssetPath(Selection.activeObject)), "");
                }

                var jsonData = JObject.Parse(IOProvider.ToJson(Target.information)).ToString(Formatting.Indented);
                File.WriteAllText($"{path}/{jsonName}.json", jsonData);
                AssetDatabase.ImportAsset($"{path}/{jsonName}.json");
                AddressablesTools.MakeAddressable($"{path}/{jsonName}.json", $"{jsonName}.json", "science_region");
                jsonData = JObject.Parse(IOProvider.ToJson(new CelestialBodyBakedDiscoverables
                {
                    BodyName = Target.information.BodyName,
                    Version = Target.information.Version,
                    Discoverables = Target.discoverables.ToArray()
                })).ToString(Formatting.Indented);
                File.WriteAllText($"{path}/{discoverablesName}.json", jsonData);
                AssetDatabase.ImportAsset($"{path}/{discoverablesName}.json");
                AddressablesTools.MakeAddressable($"{path}/{discoverablesName}.json", $"{discoverablesName}.json", "science_region_discoverables");
                var regionMap = CreateInstance<CelestialBodyBakedScienceRegionMap>();
                regionMap.Width = Target.scienceRegionMap.width;
                regionMap.Height = Target.scienceRegionMap.height;
                regionMap.MapData = Target.GetIndices();
                regionMap.BodyName = Target.information.BodyName;
                if (File.Exists(path + $"/{bakedRegionsName}.asset")) AssetDatabase.DeleteAsset(path + $"/{bakedRegionsName}.asset");
                AssetDatabase.CreateAsset(regionMap,path + $"/{bakedRegionsName}.asset");
                AddressablesTools.MakeAddressable($"{path}/{bakedRegionsName}.asset", $"{bakedRegionsName}",
                    "science_region_map");
                AssetDatabase.Refresh();
            }
        }
    }
}