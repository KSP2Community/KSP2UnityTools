using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text.RegularExpressions;
using Cheese.Extensions;
using Editor.KSP2UnityTools.Editor;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UniLinq;
using UnityEditor;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Build;
using UnityEditor.AddressableAssets.Settings;
using UnityEngine;
using UnityEngine.UIElements;

namespace Editor.Editor
{
    public class KSP2UnityToolsWindow : EditorWindow
    {
        [MenuItem("Tools/KSP2 Unity Tools")]
        public static void ShowDevKit()
        {
            EditorWindow window = GetWindow<KSP2UnityToolsWindow>();
            window.titleContent = new GUIContent("KSP2 Unity Tools");
        }

        private ModInfo _projectModInfo;

        private void InitializeModInfo()
        {
            _projectModInfo = KSP2UnityToolsManager.ProjectModInfo;
        }

        private bool BuildEverything => KSP2UnityToolsManager.Settings.savedBuildMode == "Everything";
        private DropdownField _buildMode;
        private TextField _buildPath;
        private Button _browseBuildPath;
        private TextField _modId;
        private TextField _modName;
        private TextField _modAuthor;
        private TextField _modDescription;
        private TextField _modSource;
        private TextField _modVersion;
        private TextField _versionCheck;
        private Foldout _ksp2Version;
        private TextField _ksp2Min;
        private TextField _ksp2Max;
        private Foldout _dependencies;
        private Button _addDependency;
        private List<DependencyController> _dependencyControllers = new();
        private Foldout _conflicts;
        private Button _addConflict;
        private VisualElement _dependencyContainer;
        private VisualElement _conflictContainer;
        private VisualTreeAsset _dependencyTemplate;
        private Button _setupAddressables;
        private Button _generateSwinfo;
        private Button _importSwinfo;
        private Button _buildMod;
        
        
        private void CreateGUI()
        {
            InitializeModInfo();
            var doc = AssetDatabase
                .LoadAssetAtPath<VisualTreeAsset>(
                    "Packages/ksp2community.ksp2unitytools/Assets/KSP2UnityTools/KSP2UnityToolsSDK.uxml").Instantiate();
            _dependencyTemplate =
                AssetDatabase.LoadAssetAtPath<VisualTreeAsset>(
                    "Packages/ksp2community.ksp2unitytools/Assets/KSP2UnityTools/SwinfoDependency.uxml");
            rootVisualElement.Add(doc);
            _buildMode = doc.Q<DropdownField>("BuildMode");
            _buildMode.SetValueWithoutNotify(KSP2UnityToolsManager.Settings.savedBuildMode);
            _buildMode.RegisterValueChangedCallback(evt =>
            {
                KSP2UnityToolsManager.Settings.savedBuildMode = evt.newValue;
                EditorUtility.SetDirty(KSP2UnityToolsManager.Settings);
                UpdateModInfoDisplay();
            });
            _buildPath = doc.Q<TextField>("BuildPath");
            _buildPath.value = KSP2UnityToolsManager.Settings.savedBuildPath;
            _buildPath.RegisterValueChangedCallback(evt =>
            {
                KSP2UnityToolsManager.Settings.savedBuildPath = evt.newValue;
                EditorUtility.SetDirty(KSP2UnityToolsManager.Settings);
            });
            _browseBuildPath = doc.Q<Button>("BrowseBuildPath");
            _browseBuildPath.clicked += BrowseBuildPath;
            _modId = doc.Q<TextField>("ModID");
            _modId.RegisterValueChangedCallback(evt =>
            {
                _projectModInfo.id = evt.newValue;
                EditorUtility.SetDirty(_projectModInfo);
            });
            _modName = doc.Q<TextField>("ModName");
            _modName.RegisterValueChangedCallback(evt => { _projectModInfo.name = evt.newValue; 
                EditorUtility.SetDirty(_projectModInfo);});
            _modAuthor = doc.Q<TextField>("ModAuthor");
            _modAuthor.RegisterValueChangedCallback(evt => { _projectModInfo.author = evt.newValue; 
                EditorUtility.SetDirty(_projectModInfo);});
            _modDescription = doc.Q<TextField>("ModDescription");
            _modDescription.RegisterValueChangedCallback(evt => { _projectModInfo.description = evt.newValue; 
                EditorUtility.SetDirty(_projectModInfo);});
            _modSource = doc.Q<TextField>("ModSource");
            _modSource.RegisterValueChangedCallback(evt => { _projectModInfo.source = evt.newValue; 
                EditorUtility.SetDirty(_projectModInfo);});
            _modVersion = doc.Q<TextField>("Version");
            _modVersion.RegisterValueChangedCallback(evt => { _projectModInfo.version = evt.newValue; 
                EditorUtility.SetDirty(_projectModInfo);});
            _versionCheck = doc.Q<TextField>("VersionCheck");
            _versionCheck.RegisterValueChangedCallback(evt => { _projectModInfo.versionCheck = evt.newValue; 
                EditorUtility.SetDirty(_projectModInfo);});
            _ksp2Version = doc.Q<Foldout>("KSP2Version");
            _ksp2Min = doc.Q<TextField>("MinimumKSP2Version");
            _ksp2Min.RegisterValueChangedCallback(evt => { _projectModInfo.minKsp2Version = evt.newValue; 
                EditorUtility.SetDirty(_projectModInfo);});
            _ksp2Max = doc.Q<TextField>("MaximumKSP2Version");
            _ksp2Max.RegisterValueChangedCallback(evt => { _projectModInfo.maxKsp2Version = evt.newValue; 
                EditorUtility.SetDirty(_projectModInfo);});
            _dependencies = doc.Q<Foldout>("Dependencies");
            _dependencyContainer = doc.Q("DependencyContainer");
            _addDependency = doc.Q<Button>("AddDependency");
            _addDependency.clicked += AddDependency;
            _conflicts = doc.Q<Foldout>("Conflicts");
            _conflictContainer = doc.Q("ConflictContainer");
            _addConflict = doc.Q<Button>("AddConflict");
            _addConflict.clicked += AddConflict;
            _setupAddressables = doc.Q<Button>("AddressablesSetup");
            _setupAddressables.clicked += SetupAddressables;
            _generateSwinfo = doc.Q<Button>("GenerateSwinfo");
            _generateSwinfo.clicked += GenerateSwinfo;
            _importSwinfo = doc.Q<Button>("ImportSwinfo");
            _importSwinfo.clicked += ImportSwinfo;
            _buildMod = doc.Q<Button>("BuildMod");
            _buildMod.clicked += BuildAddressables;
            UpdateModInfoDisplay();
        }

        private void UpdateModInfoDisplay()
        {
            _modId.SetValueWithoutNotify(_projectModInfo.id);
            _dependencyControllers.Clear();
            if (BuildEverything)
            {
                _modName.SetVisibility(true);
                _modName.SetValueWithoutNotify(_projectModInfo.name);
                _modAuthor.SetVisibility(true);
                _modAuthor.SetValueWithoutNotify(_projectModInfo.author);
                _modDescription.SetVisibility(true);
                _modDescription.SetValueWithoutNotify(_projectModInfo.description);
                _modSource.SetVisibility(true);
                _modSource.SetValueWithoutNotify(_projectModInfo.source);
                _modVersion.SetVisibility(true);
                _modVersion.SetValueWithoutNotify(_projectModInfo.version);
                _versionCheck.SetVisibility(true);
                _versionCheck.SetValueWithoutNotify(_projectModInfo.versionCheck);
                _ksp2Version.SetVisibility(true);
                _ksp2Min.SetValueWithoutNotify(_projectModInfo.minKsp2Version);
                _ksp2Max.SetValueWithoutNotify(_projectModInfo.maxKsp2Version);
                _dependencies.SetVisibility(true);
                _conflicts.SetVisibility(true);
                _dependencyContainer.Clear();
                _conflictContainer.Clear();
                foreach (var dep in _projectModInfo.dependencies)
                {
                    var element = _dependencyTemplate.Instantiate();
                    _dependencyContainer.Add(element);
                    _dependencyControllers.Add(new(element, dep, dependency =>
                    {
                        _projectModInfo.dependencies.Remove(dependency);
                        EditorUtility.SetDirty(_projectModInfo);
                        UpdateModInfoDisplay();
                    }));
                }

                foreach (var dep in _projectModInfo.incompatibilities)
                {
                    var element = _dependencyTemplate.Instantiate();
                    _conflictContainer.Add(element);
                    _dependencyControllers.Add(new(element, dep, dependency =>
                    {
                        _projectModInfo.incompatibilities.Remove(dependency);
                        EditorUtility.SetDirty(_projectModInfo);
                        UpdateModInfoDisplay();
                    }));
                }
            }
            else
            {
                _modName.SetVisibility(false);
                _modAuthor.SetVisibility(false);
                _modDescription.SetVisibility(false);
                _modSource.SetVisibility(false);
                _modVersion.SetVisibility(false);
                _versionCheck.SetVisibility(false);
                _ksp2Version.SetVisibility(false);
                _dependencies.SetVisibility(false);
                _conflicts.SetVisibility(false);
            }
        }

        private void BrowseBuildPath()
        {
            var path = _buildPath.value;
            if (string.IsNullOrEmpty(path)) path = "Assets";
            _buildPath.value = BuildEverything ? EditorUtility.SaveFilePanel("Save Location", new FileInfo(path).DirectoryName, $"{_projectModInfo.id}.zip","zip") : EditorUtility.SaveFolderPanel("Save Location", path, "");
        }

        private void AddDependency()
        {
            _projectModInfo.dependencies.Add(new ()
            {
                Id = "",
                Min = "",
                Max = ""
            });
            EditorUtility.SetDirty(_projectModInfo);
            UpdateModInfoDisplay();
        }

        private void AddConflict()
        {
            _projectModInfo.incompatibilities.Add(new ()
            {
                Id = "",
                Min = "",
                Max = ""
            });
            UpdateModInfoDisplay();
            EditorUtility.SetDirty(_projectModInfo);
        }
        
        
        private void SetupAddressables()
        {
            if (AddressableAssetSettingsDefaultObject.Settings == null)
            {
                AddressableAssetSettingsDefaultObject.Settings = AddressableAssetSettings.Create(AddressableAssetSettingsDefaultObject.kDefaultConfigFolder,
                    AddressableAssetSettingsDefaultObject.kDefaultConfigAssetName, true, true);
            }

            var settings = AddressableAssetSettingsDefaultObject.Settings;
            var sanitizedId = _projectModInfo.SanitizedId;
            if (!settings.GetLabels().Contains("parts_data"))
            {
                settings.AddLabel("parts_data");
            }

            AddressableAssetGroup assetGroup;
            if (settings.groups.Any(x => x.name == sanitizedId))
            {
                assetGroup = settings.FindGroup(sanitizedId);
            }
            else
            {
                assetGroup = settings.CreateGroup(sanitizedId, true, false, false, settings.DefaultGroup.Schemas);
            }

            assetGroup.Settings.profileSettings.SetValue(assetGroup.Settings.activeProfileId,"Local.BuildPath","Library/com.unity.addressables/aa/Windows/StandaloneWindows64");
            assetGroup.Settings.profileSettings.SetValue(assetGroup.Settings.activeProfileId,"Local.LoadPath",$"{{SpaceWarpPaths.{sanitizedId}}}/addressables/StandaloneWindows64");
        }

        private void GenerateSwinfo()
        {
            _projectModInfo.GenerateSwinfo("Assets/swinfo.json");
        }

        private void ImportSwinfo()
        {
            var file = EditorUtility.OpenFilePanel("Swinfo Location", "Assets", "json");
            var data = JObject.Parse(File.ReadAllText(file));
            if (data.ContainsKey("mod_id")) _projectModInfo.id = data["mod_id"]!.Value<string>();
            if (data.ContainsKey("name")) _projectModInfo.name = data["name"]!.Value<string>();
            if (data.ContainsKey("author")) _projectModInfo.author = data["author"]!.Value<string>();
            if (data.ContainsKey("description")) _projectModInfo.description = data["description"]!.Value<string>();
            if (data.ContainsKey("source")) _projectModInfo.source = data["source"]!.Value<string>();
            if (data.TryGetValue("ksp2_version", out var value))
            {
                var ksp2Version = value as JObject;
                if (ksp2Version!.ContainsKey("min")) _projectModInfo.minKsp2Version = ksp2Version["min"]!.Value<string>();
                if (ksp2Version!.ContainsKey("max")) _projectModInfo.maxKsp2Version = ksp2Version["max"]!.Value<string>();
            }

            if (data.ContainsKey("version_check"))
                _projectModInfo.versionCheck = data["version_check"]!.Value<string>();
            _projectModInfo.dependencies.Clear();
            _projectModInfo.incompatibilities.Clear();
            if (data.TryGetValue("dependencies", out var dependencies))
            {
                var depJArray = dependencies as JArray;
                foreach (var dep in depJArray)
                {
                    var depJObject = dep as JObject;
                    ModDependency dependency = new();
                    if (depJObject.ContainsKey("id")) dependency.Id = depJObject["id"].Value<string>();
                    if (depJObject.TryGetValue("version", out var v))
                    {
                        var version = v as JObject;
                        if (version.ContainsKey("min")) dependency.Min = version["min"].Value<string>();
                        if (version.ContainsKey("max")) dependency.Max = version["max"].Value<string>();
                    }

                    _projectModInfo.dependencies.Add(dependency);
                }
            }
            
            if (data.TryGetValue("conflicts", out var conflicts))
            {
                var depJArray = conflicts as JArray;
                foreach (var dep in depJArray)
                {
                    var depJObject = dep as JObject;
                    ModDependency dependency = new();
                    if (depJObject.ContainsKey("id")) dependency.Id = depJObject["id"].Value<string>();
                    if (depJObject.TryGetValue("version", out var v))
                    {
                        var version = v as JObject;
                        if (version.ContainsKey("min")) dependency.Min = version["min"].Value<string>();
                        if (version.ContainsKey("max")) dependency.Max = version["max"].Value<string>();
                    }

                    _projectModInfo.incompatibilities.Add(dependency);
                }
            }
            
            EditorUtility.SetDirty(_projectModInfo);
            UpdateModInfoDisplay();
        }

        static void CopyDirectory(string sourceDir, string destinationDir, bool recursive)
        {
            // Get information about the source directory
            var dir = new DirectoryInfo(sourceDir);

            // Check if the source directory exists
            if (!dir.Exists)
                throw new DirectoryNotFoundException($"Source directory not found: {dir.FullName}");

            // Cache directories before we start copying
            DirectoryInfo[] dirs = dir.GetDirectories();

            // Create the destination directory
            Directory.CreateDirectory(destinationDir);

            // Get the files in the source directory and copy to the destination directory
            foreach (FileInfo file in dir.GetFiles())
            {
                string targetFilePath = Path.Combine(destinationDir, file.Name);
                file.CopyTo(targetFilePath);
            }

            // If recursive and copying subdirectories, recursively call this method
            if (recursive)
            {
                foreach (DirectoryInfo subDir in dirs)
                {
                    string newDestinationDir = Path.Combine(destinationDir, subDir.Name);
                    CopyDirectory(subDir.FullName, newDestinationDir, true);
                }
            }
        }
        
        private void BuildAddressables()
        {
            AddressableAssetSettings.BuildPlayerContent(out AddressablesPlayerBuildResult result);
            bool success = string.IsNullOrEmpty(result.Error);
            if (!success)
            {
                EditorUtility.DisplayDialog("Build Error", result.Error, "Acknowledge");
                return;
            }

            if (BuildEverything)
            {
                if (Directory.Exists("KSP2UnityToolsTempBuild"))
                {
                    Directory.Delete("KSP2UnityToolsTempBuild", true);
                }

                Directory.CreateDirectory("KSP2UnityToolsTempBuild");
                Directory.CreateDirectory("KSP2UnityToolsTempBuild/BepInEx");
                Directory.CreateDirectory("KSP2UnityToolsTempBuild/BepinEx/Plugins");
                Directory.CreateDirectory($"KSP2UnityToolsTempBuild/BepInEx/Plugins/{_projectModInfo.id}");
                Directory.CreateDirectory($"KSP2UnityToolsTempBuild/BepInEx/Plugins/{_projectModInfo.id}/localizations");
                Directory.CreateDirectory($"KSP2UnityToolsTempBuild/BepInEx/Plugins/{_projectModInfo.id}/addressables");
                _projectModInfo.GenerateSwinfo(
                    $"KSP2UnityToolsTempBuild/Bepinex/Plugins/{_projectModInfo.id}/swinfo.json");
                if (Directory.Exists("Assets/localizations"))
                {
                    foreach (var file in Directory.EnumerateFiles("Assets/localizations"))
                    {
                        if (file.EndsWith(".csv") || file.EndsWith(".i2csv"))
                        {
                            FileInfo f = new FileInfo(file);
                            File.Copy(file,$"KSP2UnityToolsTempBuild/BepInEx/Plugins/{_projectModInfo.id}/localizations{f.Name}");
                        }
                    }
                }
                CopyDirectory("Library/com.unity.addressables/aa/Windows",
                    $"KSP2UnityToolsTempBuild/BepInEx/Plugins/{_projectModInfo.id}/addressables", true);
                if (File.Exists(_buildPath.text)) File.Delete(_buildPath.text);
                ZipFile.CreateFromDirectory("KSP2UnityToolsTempBuild", _buildPath.text);
            }
            else
            {
                if (Directory.Exists(_buildPath.text))
                {
                    Directory.Delete(_buildPath.text,true);
                }
                CopyDirectory("Library/com.unity.addressables/aa/Windows",
                    _buildPath.text, true);
            }
        }
    }
}