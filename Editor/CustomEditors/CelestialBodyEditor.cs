using System.IO;
using System.Reflection;
using KSP;
using KSP.IO;
using KSP.Sim.Definitions;
using ksp2community.ksp2unitytools.editor.API;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor.CustomEditors
{
    [CustomEditor(typeof(CoreCelestialBodyData))]
    public class CelestialBodyEditor : UnityEditor.Editor
    {
        private static bool _initialized;

        private static PersistentDictionary _jsonPaths;
        
        private static PersistentDictionary JsonPaths => _jsonPaths ??= KSP2UnityToolsManager.GetDictionary("JsonPaths");
        private static void Initialize()
        {
            typeof(IOProvider).GetMethod("Init", BindingFlags.Static | BindingFlags.NonPublic)
                ?.Invoke(null, new object[] { });
            _initialized = true;
        }
        private GameObject TargetObject => TargetData.gameObject;
        private CoreCelestialBodyData TargetData => target as CoreCelestialBodyData;

        private CelestialBodyCore TargetCore => TargetData.Core;

        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
            GUILayout.Label("Body Saving", EditorStyles.boldLabel);
            var jsonPath = JsonPaths.TryGetValue(TargetObject.name, out var newJsonPath) ? newJsonPath : "%NAME%.json";
            JsonPaths[TargetObject.name] = jsonPath = EditorGUILayout.TextField("JSON Path", jsonPath);
            if (GUILayout.Button("Save Body JSON"))
            {
                if (!_initialized) Initialize();
                if (TargetCore == null) return;
                var json = IOProvider.ToJson(TargetCore);
                var jObject = JObject.Parse(json);
                json = jObject.ToString(Formatting.Indented);
                var path = $"Assets/{jsonPath}";
                path = path.Replace("%NAME%", TargetCore.data.bodyName);
                var directoryName = new FileInfo(path).DirectoryName;
                Directory.CreateDirectory(directoryName);
                File.WriteAllText($"{path}", json);
                AssetDatabase.ImportAsset(path);
                AddressablesTools.MakeAddressable(path, $"{TargetCore.data.bodyName}.json", "celestial_bodies");
                AssetDatabase.Refresh();
                AssetDatabase.SaveAssets();
                EditorUtility.DisplayDialog("Body Exported", $"Json is at: {path}", "ok");
            }
        }
    }
}
