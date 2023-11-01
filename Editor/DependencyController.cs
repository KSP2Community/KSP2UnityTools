using System;
using UnityEngine.UIElements;

namespace ksp2community.ksp2unitytools.editor
{
    public class DependencyController
    {
        public DependencyController(VisualElement element, ModDependency dep, Action<ModDependency> cb)
        {
            var id = element.Q<TextField>("DependencyID");
            id.value = dep.Id;
            id.RegisterValueChangedCallback(evt => { dep.Id = evt.newValue; });
            var min = element.Q<TextField>("DependencyMin");
            min.value = dep.Min;
            min.RegisterValueChangedCallback(evt => { dep.Min = evt.newValue; });
            var max = element.Q<TextField>("DependencyMax");
            max.value = dep.Max;
            max.RegisterValueChangedCallback(evt => { dep.Max = evt.newValue; });
            var remove = element.Q<Button>("Remove");
            remove.clicked += () => { cb.Invoke(dep); };
        }
    }
}