using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace CryptCrawl
{
    /// <summary>Numbers that pop out of whatever got hit and float away.</summary>
    public static class DamageNumbers
    {
        class Number
        {
            public RectTransform rt;
            public Text text;
            public Vector3 world;
            public float age;
            public float scale;
            public Vector3 drift;
        }

        static readonly List<Number> Active = new List<Number>();
        static readonly Stack<Number> Pool = new Stack<Number>();
        static RectTransform _layer;
        const float Life = 0.75f;

        public static void Init(RectTransform layer)
        {
            _layer = layer;
            Active.Clear();
            Pool.Clear();
        }

        public static void Show(Vector3 world, float amount, Color color, bool big, string prefix = "")
        {
            if (_layer == null) return;
            var n = Pool.Count > 0 ? Pool.Pop() : Create();
            n.rt.gameObject.SetActive(true);
            n.text.text = prefix + Mathf.Max(1, Mathf.RoundToInt(amount));
            n.text.color = color;
            n.world = world;
            n.age = 0f;
            n.scale = big ? 1.5f : 1f;
            n.drift = new Vector3(Random.Range(-0.6f, 0.6f), 1.6f, 0f);
            Active.Add(n);
        }

        static Number Create()
        {
            var rt = Ui.Box("Damage", _layer, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(200, 80));
            rt.pivot = new Vector2(0.5f, 0.5f);
            var t = Ui.Label(rt, "", 46, TextAnchor.MiddleCenter, Color.white, true);
            return new Number { rt = rt, text = t };
        }

        /// <summary>Called by the HUD every frame.</summary>
        public static void Tick(Camera cam)
        {
            if (cam == null || _layer == null) return;
            for (int i = Active.Count - 1; i >= 0; i--)
            {
                var n = Active[i];
                n.age += Time.unscaledDeltaTime;
                if (n.age >= Life || n.rt == null)
                {
                    if (n.rt != null) { n.rt.gameObject.SetActive(false); Pool.Push(n); }
                    Active.RemoveAt(i);
                    continue;
                }
                float k = n.age / Life;
                var screen = cam.WorldToScreenPoint(n.world + n.drift * k);
                if (screen.z < 0f) { n.rt.gameObject.SetActive(false); continue; }
                n.rt.gameObject.SetActive(true);
                RectTransformUtility.ScreenPointToLocalPointInRectangle(_layer, screen, null, out var local);
                n.rt.anchoredPosition = local;
                float pop = k < 0.15f ? Mathf.Lerp(1.6f, 1f, k / 0.15f) : 1f;
                n.rt.localScale = Vector3.one * n.scale * pop;
                var c = n.text.color;
                c.a = 1f - Mathf.Clamp01((k - 0.6f) / 0.4f);
                n.text.color = c;
            }
        }
    }
}
