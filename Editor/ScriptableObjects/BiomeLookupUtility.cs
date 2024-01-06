using System;
using System.Collections.Generic;
using System.Linq;
using KSP.Rendering.Planets;
using UnityEngine;

namespace ksp2community.ksp2unitytools.editor.ScriptableObjects
{
    [CreateAssetMenu(fileName = "BiomeLookup",menuName = "KSP2UT/Biome Lookup Utility")]
    public class BiomeLookupUtility : ScriptableObject
    {
        public Texture2D biomeMap;

        public List<ColorInfo> colorMapping = new();


        private Color GetScaled(int scaledX, int scaledY)
        {
            var actualX = (int)((long)scaledX * biomeMap.width / 4096L);
            var actualY = (int)((long)scaledY * biomeMap.height / 4096L);
            return biomeMap.GetPixel(actualX, actualY);
        }
        
        private Color[,] GetColors(int cellX, int cellY)
        {
            var result = new Color[16, 16];
            var x16 = cellX * 16;
            var y16 = cellY * 16;
            if (biomeMap == null) return result;
            for (var y = 0; y < 16; y++)
            {
                var scaledY = y16 * 16 + y;
                for (var x = 0; x < 16; x++)
                {
                    result[y, x] = GetScaled(x16 + x, y16);
                }
            }
            return result;
        }

        private int ConvertToIndex(Color col)
        {
            var bestIndex = 0;
            var closestDistance = float.MaxValue;
            for (var i = 0; i < colorMapping.Count; i++)
            {
                var indexColor = colorMapping[i].color;
                var distanceSquared = (col.r - indexColor.r) * (col.r - indexColor.r) +
                                      (col.g - indexColor.g) * (col.g - indexColor.g) +
                                      (col.b - indexColor.b) * (col.b - indexColor.b) +
                                      (col.a - indexColor.a) * (col.a - indexColor.a);
                if (!(distanceSquared < closestDistance)) continue;
                closestDistance = distanceSquared;
                bestIndex = i;
            }
            return bestIndex;
        }

        private int[,] ConvertToIndices(Color[,] cell)
        {
            var result = new int[16, 16];
            for (var y = 0; y < 16; y++)
            {
                for (var x = 0; x < 16; x++)
                {
                    result[y, x] = ConvertToIndex(cell[y, x]);
                }
            }
            return result;
        }

        private static IEnumerable<RectangleInfo> Rectangles(int[,] indices)
        {
            var result = new List<RectangleInfo>();
            while (true)
            {
                int startX, startY, index;
                for (startY = 0; startY < 16; startY++)
                {
                    for (startX = 0; startX < 16; startX++)
                    {
                        index = indices[startY, startX];
                        if (!AlreadyMarked(startX, startY)) goto found_start;
                    }
                }
                break;
                found_start:
                int endX = startX, endY = startY;
                for (; endX < 16; endX++)
                {
                    if (indices[startY, endX] != index) break;
                }
                endX -= 1;

                for (; endY < 16; endY++)
                {
                    for (var x = startX; x <= endX; x++)
                    {
                        if (indices[endY, x] == index) continue;
                        goto found_end;
                    }
                }
                found_end:
                endY -= 1;

                result.Add(new RectangleInfo
                {
                    minX = startX, 
                    minY = startY, 
                    maxX = endX, 
                    maxY = endY, 
                    index = index
                });
            }

            return result;

            bool AlreadyMarked(int x, int y)
            {
                return result.Any(rectangle => x >= rectangle.minX && x <= rectangle.maxX && y >= rectangle.minY && y <= rectangle.maxY);
            }
        }

        public List<int> GetCell(int x, int y) => Rectangles(ConvertToIndices(GetColors(x, y)))
            .Select(rectangleInfo => rectangleInfo.ToPackedData(this)).ToList();


        private class RectangleInfo
        {
            internal int minX;
            internal int maxX;
            internal int minY;
            internal int maxY;
            internal int index;

            internal int ToPackedData(BiomeLookupUtility utility)
            {
                var info = utility.colorMapping[index];
                var type = info.type;
                return BiomeLookupHashTable.PackBiomeChunkData(minX, maxX, minY, maxY, (int)type, index);
            }
        }
        
        [Serializable]
        public class ColorInfo
        {
            public string name;
            public Color color;
            public PQSData.KSP2BiomeType type;
        }
    }
}