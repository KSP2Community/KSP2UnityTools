using System;
using System.Collections.Generic;
using KSP.Game.Science;
using Newtonsoft.Json;
using UniLinq;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor.ScriptableObjects
{
    [CreateAssetMenu(fileName = "ScienceRegions",menuName = "KSP2UT/Science Region Data")]
    public class ScienceRegionData : ScriptableObject
    {
        public Texture2D scienceRegionMap;
        public ScienceRegionDataInformation information = new();
        public List<CelestialBodyDiscoverablePosition> discoverables = new();
        
        private int ConvertToIndex(Color col)
        {
            var bestIndex = 0;
            var closestDistance = float.MaxValue;
            foreach (var region in information.ScienceRegionDefinitions)
            {
                var indexColor = region.RegionColor;
                var distanceSquared = (col.r - indexColor.r) * (col.r - indexColor.r) +
                                      (col.g - indexColor.g) * (col.g - indexColor.g) +
                                      (col.b - indexColor.b) * (col.b - indexColor.b);
                if (!(distanceSquared < closestDistance)) continue;
                closestDistance = distanceSquared;
                bestIndex = region.MapId;
            }
            return bestIndex;
        }

        public byte[] GetIndices() => !scienceRegionMap.isReadable
            ? new byte[scienceRegionMap.width * scienceRegionMap.height]
            : scienceRegionMap.GetPixels().Select(ConvertToIndex).Cast<byte>().ToArray();


        [Serializable]
        public class ScienceRegionDataInformation
        {
            public string Version;
            public string BodyName;
            public CBSituationData SituationData;
            public ExtendedScienceRegionDefinition[] ScienceRegionDefinitions;
        }

        [Serializable]
        public class ExtendedScienceRegionDefinition : ScienceRegionDefinition
        {
            [JsonIgnore]
            public Color RegionColor;
        }
    }
}