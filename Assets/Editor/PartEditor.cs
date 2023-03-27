
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using KSP;
using UnityEditor;
using Cheese.Extensions;
using KSP.IO;
using KSP.Modules;
using KSP.Sim.Definitions;
using Newtonsoft.Json;
using Newtonsoft.Json.UnityConverters;
using Newtonsoft.Json.UnityConverters.Configuration;
using UnityEditor.VersionControl;
using UnityEngine;

[CustomEditor(typeof(CorePartData))]
public class PartEditor : Editor
{

    private static bool _initialized = false;

    // Just initialize all the conversion stuff
    private static void Initialize()
    {
        typeof(IOProvider).GetMethod("Init", BindingFlags.Static | BindingFlags.NonPublic)
            ?.Invoke(null, new object[] { });
        _initialized = true;
        Module_Engine mod;
    }

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        if (!GUILayout.Button("Save Part JSON")) return;
        if (!_initialized) Initialize();
        var core = (serializedObject.targetObject as CorePartData)?.Core!;
        var targetGO = (serializedObject.targetObject as CorePartData).gameObject;
        if (core == null) return;
        // Clear out the serialized part modules and reserialize them
        core.data.serializedPartModules.Clear();
        foreach (var child in targetGO.GetComponents<PartBehaviourModule>())
        {
            child.GetType().GetMethod("AddDataModules", BindingFlags.Instance | BindingFlags.NonPublic)?.Invoke(child, new object[] {});
            foreach (var data in child.DataModules.Values)
            {
                data.GetType().GetMethod("RebuildDataContext", BindingFlags.Instance | BindingFlags.NonPublic)
                    ?.Invoke(data, new object[] { });
            }
            core.data.serializedPartModules.Add(new SerializedPartModule(child,false));
        }
        var json = IOProvider.ToJson(core);
        File.WriteAllText($"{Application.dataPath}/{core.data.partName}.json", json);
        AssetDatabase.Refresh();
        EditorUtility.DisplayDialog("Part Exported", $"Json is at: {Application.dataPath}/{core.data.partName}.json", "ok");
    }
}
