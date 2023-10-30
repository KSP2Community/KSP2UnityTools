using System.IO;
using System.Reflection;
using Editor.KSP2UnityTools.Editor;
using KSP;
using UnityEditor;
using KSP.IO;
using KSP.Modules;
using KSP.Sim.Definitions;
using KSP2UT.KSP2UnityTools;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEngine;

[CustomEditor(typeof(CorePartData))]
public class PartEditor : UnityEditor.Editor
{
    private static bool _initialized = false;
    private static readonly Color ComColor = new Color(Color.yellow.r, Color.yellow.g, Color.yellow.b, 0.5f);

    // private static string _jsonPath = "%NAME%.json";

    private static bool _centerOfMassGizmos = true;
    private static bool _centerOfLiftGizmos = true;
    private static bool _attachNodeGizmos = true;

    public static bool DragCubeGizmos = true;

    // Just initialize all the conversion stuff
    private static void Initialize()
    {
        typeof(IOProvider).GetMethod("Init", BindingFlags.Static | BindingFlags.NonPublic)
            ?.Invoke(null, new object[] { });
        _initialized = true;
        Module_Engine mod;
    }

    private GameObject TargetObject => TargetData.gameObject;
    private CorePartData TargetData => target as CorePartData;
    private PartCore TargetCore => TargetData.Core;

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        GUILayout.Label("Attach Node Settings");
        if (GUILayout.Button("Auto Generate AttachNodes"))
        {

            TargetCore.data.attachNodes.Clear();
            // Attach node naming scheme
            foreach (var attachmentNode in TargetObject.GetComponentsInChildren<AttachmentNode>())
            {
                var obj = attachmentNode.gameObject;
                var pos = TargetObject.transform.InverseTransformPoint(obj.transform.position);
                var dir = Quaternion.Euler(TargetObject.transform.InverseTransformDirection(obj.transform.rotation.eulerAngles)) * Vector3.forward;
                var newDefinition = new AttachNodeDefinition
                {
                    nodeID = obj.name,
                    NodeSymmetryGroupID = attachmentNode.nodeSymmetryGroupID,
                    nodeType = attachmentNode.nodeType,
                    attachMethod = attachmentNode.attachMethod,
                    IsMultiJoint = attachmentNode.isMultiJoint,
                    MultiJointMaxJoint = attachmentNode.multiJointMaxJoint,
                    MultiJointRadiusOffset = attachmentNode.multiJointRadiusOffset,
                    position = pos,
                    orientation = dir,
                    size = attachmentNode.size,
                    visualSize = attachmentNode.visualSize,
                    angularStrengthMultiplier = attachmentNode.angularStrengthMultiplier,
                    contactArea = attachmentNode.contactArea,
                    overrideDragArea = attachmentNode.overrideDragArea,
                    isCompoundJoint = attachmentNode.isCompoundJoint
                };
                TargetCore.data.attachNodes.Add(newDefinition);
            }
            EditorUtility.SetDirty(target);
        }

        GUILayout.Label("Gizmo Settings", EditorStyles.boldLabel);
        EditorGUI.BeginChangeCheck();
        _centerOfMassGizmos = EditorGUILayout.Toggle("CoM gizmos", _centerOfMassGizmos);
        _centerOfLiftGizmos = EditorGUILayout.Toggle("CoL gizmos", _centerOfLiftGizmos);
        _attachNodeGizmos = EditorGUILayout.Toggle("Attach Node Gizmos", _attachNodeGizmos);
        DragCubeGizmos = EditorGUILayout.Toggle("Drag Cube Gizmos", DragCubeGizmos);
        if (EditorGUI.EndChangeCheck())
        {
            EditorUtility.SetDirty(target);
        }
        GUILayout.Label("Part Saving", EditorStyles.boldLabel);
        string _jsonPath = "%NAME%.json";
        if (KSP2UnityToolsManager.Settings.Contains(TargetObject.name))
        {
            _jsonPath = KSP2UnityToolsManager.Settings.Get(TargetObject.name);
        }
        // _jsonPath = EditorGUILayout.TextField("JSON Path",_jsonPath);
        EditorGUI.BeginChangeCheck();
        KSP2UnityToolsManager.Settings.Set(TargetObject.name, _jsonPath = EditorGUILayout.TextField("JSON Path", _jsonPath));
        if (EditorGUI.EndChangeCheck())
            EditorUtility.SetDirty(KSP2UnityToolsManager.Settings);
        if (!GUILayout.Button("Save Part JSON")) return;
        if (!_initialized) Initialize();
        if (TargetCore == null) return;
        // Clear out the serialized part modules and reserialize them
        TargetCore.data.serializedPartModules.Clear();
        foreach (var child in TargetObject.GetComponents<Component>())
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
            TargetCore.data.serializedPartModules.Add(new SerializedPartModule(partBehaviourModule,false));
        }
        var json = IOProvider.ToJson(TargetCore);
        var path = $"Assets/{_jsonPath}";
        path = path.Replace("%NAME%", TargetCore.data.partName);
        File.WriteAllText($"{path}", json);
        AssetDatabase.ImportAsset(path);
        AssetDatabase.Refresh();
        var settings = AddressableAssetSettingsDefaultObject.Settings;
        var group = settings.FindGroup(KSP2UnityToolsManager.ProjectModInfo.SanitizedId);
        var guid = AssetDatabase.AssetPathToGUID(path);
        var entry = settings.CreateOrMoveEntry(guid, group);
        entry.labels.Add("parts_data");
        entry.address = $"{TargetCore.data.partName}.json";
        settings.SetDirty(AddressableAssetSettings.ModificationEvent.EntryMoved, entry, true);
        AssetDatabase.SaveAssets();
        EditorUtility.DisplayDialog("Part Exported", $"Json is at: {path}", "ok");
    }

    [DrawGizmo(GizmoType.Active | GizmoType.Selected)]
    public static void DrawGizmoForPartCoreData(CorePartData data, GizmoType gizmoType)
    {
        var localToWorldMatrix = data.transform.localToWorldMatrix;
        if (_centerOfMassGizmos)
        {
            var centerOfMassPosition = data.Data.coMassOffset;
            centerOfMassPosition = localToWorldMatrix.MultiplyPoint(centerOfMassPosition);
            Gizmos.DrawIcon(centerOfMassPosition, "Packages/ksp2community.ksp2unitytools/Assets/Gizmos/com_icon.png", false);
        }
        if (_centerOfLiftGizmos)
        {
            var centerOfLiftPosition = data.Data.coLiftOffset;
            centerOfLiftPosition = localToWorldMatrix.MultiplyPoint(centerOfLiftPosition);
            Gizmos.DrawIcon(centerOfLiftPosition, "Packages/ksp2community.ksp2unitytools/Assets/Gizmos/col_icon.png", false);
        }
        if (!_attachNodeGizmos) return;
        Gizmos.color = new Color(Color.green.r, Color.green.g, Color.green.b, 0.5f);
        foreach (var attachNode in data.Data.attachNodes)
        {
            var pos = attachNode.position;
            pos = localToWorldMatrix.MultiplyPoint(pos);
            var dir = attachNode.orientation;
            dir = localToWorldMatrix.MultiplyVector(dir);
            Gizmos.DrawRay(pos, dir * 0.25f);
            Gizmos.DrawSphere(pos,0.05f);
        }
    }

    [DrawGizmo(GizmoType.Active | GizmoType.Selected)]
    public static void DrawGizmoForAttachmentNode(AttachmentNode node, GizmoType gizmoType)
    {
        if (!_attachNodeGizmos) return;
        Gizmos.color = new Color(Color.green.r, Color.green.g, Color.green.b, 0.5f);
        var pos = node.transform.position;
        Gizmos.DrawRay(pos, node.transform.rotation * Vector3.forward * 0.25f);
        Gizmos.DrawSphere(pos,0.05f);
    }
}
