using System.IO;
using UnityEditor;

namespace Editor.KSP2UnityTools.Editor
{
    public static class FixUnity
    {
        private static string _emptyMonobehaviour = @"
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ThisScriptFixesUnity : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
";
        [MenuItem("Tools/Fix Unity")]
        public static void CreateDeleteScript()
        {
            if (File.Exists("Assets/ThisScriptFixesUnity.cs"))
            {
                AssetDatabase.DeleteAsset("Assets/ThisScriptFixesUnity.cs");
            }
            else
            {
                File.WriteAllText("Assets/ThisScriptFixesUnity.cs", _emptyMonobehaviour);
                AssetDatabase.ImportAsset("Assets/ThisScriptFixesUnity.cs");
            }

            AssetDatabase.Refresh();
        }
    }
}