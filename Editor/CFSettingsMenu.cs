using System.IO;
using UnityEditor;
using UnityEngine;

namespace CausalFoundry.Unity.Editor
{
    internal static class CFSettingsMenu
    {
        private const string AssetDirectory = "Assets/Resources";
        private const string AssetPath = AssetDirectory + "/CausalFoundrySettings.asset";

        [MenuItem("Tools/Causal Foundry/Create or Select SDK Settings", priority = 100)]
        private static void CreateOrSelectSettings()
        {
            CFSettings settings =
                AssetDatabase.LoadAssetAtPath<CFSettings>(AssetPath);
            if (settings == null)
            {
                if (!Directory.Exists(AssetDirectory))
                {
                    Directory.CreateDirectory(AssetDirectory);
                }

                settings = ScriptableObject.CreateInstance<CFSettings>();
                AssetDatabase.CreateAsset(settings, AssetPath);
                AssetDatabase.SaveAssets();
            }

            Selection.activeObject = settings;
            EditorGUIUtility.PingObject(settings);
        }
    }
}
