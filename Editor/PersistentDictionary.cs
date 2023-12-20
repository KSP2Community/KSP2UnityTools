using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor
{

    public class PersistentDictionary : ScriptableObject
    {
        public List<string> Keys = new();
        public List<string> Values = new();

        public void OnEnable()
        {
            if (Keys.Count != Values.Count)
            {
                Keys.Clear();
                Values.Clear();
            }
        }

        public bool Contains(string key) => Keys.Contains(key);

        public void Remove(string key)
        {
            var index = IndexOf(key);
            if (index != -1)
            {
                Keys.RemoveAt(index);
                Values.RemoveAt(index);
            }

            EditorUtility.SetDirty(this);
        }

        private int IndexOf(string key) => Keys.IndexOf(key);

        public bool TryGetValue(string key, out string value)
        {
            var index = IndexOf(key);
            if (index == -1)
            {
                value = null;
                return false;
            }
            else
            {
                value = Values[index];
                return true;
            }
        }
        
        public string this[string key]
        {
            get
            {
                var index = IndexOf(key);
                if (index == -1)
                {
                    throw new KeyNotFoundException(key);
                }
                else
                {
                    return Values[index];
                }
            }
            set
            {
                EditorUtility.SetDirty(this);
                var index = IndexOf(key);
                if (index == -1)
                {
                    Keys.Add(key);
                    Values.Add(value);
                }
                else
                {
                    Values[index] = value;
                }
            }
        }
    }
}