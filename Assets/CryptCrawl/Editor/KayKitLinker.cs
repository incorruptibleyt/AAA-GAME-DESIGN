using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

namespace CryptCrawl.EditorTools
{
    /// <summary>
    /// One click to hook up the KayKit art. Drop the KayKit packs anywhere inside Assets,
    /// then choose Crypt Crawl > Link KayKit Assets. This tool:
    ///   1. finds each model the game wants by file name,
    ///   2. sets the character rigs up so they share one set of animations,
    ///   3. builds an Animator Controller from the KayKit animation clips,
    ///   4. writes everything into the ArtLibrary asset the game reads.
    /// Anything it can't find keeps using the placeholder shapes.
    /// </summary>
    public static class KayKitLinker
    {
        const string LibraryPath = ProjectSetup.ResourcesDir + "/ArtLibrary.asset";
        const string ControllerPath = ProjectSetup.ResourcesDir + "/CharacterAnimator.controller";

        static readonly string[] CharacterKeys =
        {
            ArtKeys.Knight, ArtKeys.Barbarian, ArtKeys.Mage, ArtKeys.Rogue, ArtKeys.Ranger,
            ArtKeys.SkeletonMinion, ArtKeys.SkeletonWarrior, ArtKeys.SkeletonRogue, ArtKeys.SkeletonMage, ArtKeys.SkeletonGolem,
        };

        /// <summary>Animator state name, then clip-name fragments to look for, best first.</summary>
        static readonly (string state, string[] names, bool loop)[] States =
        {
            ("Idle", new[] { "Idle_A", "Idle", "Unarmed_Idle" }, true),
            ("Run", new[] { "Running_A", "Running_B", "Run", "Walking_A", "Walk" }, true),
            ("Attack", new[] { "1H_Ranged_Shoot", "2H_Ranged_Shoot", "Ranged_Shoot", "Throw", "1H_Melee_Attack_Chop", "Melee_1H_Attack_Chop", "Attack" }, false),
            ("Cast", new[] { "Spellcast_Shoot", "Spellcasting", "Spellcast", "Cast" }, false),
            ("Hit", new[] { "Hit_A", "Hit_B", "Hit" }, false),
            ("Death", new[] { "Death_A", "Death_B", "Death", "Die" }, false),
        };

        [MenuItem("Crypt Crawl/Link KayKit Assets", priority = 20)]
        public static void Link()
        {
            ProjectSetup.EnsureMaterials();
            var report = new StringBuilder();

            var models = AssetDatabase.FindAssets("t:Model")
                .Select(AssetDatabase.GUIDToAssetPath)
                .Where(p => p.StartsWith("Assets/") && !p.StartsWith(ProjectSetup.Root + "/"))
                .ToList();

            if (models.Count == 0)
            {
                EditorUtility.DisplayDialog("Crypt Crawl",
                    "No 3D models found in your Assets folder yet.\n\nDownload the KayKit packs, unzip them, and drag their FBX folders into the Project window first. The setup guide (SETUP.md) walks through it.",
                    "OK");
                return;
            }

            // ---- 1. Find the models.
            var found = new Dictionary<string, string>();
            foreach (var kv in ArtKeys.SearchNames)
            {
                var path = FindModel(models, kv.Key, kv.Value);
                if (path != null) found[kv.Key] = path;
            }

            // Animation files: models whose names suggest they hold the shared clips (Rig_Medium_*, *Animations*).
            var animationFiles = models.Where(p =>
            {
                var n = Path.GetFileNameWithoutExtension(p);
                return n.StartsWith("Rig_", StringComparison.OrdinalIgnoreCase) || p.IndexOf("animation", StringComparison.OrdinalIgnoreCase) >= 0;
            }).Where(p => !found.ContainsValue(p)).ToList();

            // ---- 2. Rig setup: Humanoid lets one set of clips drive every character. Fall back to Generic if it fails.
            var rigged = CharacterKeys.Where(found.ContainsKey).Select(k => found[k]).Concat(animationFiles).Distinct().ToList();
            bool humanoid = SetRigs(rigged, ModelImporterAnimationType.Human);
            if (!humanoid)
            {
                SetRigs(rigged, ModelImporterAnimationType.Generic);
                report.AppendLine("Rigs: Humanoid set-up didn't take, so Generic rigs were used instead.");
            }
            else report.AppendLine("Rigs: Humanoid.");

            // ---- 3. Animator Controller.
            var clipSources = animationFiles.Count > 0 ? animationFiles : rigged;
            var clips = clipSources.SelectMany(LoadClips).ToList();
            SetLooping(clipSources);
            clips = clipSources.SelectMany(LoadClips).ToList(); // reload after reimport
            var controller = BuildController(clips, report);

            // ---- 4. Art library.
            var lib = AssetDatabase.LoadAssetAtPath<ArtLibrary>(LibraryPath);
            if (lib == null)
            {
                lib = ScriptableObject.CreateInstance<ArtLibrary>();
                AssetDatabase.CreateAsset(lib, LibraryPath);
            }
            lib.models.Clear();
            report.AppendLine();
            foreach (var kv in ArtKeys.SearchNames)
            {
                if (found.TryGetValue(kv.Key, out var path))
                {
                    lib.models.Add(new ArtLibrary.Entry { key = kv.Key, prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path) });
                    report.AppendLine($"✓ {kv.Key}  ←  {Path.GetFileName(path)}");
                }
                else report.AppendLine($"·  {kv.Key}  (not found, using placeholder)");
            }
            lib.characterController = controller;
            EditorUtility.SetDirty(lib);
            AssetDatabase.SaveAssets();

            Debug.Log("[Crypt Crawl] KayKit link report:\n" + report);
            EditorUtility.DisplayDialog("Crypt Crawl: KayKit linked", report.ToString(), "OK");
        }

        [MenuItem("Crypt Crawl/Unlink KayKit Assets (use placeholders)", priority = 21)]
        public static void Unlink()
        {
            if (AssetDatabase.LoadAssetAtPath<ArtLibrary>(LibraryPath) != null) AssetDatabase.DeleteAsset(LibraryPath);
            EditorUtility.DisplayDialog("Crypt Crawl", "The game will use placeholder shapes again. Your KayKit files were not touched.", "OK");
        }

        static string FindModel(List<string> models, string key, string[] names)
        {
            bool wantsSkeleton = key.StartsWith("Skeleton", StringComparison.OrdinalIgnoreCase);
            var candidates = models.Where(p =>
            {
                var n = Path.GetFileNameWithoutExtension(p);
                if (n.StartsWith("Rig_", StringComparison.OrdinalIgnoreCase)) return false;
                // "Mage" must not pick up "Skeleton_Mage", and so on.
                bool isSkeleton = n.IndexOf("Skeleton", StringComparison.OrdinalIgnoreCase) >= 0;
                return wantsSkeleton == isSkeleton || !CharacterKeys.Contains(key);
            }).ToList();

            foreach (var name in names)
            {
                var exact = candidates.Where(p => string.Equals(Path.GetFileNameWithoutExtension(p), name, StringComparison.OrdinalIgnoreCase)).OrderBy(PreferFbx).FirstOrDefault();
                if (exact != null) return exact;
            }
            foreach (var name in names)
            {
                var starts = candidates.Where(p => Path.GetFileNameWithoutExtension(p).StartsWith(name, StringComparison.OrdinalIgnoreCase)).OrderBy(PreferFbx).ThenBy(p => p.Length).FirstOrDefault();
                if (starts != null) return starts;
            }
            return null;
        }

        static int PreferFbx(string path) => path.EndsWith(".fbx", StringComparison.OrdinalIgnoreCase) ? 0 : 1;

        static bool SetRigs(List<string> paths, ModelImporterAnimationType type)
        {
            bool allValid = true;
            AssetDatabase.StartAssetEditing();
            try
            {
                foreach (var p in paths)
                {
                    if (!(AssetImporter.GetAtPath(p) is ModelImporter mi)) continue;
                    if (mi.animationType == type && mi.avatarSetup == ModelImporterAvatarSetup.CreateFromThisModel) continue;
                    mi.animationType = type;
                    mi.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
                    mi.SaveAndReimport();
                }
            }
            finally { AssetDatabase.StopAssetEditing(); }

            if (type != ModelImporterAnimationType.Human) return true;
            foreach (var p in paths)
            {
                var avatar = AssetDatabase.LoadAllAssetsAtPath(p).OfType<Avatar>().FirstOrDefault();
                if (avatar == null || !avatar.isValid || !avatar.isHuman)
                {
                    Debug.LogWarning($"[Crypt Crawl] Humanoid avatar failed for {p}");
                    allValid = false;
                }
            }
            return allValid;
        }

        static IEnumerable<AnimationClip> LoadClips(string path) =>
            AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c => !c.name.StartsWith("__preview__"));

        static void SetLooping(List<string> paths)
        {
            foreach (var p in paths)
            {
                if (!(AssetImporter.GetAtPath(p) is ModelImporter mi)) continue;
                var clips = mi.clipAnimations.Length > 0 ? mi.clipAnimations : mi.defaultClipAnimations;
                bool changed = false;
                foreach (var c in clips)
                {
                    bool shouldLoop = States.Any(s => s.loop && s.names.Any(n => c.name.IndexOf(n, StringComparison.OrdinalIgnoreCase) >= 0));
                    if (shouldLoop && !c.loopTime) { c.loopTime = true; changed = true; }
                }
                if (changed)
                {
                    mi.clipAnimations = clips;
                    mi.SaveAndReimport();
                }
            }
        }

        static AnimationClip Pick(List<AnimationClip> clips, string[] names)
        {
            foreach (var n in names)
            {
                var exact = clips.FirstOrDefault(c => string.Equals(c.name, n, StringComparison.OrdinalIgnoreCase) || c.name.EndsWith("|" + n, StringComparison.OrdinalIgnoreCase));
                if (exact != null) return exact;
            }
            foreach (var n in names)
            {
                var part = clips.Where(c => c.name.IndexOf(n, StringComparison.OrdinalIgnoreCase) >= 0).OrderBy(c => c.name.Length).FirstOrDefault();
                if (part != null) return part;
            }
            return null;
        }

        static AnimatorController BuildController(List<AnimationClip> clips, StringBuilder report)
        {
            if (clips.Count == 0)
            {
                report.AppendLine("Animations: none found. Import the KayKit Character Animations pack for moving characters.");
                return null;
            }

            if (AssetDatabase.LoadAssetAtPath<AnimatorController>(ControllerPath) != null) AssetDatabase.DeleteAsset(ControllerPath);
            var controller = AnimatorController.CreateAnimatorControllerAtPath(ControllerPath);
            var sm = controller.layers[0].stateMachine;

            report.Append("Animations:");
            foreach (var (state, names, _) in States)
            {
                var clip = Pick(clips, names);
                // Leave out states with no clip: the game skips missing states instead of snapping to a T-pose.
                if (clip == null && state != "Idle") { report.Append($" {state}✗"); continue; }
                var s = sm.AddState(state);
                s.motion = clip;
                if (state == "Idle") sm.defaultState = s;
                report.Append(clip != null ? $" {state}✓" : $" {state}✗");
            }
            report.AppendLine();
            AssetDatabase.SaveAssets();
            return controller;
        }
    }
}
