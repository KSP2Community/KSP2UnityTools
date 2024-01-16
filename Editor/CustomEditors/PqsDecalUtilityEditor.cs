using System.IO;
using ksp2community.ksp2unitytools.editor.ScriptableObjects;
using UniLinq;
using UnityEditor;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor.CustomEditors
{
    [CustomEditor(typeof(PqsDecalUtility))]
    public class PqsDecalUtilityEditor : UnityEditor.Editor
    {
        private static PersistentDictionary _pqsDecalDataNames;

        private static PersistentDictionary PqsDecalNames =>
            _pqsDecalDataNames ??= KSP2UnityToolsManager.GetDictionary("PqsDecalNames");
        
        private PqsDecalUtility Target => target as PqsDecalUtility;

        private static (ushort[] data, int width, int height) GetDataFrom(Texture2D texture16)
        {
            var rawData = texture16.GetRawTextureData<ushort>();
            Debug.Log($"Native Length: {rawData.Length}, Target Length: {texture16.width}, {texture16.height}");
            var data = new ushort[texture16.width * texture16.height];
            rawData.CopyTo(data);
            return (data, texture16.width, texture16.height);
        }
        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
            GUILayout.Label("PQS Decal Data Baking", EditorStyles.boldLabel);
            var dataName = PqsDecalNames.TryGetValue(Target.name, out var newDataName) ? newDataName : "NewPQSData";
            PqsDecalNames[Target.name] = dataName = EditorGUILayout.TextField("Data Asset Name", dataName);
            if (GUILayout.Button("Bake"))
            {
                var decalData = CreateInstance<PQSDecalData>();
                decalData.BakedPqsDecalList = Target.decals;
                decalData.BakedPqsDecalIDList = Target.decals.Select(x => x.DecalID).ToList();
                decalData.DiffuseTextureArray = Target.diffuse;
                decalData.NormalTextureArray = Target.normal;
                decalData.AlphaMaskTextureArray = Target.alphaMask;
                decalData.PeakTextureArray = Target.peak;
                decalData.SlopeTextureArray = Target.slope;
                decalData.Count = Target.decals.Count;
                (decalData.HeightData, decalData.HeightWidth, decalData.HeightHeight) = GetDataFrom(Target.heightData);
                (decalData.AlphaData, decalData.AlphaWidth, decalData.AlphaHeight) = GetDataFrom(Target.alphaData);
                var path = AssetDatabase.GetAssetPath(Target);
                if (path == "")
                {
                    path = "Assets";
                }
                else if (Path.GetExtension(path) != "")
                {
                    path = path.Replace(Path.GetFileName(AssetDatabase.GetAssetPath(Selection.activeObject)), "");
                }

                if (File.Exists($"{path}/{dataName}.asset")) AssetDatabase.DeleteAsset($"{path}/{dataName}.asset");
                AssetDatabase.CreateAsset(decalData,$"{path}/{dataName}.asset");
                AssetDatabase.Refresh();
            }
        }
    }
}