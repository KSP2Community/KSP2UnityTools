using System;

namespace Editor.Editor
{
    [Serializable]
    public class ModDependency
    {
        public string Id = "";
        public string Min = "*";
        public string Max = "*";
    }
}