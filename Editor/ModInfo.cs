using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;

namespace Editor.Editor
{
    /// <summary>
    /// This is used for auto generating releases of packages if you wish, it will also have a uitk based editor for 
    /// 
    /// </summary>
    public class ModInfo : ScriptableObject
    {
        public string id = "sampleMod";
        public string name = "Sample Mod";
        public string author = "nobody";
        public string description = "A sample mod for KSP2";
        public string version = "0.1.0";
        public string versionCheck = "";
        public string minKsp2Version = "*";
        public string maxKsp2Version = "*";
        public string source = "";

        [SerializeField]
        public List<ModDependency> dependencies = new()
        {
            new()
            {
                Id = "com.github.x606.spacewarp",
                Min = "1.5.1",
                Max = "*"
            },
        };

        [SerializeField]
        public List<ModDependency> incompatibilities = new()
        {

        };

        private static Regex InvalidCharacterRegex = new(@"[^a-zA-Z0-9_]");
        private static Regex InvalidStartRegex = new(@"^[0-9].*$");
        public string SanitizedId {
            get {
                var replaced = InvalidCharacterRegex.Replace(id, "_");
                if (InvalidStartRegex.IsMatch(replaced))
                {
                    replaced = $"_{replaced}";
                }

                return replaced;
            }
        }

    public void GenerateSwinfo(string path)
        {
            var deps = new JArray();
            foreach (var dep in dependencies)
            {
                var versionObj = new JObject
                {
                    ["min"] = dep.Min,
                    ["max"] = dep.Max
                };
                var depObj = new JObject
                {
                    ["id"] = dep.Id,
                        ["version"] = versionObj
                };
                deps.Add(depObj);
            }

            var conflicts = new JArray();
            foreach (var conflict in incompatibilities)
            {
                var versionObj = new JObject
                {
                    ["min"] = conflict.Min,
                    ["max"] = conflict.Max
                };
                var conflictObj = new JObject
                {
                    ["id"] = conflict.Id,
                    ["version"] = versionObj
                };
                conflicts.Add(conflictObj);
            }

            var ksp2Version = new JObject
            {
                ["min"] = minKsp2Version,
                ["max"] = maxKsp2Version
            };
            var jObject = new JObject
            {
                ["spec"] = "2.0",
                ["mod_id"] = id,
                ["name"] = name,
                ["author"] = author,
                ["description"] = description,
                ["source"] = source,
                ["version"] = version,
                ["dependencies"] = deps,
                ["conflicts"] = conflicts
            };
            File.WriteAllText(path,jObject.ToString(Formatting.Indented));
            if (!path.StartsWith("Assets/")) return;
            AssetDatabase.ImportAsset(path);
            AssetDatabase.Refresh();
        }
    }
}