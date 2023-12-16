using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

namespace ksp2community.ksp2unitytools.editor
{
    public class KSP2UnityToolsSettings : ScriptableObject
    {
        public List<string> ignoredFiles = new();
        public string savedBuildPath = "";
        public string savedBuildMode = "Everything";
        public string savedModAddressablesPath = "";
        public string savedKsp2Path = "";
        

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