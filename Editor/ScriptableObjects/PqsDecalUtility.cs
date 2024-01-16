using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

namespace ksp2community.ksp2unitytools.editor.ScriptableObjects
{
    [CreateAssetMenu(fileName = "PqsDecalUtility",menuName = "KSP2UT/Pqs Decal Utility")]
    public class PqsDecalUtility : ScriptableObject
    {

        [Header("Decals")] 
        [Tooltip("A list of decal instances")]
        public List<PQSDecal> decals;

        [Header("Texture Arrays")] 
        [Tooltip("The diffuse textures for decals")]
        public Texture2DArray diffuse;
        [Tooltip("The normal textures for decals")]
        public Texture2DArray normal;
        [Tooltip("The alpha mask textures for decals")]
        public Texture2DArray alphaMask;
        [Tooltip("The peak textures for decals")]
        public Texture2DArray peak;
        [Tooltip("The slope textures for decals")]
        public Texture2DArray slope;
        
        [Header("Maps")]
        [Tooltip("A R16 texture containing the height data")]
        public Texture2D heightData;
        [Tooltip("A R16 texture containing the alpha data")]
        public Texture2D alphaData;
        
        
    }
}