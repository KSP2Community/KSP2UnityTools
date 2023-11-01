using UnityEngine.UIElements;

namespace ksp2community.ksp2unitytools.editor.Editor.Extensions
{
    public static class VisualElementExtensions
    {
        public static void SetVisibility(this VisualElement element, bool visibility)
        {
            if (visibility)
            {
                element.visible = true;
                element.style.display = DisplayStyle.Flex;
            }
            else
            {
                element.visible = false;
                element.style.display = DisplayStyle.None;
            }
        }
    }
}