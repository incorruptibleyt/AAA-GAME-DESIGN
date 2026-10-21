using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace CryptCrawl.EditorTools
{
    /// <summary>
    /// Runs automatically when Unity opens the project. Creates the game scene, the
    /// template materials the game needs on phones, and sets sensible phone settings.
    /// You can run it again any time from the menu: Crypt Crawl > Set Up Project.
    /// </summary>
    [InitializeOnLoad]
    public static class ProjectSetup
    {
        public const string Root = "Assets/CryptCrawl";
        public const string ResourcesDir = Root + "/Resources/CryptCrawl";
        public const string ScenePath = Root + "/Scenes/Main.unity";

        static ProjectSetup()
        {
            EditorApplication.delayCall += () =>
            {
                if (EditorApplication.isPlayingOrWillChangePlaymode) return;
                EnsureMaterials();
                EnsureScene(openIfIdle: true);
                string key = "CryptCrawl.PlayerSettings." + Application.dataPath;
                if (!EditorPrefs.GetBool(key, false))
                {
                    ApplyPlayerSettings();
                    EditorPrefs.SetBool(key, true);
                }
            };
        }

        [MenuItem("Crypt Crawl/Set Up Project", priority = 0)]
        public static void SetUpFromMenu()
        {
            EnsureMaterials();
            EnsureScene(openIfIdle: false);
            ApplyPlayerSettings();
            if (EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
                EditorSceneManager.OpenScene(ScenePath);
            EditorUtility.DisplayDialog("Crypt Crawl", "Project set up.\n\nPress the Play button (top middle of Unity) to play.", "OK");
        }

        [MenuItem("Crypt Crawl/Play", priority = 1)]
        public static void PlayFromMenu()
        {
            EnsureScene(openIfIdle: false);
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            EditorSceneManager.OpenScene(ScenePath);
            EditorApplication.isPlaying = true;
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            string parent = Path.GetDirectoryName(path).Replace('\\', '/');
            EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, Path.GetFileName(path));
        }

        /// <summary>
        /// Materials kept in Resources make sure their shaders (and the glow variant) are
        /// included when building for a phone. Re-pointed automatically if you switch to URP.
        /// </summary>
        public static void EnsureMaterials()
        {
            EnsureFolder(ResourcesDir);
            EnsureMaterial("Lit", MaterialLibrary.FindLitShader(), false);
            EnsureMaterial("LitEmissive", MaterialLibrary.FindLitShader(), true);
            EnsureMaterial("Unlit", MaterialLibrary.FindUnlitShader(), false);
            AssetDatabase.SaveAssets();
        }

        static void EnsureMaterial(string name, Shader shader, bool emissive)
        {
            if (shader == null) return;
            string path = $"{ResourcesDir}/{name}.mat";
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (mat == null)
            {
                mat = new Material(shader);
                AssetDatabase.CreateAsset(mat, path);
            }
            else if (mat.shader != shader)
            {
                mat.shader = shader;
            }
            if (emissive)
            {
                mat.EnableKeyword("_EMISSION");
                mat.SetColor("_EmissionColor", Color.white);
                mat.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
            }
            EditorUtility.SetDirty(mat);
        }

        public static void EnsureScene(bool openIfIdle)
        {
            if (!File.Exists(ScenePath))
            {
                EnsureFolder(Path.GetDirectoryName(ScenePath).Replace('\\', '/'));
                var active = SceneManager.GetActiveScene();
                bool idle = string.IsNullOrEmpty(active.path) && !active.isDirty;
                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, idle ? NewSceneMode.Single : NewSceneMode.Additive);
                EditorSceneManager.SaveScene(scene, ScenePath);
                if (!idle) EditorSceneManager.CloseScene(scene, true);
                AssetDatabase.Refresh();
            }

            var scenes = EditorBuildSettings.scenes;
            if (scenes.Length == 0 || scenes[0].path != ScenePath)
            {
                var list = new System.Collections.Generic.List<EditorBuildSettingsScene> { new EditorBuildSettingsScene(ScenePath, true) };
                foreach (var s in scenes) if (s.path != ScenePath) list.Add(s);
                EditorBuildSettings.scenes = list.ToArray();
            }

            if (openIfIdle)
            {
                var active = SceneManager.GetActiveScene();
                if (active.path != ScenePath && string.IsNullOrEmpty(active.path) && !active.isDirty)
                    EditorSceneManager.OpenScene(ScenePath);
            }
        }

        public static void ApplyPlayerSettings()
        {
            PlayerSettings.productName = "Crypt Crawl";
            if (PlayerSettings.companyName == "DefaultCompany") PlayerSettings.companyName = "Jesse";
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
            PlayerSettings.SetApplicationIdentifier(UnityEditor.Build.NamedBuildTarget.Android, "com.jesse.cryptcrawl");
            PlayerSettings.SetApplicationIdentifier(UnityEditor.Build.NamedBuildTarget.iOS, "com.jesse.cryptcrawl");
            QualitySettings.vSyncCount = 0;
            PlayerSettings.colorSpace = ColorSpace.Linear; // richer, more accurate lighting
        }
    }
}
