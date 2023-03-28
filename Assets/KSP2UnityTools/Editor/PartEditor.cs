
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using KSP;
using UnityEditor;
using Cheese.Extensions;
using KSP.IO;
using KSP.Modules;
using KSP.Sim.Definitions;
using KSP.Sim.impl;
using Newtonsoft.Json;
using Newtonsoft.Json.UnityConverters;
using Newtonsoft.Json.UnityConverters.Configuration;
using UnityEditor.VersionControl;
using UnityEngine;
using UnityEngine.Rendering;

[CustomEditor(typeof(CorePartData))]
public class PartEditor : Editor
{

    private static bool _initialized = false;
    private static readonly Color ComColor = new Color(Color.yellow.r, Color.yellow.g, Color.yellow.b, 0.5f);
    
    // Just initialize all the conversion stuff
    private static void Initialize()
    {
        typeof(IOProvider).GetMethod("Init", BindingFlags.Static | BindingFlags.NonPublic)
            ?.Invoke(null, new object[] { });
        _initialized = true;
        Module_Engine mod;
    }

    private void OnSceneGUI()
    {
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
        foreach (var child in targetGO.GetComponents<Component>())
        {
            if (!(child is PartBehaviourModule partBehaviourModule)) continue;
            var addMethod = child.GetType().GetMethod("AddDataModules", BindingFlags.Instance | BindingFlags.NonPublic) ??
                            child.GetType().GetMethod("AddDataModules", BindingFlags.Instance | BindingFlags.Public);
            addMethod?.Invoke(child, new object[] { });
            foreach (var data in partBehaviourModule.DataModules.Values)
            {
                var rebuildMethod = data.GetType().GetMethod("RebuildDataContext", BindingFlags.Instance | BindingFlags.NonPublic) ?? data.GetType().GetMethod("RebuildDataContext", BindingFlags.Instance | BindingFlags.Public);
                rebuildMethod?.Invoke(data, new object[] { });
            }
            core.data.serializedPartModules.Add(new SerializedPartModule(partBehaviourModule,false));
        }
        var json = IOProvider.ToJson(core);
        File.WriteAllText($"{Application.dataPath}/{core.data.partName}.json", json);
        AssetDatabase.Refresh();
        EditorUtility.DisplayDialog("Part Exported", $"Json is at: {Application.dataPath}/{core.data.partName}.json", "ok");
    }
    [DrawGizmo(GizmoType.Active | GizmoType.Selected)]
    static void DrawGizmoForPartCoreData(CorePartData data, GizmoType gizmoType)
    {
        var centerOfMassPosition = data.Data.coMassOffset;
        var localToWorldMatrix = data.transform.localToWorldMatrix;
        centerOfMassPosition = localToWorldMatrix.MultiplyPoint(centerOfMassPosition);
        Gizmos.DrawIcon(centerOfMassPosition, "com_icon.png",false);
        var centerOfLiftPosition = data.Data.coLiftOffset;
        centerOfLiftPosition = localToWorldMatrix.MultiplyPoint(centerOfLiftPosition);
        Gizmos.DrawIcon(centerOfLiftPosition, "col_icon.png",false);
    }
}
