using System;
using System.Collections.Generic;
using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// The list of 3D models and animations the game should use. You don't fill this in
    /// by hand: import the KayKit packs, then click "Crypt Crawl > Link KayKit Assets" in
    /// Unity's menu bar and it is created at Assets/CryptCrawl/Resources/CryptCrawl/ArtLibrary.asset.
    /// Anything left empty falls back to the built-in placeholder shapes.
    /// </summary>
    [CreateAssetMenu(menuName = "Crypt Crawl/Art Library", fileName = "ArtLibrary")]
    public class ArtLibrary : ScriptableObject
    {
        public const string ResourcePath = "CryptCrawl/ArtLibrary";

        [Serializable]
        public class Entry
        {
            public string key;
            public GameObject prefab;
        }

        [Tooltip("Characters and props, looked up by key (for example \"Knight\" or \"Skeleton_Minion\").")]
        public List<Entry> models = new List<Entry>();

        [Tooltip("Animator Controller with Idle, Run, Attack, Cast, Hit and Death states, built by the Link KayKit Assets menu.")]
        public RuntimeAnimatorController characterController;

        [Tooltip("Tick this if the KayKit walls show their back side to the room.")]
        public bool flipWalls;

        static ArtLibrary _loaded;
        static bool _tried;

        public static ArtLibrary Instance
        {
            get
            {
                if (!_tried)
                {
                    _tried = true;
                    _loaded = Resources.Load<ArtLibrary>(ResourcePath);
                }
                return _loaded;
            }
        }

        public static GameObject Get(string key)
        {
            var lib = Instance;
            if (lib == null) return null;
            foreach (var e in lib.models)
                if (e != null && e.prefab != null && string.Equals(e.key, key, StringComparison.OrdinalIgnoreCase))
                    return e.prefab;
            return null;
        }
    }

    /// <summary>The keys the game asks the ArtLibrary for.</summary>
    public static class ArtKeys
    {
        public const string Knight = "Knight";
        public const string Barbarian = "Barbarian";
        public const string Mage = "Mage";
        public const string Rogue = "Rogue";
        public const string Ranger = "Ranger";

        public const string SkeletonMinion = "Skeleton_Minion";
        public const string SkeletonWarrior = "Skeleton_Warrior";
        public const string SkeletonRogue = "Skeleton_Rogue";
        public const string SkeletonMage = "Skeleton_Mage";
        public const string SkeletonGolem = "Skeleton_Golem";

        public const string Floor = "floor_tile_large";
        public const string Wall = "wall";
        public const string Pillar = "pillar";
        public const string Barrel = "barrel_large";
        public const string Crates = "crates_stacked";
        public const string Torch = "torch_mounted";
        public const string Chest = "chest";
        public const string Banner = "banner";

        /// <summary>
        /// For each key, file-name fragments to search for (best first). KayKit renamed some
        /// files between versions, so the linker tries each in turn.
        /// </summary>
        public static readonly Dictionary<string, string[]> SearchNames = new Dictionary<string, string[]>
        {
            { Knight, new[] { "Knight" } },
            { Barbarian, new[] { "Barbarian" } },
            { Mage, new[] { "Mage" } },
            { Rogue, new[] { "Rogue_Hooded", "Rogue" } },
            { Ranger, new[] { "Ranger" } },
            { SkeletonMinion, new[] { "Skeleton_Minion" } },
            { SkeletonWarrior, new[] { "Skeleton_Warrior" } },
            { SkeletonRogue, new[] { "Skeleton_Rogue" } },
            { SkeletonMage, new[] { "Skeleton_Mage" } },
            { SkeletonGolem, new[] { "Skeleton_Golem", "Golem" } },
            { Floor, new[] { "floor_tile_large", "floor_tile_big", "floor_tile" } },
            { Wall, new[] { "wall" } },
            { Pillar, new[] { "pillar" } },
            { Barrel, new[] { "barrel_large", "barrel" } },
            { Crates, new[] { "crates_stacked", "box_stacked", "crate" } },
            { Torch, new[] { "torch_mounted", "torch_lit", "torch" } },
            { Chest, new[] { "chest" } },
            { Banner, new[] { "banner" } },
        };
    }
}
