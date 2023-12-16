using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using JetBrains.Annotations;
using KSP.IO;
using KSP.Modules;
using KSP.Sim;
using KSP.Sim.Definitions;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor.API
{

    public static class PatchManagerTools
    {
        public static List<Type> ModuleDataSubtypes =
            AppDomain.CurrentDomain.GetAssemblies().SelectMany(x => x.GetTypes()).Where(type => type.GetFields(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic).Any(
                x => x.GetCustomAttributes().Any(y => y is KSPStateAttribute or KSPDefinitionAttribute)
                )).ToList();
        private static void Indent(this StringBuilder sb, int indentation)
        {
            for (var i = 0; i < indentation; i++) sb.Append("    ");
        }
        
        [PublicAPI]
        public static string CreatePatchData(PartData partData, string prefabAddress ="",string iconAddress="")
        {
            if (string.IsNullOrEmpty(prefabAddress)) prefabAddress = $"{partData.partName}.prefab";
            if (string.IsNullOrEmpty(iconAddress)) iconAddress = $"{partData.partName}.png";
            StringBuilder sb = new StringBuilder();
            sb.Append($"@new({ToLiteral(partData.partName)})\n");
            sb.Append(":parts {\n");
            var indentation = 1;
            
            sb.Indent(indentation);
            sb.Append("/*\n");
            sb.Indent(indentation);
            sb.Append("  +-------------------------+\n");
            sb.Indent(indentation);
            sb.Append("  | Asset Loading Overrides |\n");
            sb.Indent(indentation);
            sb.Append("  +-------------------------+\n");
            sb.Indent(indentation);
            sb.Append("*/\n\n");
            sb.Indent(indentation);
            sb.Append("/* The addressables address to load the part prefab from */\n");
            sb.Indent(indentation);
            sb.Append($"PrefabAddress: {ToLiteral(prefabAddress)};\n");
            sb.Indent(indentation);
            sb.Append("/* The addressables address to load the part icon from */\n");
            sb.Indent(indentation);
            sb.Append($"IconAddress: {ToLiteral(iconAddress)};\n");

            foreach (var field in partData.GetType().GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
            {
                var attributes = field.GetCustomAttributes().ToArray();
                if (attributes.OfType<HeaderAttribute>().FirstOrDefault() is { } headerAttribute)
                {
                    var str = headerAttribute.header;
                    var lines = str.Split('\n', StringSplitOptions.RemoveEmptyEntries);
                    var maxLength = lines.Select(x => x.Trim().Length).Max();
                    sb.Append('\n');
                    sb.Indent(indentation);
                    sb.Append("/*\n");
                    sb.Indent(indentation);
                    sb.Append("  +-");
                    for (var i = 0; i < maxLength; i++)
                    {
                        sb.Append('-');
                    }
                    sb.Append("-+\n");
                    foreach (var line in lines)
                    {
                        sb.Indent(indentation);
                        sb.Append("  | ");
                        sb.Append(line.Trim());
                        sb.Append(" |");
                        sb.Append('\n');
                    }
                    sb.Indent(indentation);
                    sb.Append("  +-");
                    for (var i = 0; i < maxLength; i++)
                    {
                        sb.Append('-');
                    }
                    sb.Append("-+\n");

                    sb.Indent(indentation);
                    sb.Append("*/\n");
                    sb.Append("\n");
                }
                
                if (field.Name == "serializedPartModules") continue;
                if (field.Name == "resourceContainers") continue;
                if (field.Name == "partName") continue;

                if (attributes.OfType<TooltipAttribute>().FirstOrDefault() is { } tooltipAttribute)
                {
                    var tooltip = tooltipAttribute.tooltip;
                    var lines = tooltip.Split('\n', StringSplitOptions.RemoveEmptyEntries);
                    if (lines.Length == 1)
                    {
                        sb.Indent(indentation);
                        sb.Append("/* ");
                        sb.Append(lines[0].Trim());
                        sb.Append(" */\n");
                    }
                    else
                    {
                        sb.Indent(indentation);
                        sb.Append("/*\n");
                        foreach (var line in lines)
                        {
                            sb.Indent(indentation);
                            sb.Append("  ");
                            sb.Append(line.Trim());
                            sb.Append('\n');
                        }

                        sb.Indent(indentation);
                        sb.Append("*/\n");
                    }
                }
                
                sb.Indent(indentation);
                var key = field.Name;
                if (!IsValidIdentifier(key)) key = ToLiteral(key);
                sb.Append($"{key}: ");
                var value = JToken.Parse(IOProvider.ToJson(field.GetValue(partData)));
                JsonToDataValue(sb, value, indentation, true);
                sb.Append(";\n");
            }

            sb.Append('\n');
            sb.Indent(indentation);
            sb.Append("/*\n");
            sb.Indent(indentation);
            sb.Append("  +-----------------------+\n");
            sb.Indent(indentation);
            sb.Append("  | Resources and Modules |\n");
            sb.Indent(indentation);
            sb.Append("  +-----------------------+\n");
            sb.Indent(indentation);
            sb.Append("*/\n\n");
            
            sb.Indent(indentation);
            sb.Append("* > resourceContainers {\n");
            foreach (var resourceContainer in partData.resourceContainers)
            {
                sb.Indent(indentation + 1);
                sb.Append($"+{resourceContainer.name} {{\n");
                sb.Indent(indentation + 2);
                sb.Append($"capacityUnits: {resourceContainer.capacityUnits};\n");
                sb.Indent(indentation + 2);
                sb.Append($"initialUnits: {resourceContainer.initialUnits};\n");
                sb.Indent(indentation + 2);
                sb.Append($"NonStageable: {(resourceContainer.NonStageable ? "true" : "false")};\n");
                sb.Indent(indentation + 1);
                sb.Append("}\n");
            }
            sb.Indent(indentation);
            sb.Append("}\n");
            foreach (var module in partData.serializedPartModules)
            {
                AddModuleToPatch(sb, module, indentation);
            }
            sb.Append("}");
            return sb.ToString();
        }

        public static string CreatePatchFileData(string ruleset, object value, params object[] constructorArguments)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("@new(");
            var first = true;
            foreach (var obj in constructorArguments)
            {
                if (first)
                {
                    first = false;
                }
                else
                {
                    sb.Append(", ");
                }

                var jsonObject = JToken.Parse(IOProvider.ToJson(obj));
                JsonToDataValue(sb,jsonObject);
            }
            sb.Append($")\n:{ruleset} {{\n");
            var indentation = 1;
            foreach (var field in value.GetType().GetFields(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
            {
                var attributes = field.GetCustomAttributes().ToArray();
                if (attributes.OfType<HeaderAttribute>().FirstOrDefault() is { } headerAttribute)
                {
                    var str = headerAttribute.header;
                    var lines = str.Split('\n', StringSplitOptions.RemoveEmptyEntries);
                    var maxLength = lines.Select(x => x.Trim().Length).Max();
                    sb.Append('\n');
                    sb.Indent(indentation);
                    sb.Append("/*\n");
                    sb.Indent(indentation);
                    sb.Append("  +-");
                    for (var i = 0; i < maxLength; i++)
                    {
                        sb.Append('-');
                    }
                    sb.Append("-+\n");
                    foreach (var line in lines)
                    {
                        sb.Indent(indentation);
                        sb.Append("  | ");
                        sb.Append(line.Trim());
                        sb.Append(" |");
                        sb.Append('\n');
                    }
                    sb.Indent(indentation);
                    sb.Append("  +-");
                    for (var i = 0; i < maxLength; i++)
                    {
                        sb.Append('-');
                    }
                    sb.Append("-+\n");

                    sb.Indent(indentation);
                    sb.Append("*/\n");
                    sb.Append("\n");
                }
                if (attributes.OfType<TooltipAttribute>().FirstOrDefault() is { } tooltipAttribute)
                {
                    var tooltip = tooltipAttribute.tooltip;
                    var lines = tooltip.Split('\n', StringSplitOptions.RemoveEmptyEntries);
                    if (lines.Length == 1)
                    {
                        sb.Indent(indentation);
                        sb.Append("/* ");
                        sb.Append(lines[0].Trim());
                        sb.Append(" */\n");
                    }
                    else
                    {
                        sb.Indent(indentation);
                        sb.Append("/*\n");
                        foreach (var line in lines)
                        {
                            sb.Indent(indentation);
                            sb.Append("  ");
                            sb.Append(line.Trim());
                            sb.Append('\n');
                        }

                        sb.Indent(indentation);
                        sb.Append("*/\n");
                    }
                }
                
                sb.Indent(indentation);
                var key = field.Name;
                if (!IsValidIdentifier(key)) key = ToLiteral(key);
                sb.Append($"{key}: ");
                var val = JToken.Parse(IOProvider.ToJson(field.GetValue(value)));
                JsonToDataValue(sb, val, indentation, true);
                sb.Append(";\n");
            }

            sb.Append("}");
            return sb.ToString();
        }

        private static string ToLiteral(string input) {
            var literal = new StringBuilder(input.Length + 2);
            literal.Append("\"");
            foreach (var c in input) {
                switch (c) {
                    case '\"': literal.Append("\\\""); break;
                    case '\\': literal.Append(@"\\"); break;
                    case '\0': literal.Append(@"\0"); break;
                    case '\a': literal.Append(@"\a"); break;
                    case '\b': literal.Append(@"\b"); break;
                    case '\f': literal.Append(@"\f"); break;
                    case '\n': literal.Append(@"\n"); break;
                    case '\r': literal.Append(@"\r"); break;
                    case '\t': literal.Append(@"\t"); break;
                    case '\v': literal.Append(@"\v"); break;
                    default:
                        // ASCII printable character
                        if (c >= 0x20 && c <= 0x7e) {
                            literal.Append(c);
                            // As UTF16 escaped character
                        } else {
                            literal.Append(@"\u");
                            literal.Append(((int)c).ToString("x4"));
                        }
                        break;
                }
            }
            literal.Append("\"");
            return literal.ToString();
        }

        private static bool IsValidIdentifier(string name) => Regex.IsMatch(name, "[a-zA-Z_]([a-zA-Z_.0-9]|[\\-][a-zA-Z])*");

        public const string DoubleFixedPoint =
            "0.###################################################################################################################################################################################################################################################################################################################################################";
        public static void JsonToDataValue(StringBuilder sb, JToken token, int indentation=-1, bool wrapNegatives = false)
        {
            if (token == null) sb.Append("null");
            while (token.Type == JTokenType.Property) token = ((JProperty)token).Value;
            switch (token.Type)
            {
                case JTokenType.Null or JTokenType.None:
                    sb.Append("null");
                    break;
                case JTokenType.Float:
                {
                    var floatString = ((double)token).ToString(DoubleFixedPoint, CultureInfo.InvariantCulture)
                        .TrimEnd('0');
                    if (!floatString.Contains(".")) floatString = floatString + ".0";
                    if (floatString == ".0") floatString = "0.0";
                    if (wrapNegatives && (double)token < 0) floatString = $"({floatString})";
                    sb.Append(floatString);
                    break;
                }
                case JTokenType.Integer:
                {
                    var intString = ((long)token).ToString(CultureInfo.InvariantCulture);
                    if (wrapNegatives && (long)token < 0) intString = $"({intString})";
                    sb.Append(intString);
                    break;
                }
                case JTokenType.Boolean:
                    sb.Append((bool)token ? "true" : "false");
                    break;
                case JTokenType.String or JTokenType.Date:
                    sb.Append(ToLiteral((string)token));
                    break;
                case JTokenType.Array:
                {
                    sb.Append("[");
                    bool first = true;
                    foreach (var jToken in token)
                    {
                        if (first) first = false;
                        else sb.Append(", ");
                        JsonToDataValue(sb, jToken, indentation);
                    }

                    sb.Append("]");
                    break;
                }
                case JTokenType.Object:
                {
                    sb.Append("{");
                    if (indentation != -1 && token.Values().Any())
                    {
                        sb.Append("\n");
                        sb.Indent(indentation + 1);
                    }
                    bool first = true;
                    foreach (var jToken in token)
                    {
                        var property = (JProperty)jToken;
                        if (first) first = false;
                        else
                        {
                            if (indentation != -1)
                            {
                                sb.Append(",\n");
                                sb.Indent(indentation + 1);
                            }
                            else
                            {
                                sb.Append(", ");
                            }
                        }

                        var key = property.Name;
                        if (!IsValidIdentifier(key)) key = ToLiteral(key);
                        sb.Append($"{key}: ");
                        JsonToDataValue(sb, property.Value, indentation >= 0 ? indentation + 1 : indentation);
                    }

                    if (!first && indentation != -1)
                    {
                        sb.Append("\n");
                        sb.Indent(indentation);
                    }

                    sb.Append("}");
                    break;
                }
                default:
                    sb.Append("null");
                    break;
            }
        }

        

        public static void AddDataToModule(StringBuilder sb, object data, int indentation, bool useSemicolons = false)
        {
            var objType = data.GetType();
            
            if (data is ModuleData || ModuleDataSubtypes.Contains(objType))
            {
                int internalIndentation = indentation;
                if (!useSemicolons)
                {
                    internalIndentation = indentation + 1;
                    sb.Append("{\n");
                }

                foreach (var field in objType.GetFields(BindingFlags.Instance | BindingFlags.Public |
                                                        BindingFlags.NonPublic))
                {
                    var attrs = field.GetCustomAttributes().ToList();
                    if (attrs.OfType<HeaderAttribute>().FirstOrDefault() is { } headerAttribute)
                    {
                        var str = headerAttribute.header;
                        var lines = str.Split('\n', StringSplitOptions.RemoveEmptyEntries);
                        var maxLength = lines.Select(x => x.Trim().Length).Max();
                        sb.Append('\n');
                        sb.Indent(internalIndentation);
                        sb.Append("/*\n");
                        sb.Indent(internalIndentation);
                        sb.Append("  +-");
                        for (var i = 0; i < maxLength; i++)
                        {
                            sb.Append('-');
                        }
                        sb.Append("-+\n");
                        foreach (var line in lines)
                        {
                            sb.Indent(internalIndentation);
                            sb.Append("  | ");
                            sb.Append(line.Trim());
                            sb.Append(" |");
                            sb.Append('\n');
                        }
                        sb.Indent(internalIndentation);
                        sb.Append("  +-");
                        for (var i = 0; i < maxLength; i++)
                        {
                            sb.Append('-');
                        }
                        sb.Append("-+\n");

                        sb.Indent(internalIndentation);
                        sb.Append("*/\n");
                        sb.Append("\n");
                    }
                    
                    if (attrs.OfType<JsonIgnoreAttribute>().FirstOrDefault() is not null) continue;
                    if (attrs.OfType<KSPStateAttribute>().FirstOrDefault() is not null) continue;
                    if (attrs.OfType<KSPDefinitionAttribute>().FirstOrDefault() is null) continue;
                    string tooltip = null;
                    if (attrs.OfType<TooltipAttribute>().FirstOrDefault() is { } tooltipAttribute)
                        tooltip = tooltipAttribute.tooltip;
                    if (tooltip != null)
                    {
                        var lines = tooltip.Split('\n', StringSplitOptions.RemoveEmptyEntries);
                        if (lines.Length == 1)
                        {
                            sb.Indent(internalIndentation);
                            sb.Append("/* ");
                            sb.Append(lines[0].Trim());
                            sb.Append(" */\n");
                        }
                        else
                        {
                            sb.Indent(internalIndentation);
                            sb.Append("/*\n");
                            foreach (var line in lines)
                            {
                                sb.Indent(internalIndentation);
                                sb.Append("  ");
                                sb.Append(line.Trim());
                                sb.Append('\n');
                            }

                            sb.Indent(internalIndentation);
                            sb.Append("*/\n");
                        }
                    }

                    var key = field.Name;
                    if (!IsValidIdentifier(key)) key = ToLiteral(key);
                    sb.Indent(internalIndentation);
                    sb.Append(key);
                    sb.Append(": ");
                    var value = field.GetValue(data);
                    AddDataToModule(sb, value, internalIndentation);
                    var ch = useSemicolons ? ';' : ',';
                    sb.Append($"{ch}\n");
                }

                if (!useSemicolons)
                {
                    sb.Indent(indentation);
                    sb.Append("}");
                }
            }
            else if (objType.IsArray)
            {
                var elementType = objType.GetElementType();
                if (ModuleDataSubtypes.Contains(elementType))
                {
                    var array = (Array)data;
                    if (array.Length == 0)
                    {
                        sb.Append("[]");
                        return;
                    }

                    sb.Append('[');
                    var first = true;
                    foreach (var obj in array)
                    {
                        
                        if (first)
                        {
                            sb.Append("\n");
                            sb.Indent(indentation + 1);
                            first = false;
                        }
                        else
                        {
                            sb.Append(",\n");
                            sb.Indent(indentation + 1);
                        }

                        AddDataToModule(sb, obj, indentation + 1);
                    }

                    sb.Append('\n');
                    sb.Indent(indentation);
                    sb.Append(']');
                }
                else
                {
                    var obj = JToken.Parse(IOProvider.ToJson(data));
                    JsonToDataValue(sb,obj,indentation,useSemicolons);
                }
            }
            else if (objType.IsGenericType && (objType.GetGenericTypeDefinition() == typeof(List<>)))
            {
                var elementType = objType.GetGenericArguments()[0];
                if (ModuleDataSubtypes.Contains(elementType))
                {
                    var list = (IList)data;
                    if (list.Count == 0)
                    {
                        sb.Append("[]");
                        return;
                    }

                    sb.Append('[');
                    var first = true;
                    foreach (var obj in list)
                    {
                        
                        if (first)
                        {
                            sb.Append("\n");
                            sb.Indent(indentation + 1);
                            first = false;
                        }
                        else
                        {
                            sb.Append(",\n");
                            sb.Indent(indentation + 1);
                        }

                        AddDataToModule(sb, obj, indentation + 2);
                    }

                    sb.Append('\n');
                    sb.Indent(indentation);
                    sb.Append(']');
                }
                else
                {
                    var obj = JToken.Parse(IOProvider.ToJson(data));
                    JsonToDataValue(sb,obj,indentation,useSemicolons);
                }
            }
            else
            {
                var obj = JToken.Parse(IOProvider.ToJson(data));
                JsonToDataValue(sb,obj,indentation,useSemicolons);
            }
        }
        
        public static void AddModuleToPatch(StringBuilder sb, SerializedPartModule partModule, int indentation)
        {
            sb.Indent(indentation);
            var name = partModule.Name.Replace("PartComponent", "");
            sb.Append($"+{name} {{\n");
            var nextIndentation = indentation + 1;
            foreach (var data in partModule.ModuleData)
            {
                sb.Indent(nextIndentation);
                sb.Append($"+{data.Name} {{\n");
                var obj = data.DataObject;
                var nextNextIndentation = nextIndentation + 1;
                AddDataToModule(sb, obj, nextNextIndentation, true);
                sb.Indent(nextIndentation);
                sb.Append("}\n");
            }
            sb.Indent(indentation);
            sb.Append("}\n");
        }
    }
}