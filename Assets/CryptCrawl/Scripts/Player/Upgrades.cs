using System;
using System.Collections.Generic;
using UnityEngine;

namespace CryptCrawl
{
    /// <summary>The hero's numbers. Upgrades change these during a run.</summary>
    [Serializable]
    public class HeroStats
    {
        public float maxHealth = 100f;
        public float moveSpeed = 5.2f;
        public float damage = 12f;
        public float shotsPerSecond = 1.8f;
        public float boltSpeed = 17f;
        public int frontBolts = 1;
        public int diagonalBolts;   // pairs at +/- 40 degrees
        public int rearBolts;
        public int pierce;
        public float critChance = 0.05f;
        public float burnDps;
        public float healOnKill;
    }

    /// <summary>
    /// The upgrade cards offered after each cleared room. To add a new one, copy an
    /// entry in the list below and change the text and what it does.
    /// </summary>
    public class Upgrade
    {
        public string id;
        public string title;
        public string description;
        public Color color;
        public int maxStacks = 99;
        public Action<HeroStats, Hero> apply;

        public static readonly List<Upgrade> All = new List<Upgrade>
        {
            new Upgrade
            {
                id = "damage", title = "Sharpened Bolts", description = "+30% damage",
                color = new Color(0.95f, 0.35f, 0.3f),
                apply = (s, h) => s.damage *= 1.3f,
            },
            new Upgrade
            {
                id = "speed", title = "Quick Draw", description = "+25% attack speed",
                color = new Color(1f, 0.75f, 0.25f),
                apply = (s, h) => s.shotsPerSecond *= 1.25f,
            },
            new Upgrade
            {
                id = "multishot", title = "Twin Bolts", description = "+1 bolt forward",
                color = new Color(0.4f, 0.75f, 1f), maxStacks = 3,
                apply = (s, h) => { s.frontBolts += 1; s.damage *= 0.9f; },
            },
            new Upgrade
            {
                id = "diagonal", title = "Fan of Bolts", description = "+2 bolts at an angle",
                color = new Color(0.35f, 0.6f, 1f), maxStacks = 2,
                apply = (s, h) => s.diagonalBolts += 1,
            },
            new Upgrade
            {
                id = "rear", title = "Eyes in the Back", description = "+1 bolt backward",
                color = new Color(0.55f, 0.55f, 0.95f), maxStacks = 1,
                apply = (s, h) => s.rearBolts += 1,
            },
            new Upgrade
            {
                id = "pierce", title = "Piercing Shot", description = "Bolts pass through 1 more enemy",
                color = new Color(0.75f, 0.9f, 1f), maxStacks = 2,
                apply = (s, h) => s.pierce += 1,
            },
            new Upgrade
            {
                id = "crit", title = "Keen Eye", description = "+15% critical hit chance",
                color = new Color(1f, 0.9f, 0.3f), maxStacks = 3,
                apply = (s, h) => s.critChance += 0.15f,
            },
            new Upgrade
            {
                id = "fire", title = "Fire Bolts", description = "Hits set enemies on fire",
                color = new Color(1f, 0.5f, 0.15f), maxStacks = 2,
                apply = (s, h) => s.burnDps += 8f,
            },
            new Upgrade
            {
                id = "vitality", title = "Vitality", description = "+30 max health and heal 30",
                color = new Color(0.4f, 0.95f, 0.5f),
                apply = (s, h) => { s.maxHealth += 30f; h.RefreshMaxHealth(30f); },
            },
            new Upgrade
            {
                id = "harvest", title = "Bone Harvest", description = "Heal 4 health per kill",
                color = new Color(0.6f, 1f, 0.6f), maxStacks = 3,
                apply = (s, h) => s.healOnKill += 4f,
            },
            new Upgrade
            {
                id = "boots", title = "Swift Boots", description = "+12% move speed",
                color = new Color(0.6f, 0.9f, 0.8f), maxStacks = 3,
                apply = (s, h) => s.moveSpeed *= 1.12f,
            },
        };

        /// <summary>Pick up to three different upgrades the hero can still take.</summary>
        public static List<Upgrade> RollChoices(Dictionary<string, int> taken, int count = 3)
        {
            var pool = new List<Upgrade>();
            foreach (var u in All)
            {
                taken.TryGetValue(u.id, out int n);
                if (n < u.maxStacks) pool.Add(u);
            }
            var result = new List<Upgrade>();
            while (result.Count < count && pool.Count > 0)
            {
                int i = UnityEngine.Random.Range(0, pool.Count);
                result.Add(pool[i]);
                pool.RemoveAt(i);
            }
            return result;
        }
    }
}
