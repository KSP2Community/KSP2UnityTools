using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

namespace ksp2community.ksp2unitytools.editor
{
    public class KSP2UnityToolsSettings : ScriptableObject
    {
        public List<string> gameObjectKeys = new();
        public List<string> gameObjectValues = new();
        public List<string> ignoredFiles = new();
        public string savedBuildPath = "";
        public string savedBuildMode = "Everything";
        public string savedModAddressablesPath = "";
        public string savedKsp2Path = "";

        public bool Contains(string key)
        {
            return gameObjectKeys.Contains(key);
        }

        public string Get(string key)
        {
            return gameObjectValues[gameObjectKeys.IndexOf(key)];
        }

        public void Set(string key, string value)
        {
            if (Contains(key))
            {
                gameObjectValues[gameObjectKeys.IndexOf(key)] = value;
            }
            else
            {
                gameObjectKeys.Add(key);
                gameObjectValues.Add(value);
            }
        }

        public void AddIgnoredFile(string file)
        {
            if (!ignoredFiles.Contains(file))
            {
                ignoredFiles.Add(file);
            }
        }

        public void RemoveIgnoredFile(string file)
        {
            if (ignoredFiles.Contains(file))
                ignoredFiles.Remove(file);
        }
    }
}