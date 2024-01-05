using System.IO;
using System.Reflection;
using KSP;
using KSP.IO;
using KSP.Modules;
using KSP.Sim.Definitions;
using ksp2community.ksp2unitytools.editor.API;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor
{
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
        }


        private static PersistentDictionary _patchPaths;
        private static PersistentDictionary PatchPaths => _patchPaths ??= KSP2UnityToolsManager.GetDictionary("PatchPaths");

        private static PersistentDictionary _jsonPaths;
        private static PersistentDictionary JsonPaths => _jsonPaths ??= KSP2UnityToolsManager.GetDictionary("JsonPaths");

        private static PersistentDictionary _prefabAddressOverrides;
        private static PersistentDictionary PrefabAddressOverrides => _prefabAddressOverrides ??= KSP2UnityToolsManager.GetDictionary("PrefabAddressOverrides");

        private static PersistentDictionary _iconAddressOverrides;
        private static PersistentDictionary IconAddressOverrides => _iconAddressOverrides ??= KSP2UnityToolsManager.GetDictionary("IconAddressOverrides");
        

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

            // GUILayout.Label("Address Overrides (Only Works With Patch Manager)", EditorStyles.boldLabel);
            // var prefabAddress = "%NAME%.prefab";
            // var iconAddress = "%NAME%.png";
            // if (PrefabAddressOverrides.TryGetValue(TargetObject.name, out var newPrefabAddress))
            //     prefabAddress = newPrefabAddress;
            // if (IconAddressOverrides.TryGetValue(TargetObject.name, out var newIconAddress))
            //     iconAddress = newIconAddress;
            // PrefabAddressOverrides[TargetObject.name] =
            //     prefabAddress = EditorGUILayout.TextField("Prefab Address", prefabAddress);
            // IconAddressOverrides[TargetObject.name] =
            //     iconAddress = EditorGUILayout.TextField("Icon Address", iconAddress);
            
            GUILayout.Label("Part Saving", EditorStyles.boldLabel);
            var patchPath = "plugin_template/patches/%NAME%.patch";
            var jsonPath = "%NAME%.json";
            if (PatchPaths.TryGetValue(TargetObject.name, out var newPatchPath)) patchPath = newPatchPath;
            if (JsonPaths.TryGetValue(TargetObject.name, out var newJsonPath)) jsonPath = newJsonPath;
            PatchPaths[TargetObject.name] = patchPath = EditorGUILayout.TextField("Patch Path", patchPath);
            if (GUILayout.Button("Save Patch Manager Patch"))
            {
                if (!_initialized) Initialize();
                if (TargetCore == null) return;
                // Clear out the serialized part modules and reserialize them
                TargetCore.data.serializedPartModules.Clear();
                foreach (var child in TargetObject.GetComponents<Component>())
                {
                    if (!(child is PartBehaviourModule partBehaviourModule)) continue;
                    var addMethod =
                        child.GetType().GetMethod("AddDataModules", BindingFlags.Instance | BindingFlags.NonPublic) ??
                        child.GetType().GetMethod("AddDataModules", BindingFlags.Instance | BindingFlags.Public);
                    addMethod?.Invoke(child, new object[] { });
                    foreach (var data in partBehaviourModule.DataModules.Values)
                    {
                        var rebuildMethod =
                            data.GetType().GetMethod("RebuildDataContext",
                                BindingFlags.Instance | BindingFlags.NonPublic) ?? data.GetType()
                                .GetMethod("RebuildDataContext", BindingFlags.Instance | BindingFlags.Public);
                        rebuildMethod?.Invoke(data, new object[] { });
                    }

                    TargetCore.data.serializedPartModules.Add(new SerializedPartModule(partBehaviourModule, true));
                }

                var patchData = PatchManagerTools.CreatePatchData(TargetCore.data,null,null);
                var path = $"Assets/{patchPath}";
                path = path.Replace("%NAME%", TargetCore.data.partName);
                var directoryName = new FileInfo(path).DirectoryName;
                Directory.CreateDirectory(directoryName);
                File.WriteAllText($"{path}", patchData);
                AssetDatabase.ImportAsset(path);
                AssetDatabase.Refresh();
                AssetDatabase.SaveAssets();
                EditorUtility.DisplayDialog("Patch Exported", $"Patch is at: {path}", "ok"); 
            }
            JsonPaths[TargetObject.name] = jsonPath = EditorGUILayout.TextField("JSON Path", jsonPath);
            if (GUILayout.Button("Save Part JSON"))
            {
                if (!_initialized) Initialize();
                if (TargetCore == null) return;
                // Clear out the serialized part modules and reserialize them
                TargetCore.data.serializedPartModules.Clear();
                foreach (var child in TargetObject.GetComponents<Component>())
                {
                    if (!(child is PartBehaviourModule partBehaviourModule)) continue;
                    var addMethod =
                        child.GetType().GetMethod("AddDataModules", BindingFlags.Instance | BindingFlags.NonPublic) ??
                        child.GetType().GetMethod("AddDataModules", BindingFlags.Instance | BindingFlags.Public);
                    addMethod?.Invoke(child, new object[] { });
                    foreach (var data in partBehaviourModule.DataModules.Values)
                    {
                        var rebuildMethod =
                            data.GetType().GetMethod("RebuildDataContext",
                                BindingFlags.Instance | BindingFlags.NonPublic) ?? data.GetType()
                                .GetMethod("RebuildDataContext", BindingFlags.Instance | BindingFlags.Public);
                        rebuildMethod?.Invoke(data, new object[] { });
                    }

                    TargetCore.data.serializedPartModules.Add(new SerializedPartModule(partBehaviourModule, false));
                }

                var json = IOProvider.ToJson(TargetCore);
                var jObject = JObject.Parse(json);
                json = jObject.ToString(Formatting.Indented);
                var path = $"Assets/{jsonPath}";
                path = path.Replace("%NAME%", TargetCore.data.partName);
                var directoryName = new FileInfo(path).DirectoryName;
                Directory.CreateDirectory(directoryName);
                File.WriteAllText($"{path}", json);
                AssetDatabase.ImportAsset(path);
                AddressablesTools.MakeAddressable(path, $"{TargetCore.data.partName}.json", "parts_data");
                AssetDatabase.Refresh();
                AssetDatabase.SaveAssets();
                EditorUtility.DisplayDialog("Part Exported", $"Json is at: {path}", "ok");
            }
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
}