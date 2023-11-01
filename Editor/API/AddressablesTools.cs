using UnityEditor;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;

namespace ksp2community.ksp2unitytools.editor.API
{
    public static class AddressablesTools
    {
        public static void MakeAddressable(string assetPath, string name, params string[] labels)
        {
            var settings = AddressableAssetSettingsDefaultObject.Settings;
            var group = settings.FindGroup(KSP2UnityToolsManager.ProjectModInfo.SanitizedId);
            var guid = AssetDatabase.AssetPathToGUID(assetPath);
            var entry = settings.CreateOrMoveEntry(guid, group);
            foreach (var label in labels)
            {
                entry.labels.Add(label);
            }
            entry.address = name;
            settings.SetDirty(AddressableAssetSettings.ModificationEvent.EntryMoved, entry, true);
        }
    }
}