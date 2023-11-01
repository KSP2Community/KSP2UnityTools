using System;

namespace ksp2community.ksp2unitytools.editor
{
    [Serializable]
    public class ModDependency
    {
        public string Id = "";
        public string Min = "*";
        public string Max = "*";
    }
}