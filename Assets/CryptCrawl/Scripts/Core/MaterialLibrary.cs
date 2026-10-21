using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace CryptCrawl
{
    /// <summary>
    /// Makes coloured materials at runtime. It copies template materials from
    /// Resources/CryptCrawl (the editor creates those for you) so that the shaders are
    /// included when you build for a phone, and works with both the built-in renderer and URP.
    /// </summary>
    public static class MaterialLibrary
    {
        public const string LitPath = "CryptCrawl/Lit";
        public const string LitEmissivePath = "CryptCrawl/LitEmissive";
        public const string UnlitPath = "CryptCrawl/Unlit";

        static Material _lit, _litEmissive, _unlit;
        static readonly Dictionary<string, Material> Cache = new Dictionary<string, Material>();
        static Texture2D _softCircle, _ring, _stone;
        static Sprite _circleSprite, _ringSprite;

        public static bool IsUrp => GraphicsSettings.currentRenderPipeline != null;

        public static Shader FindLitShader()
        {
            Shader s = IsUrp ? Shader.Find("Universal Render Pipeline/Lit") : Shader.Find("Standard");
            return s != null ? s : Shader.Find("Diffuse");
        }

        public static Shader FindUnlitShader()
        {
            // Sprites/Default is unlit, supports transparency and vertex colours, and runs in both pipelines.
            return Shader.Find("Sprites/Default");
        }

        static Material Template(ref Material slot, string path, bool emissive, bool lit)
        {
            if (slot != null) return slot;
            slot = Resources.Load<Material>(path);
            if (slot == null)
            {
                slot = new Material(lit ? FindLitShader() : FindUnlitShader());
                if (emissive) slot.EnableKeyword("_EMISSION");
            }
            return slot;
        }

        /// <summary>A solid, lit material. Pass emission above zero for glowing things like eyes and flames.</summary>
        public static Material Lit(Color color, float smoothness = 0.15f, float emission = 0f, Color? emissionColor = null)
        {
            string key = $"L{ColorUtility.ToHtmlStringRGBA(color)}{smoothness:F2}{emission:F2}{(emissionColor.HasValue ? ColorUtility.ToHtmlStringRGB(emissionColor.Value) : "")}";
            if (Cache.TryGetValue(key, out var m) && m != null) return m;

            bool glow = emission > 0f;
            var template = glow ? Template(ref _litEmissive, LitEmissivePath, true, true) : Template(ref _lit, LitPath, false, true);
            m = new Material(template) { color = color };
            SetSmoothness(m, smoothness);
            if (glow)
            {
                m.EnableKeyword("_EMISSION");
                m.SetColor("_EmissionColor", (emissionColor ?? color) * emission);
            }
            Cache[key] = m;
            return m;
        }

        /// <summary>Unlit and see-through. Used for warning markers, particles and trails.</summary>
        public static Material Unlit(Color color, Texture texture = null)
        {
            string key = $"U{ColorUtility.ToHtmlStringRGBA(color)}{(texture != null ? texture.name : "")}";
            if (Cache.TryGetValue(key, out var m) && m != null) return m;
            m = new Material(Template(ref _unlit, UnlitPath, false, false)) { color = color };
            if (texture != null) m.mainTexture = texture;
            Cache[key] = m;
            return m;
        }

        /// <summary>A textured, lit stone floor material.</summary>
        public static Material Floor(Vector2 tiling)
        {
            var m = new Material(Template(ref _lit, LitPath, false, true)) { color = Color.white };
            m.mainTexture = StoneTexture;
            m.mainTextureScale = tiling;
            SetSmoothness(m, 0.25f);
            return m;
        }

        static void SetSmoothness(Material m, float s)
        {
            if (m.HasProperty("_Glossiness")) m.SetFloat("_Glossiness", s);
            if (m.HasProperty("_Smoothness")) m.SetFloat("_Smoothness", s);
        }

        // ---------- Procedural textures (so the slice looks good with zero art imported) ----------

        public static Texture2D SoftCircle
        {
            get
            {
                if (_softCircle != null) return _softCircle;
                const int n = 64;
                _softCircle = new Texture2D(n, n, TextureFormat.RGBA32, false) { name = "SoftCircle", wrapMode = TextureWrapMode.Clamp };
                for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++)
                {
                    float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(n / 2f, n / 2f)) / (n / 2f);
                    float a = Mathf.Clamp01(1f - d);
                    _softCircle.SetPixel(x, y, new Color(1, 1, 1, a * a));
                }
                _softCircle.Apply();
                return _softCircle;
            }
        }

        /// <summary>A filled disc with a brighter rim: used for the "danger here" circles.</summary>
        public static Texture2D Ring
        {
            get
            {
                if (_ring != null) return _ring;
                const int n = 128;
                _ring = new Texture2D(n, n, TextureFormat.RGBA32, false) { name = "Ring", wrapMode = TextureWrapMode.Clamp };
                for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++)
                {
                    float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(n / 2f, n / 2f)) / (n / 2f);
                    float fill = d < 1f ? 0.35f : 0f;
                    float rim = Mathf.Clamp01(1f - Mathf.Abs(d - 0.93f) / 0.07f);
                    _ring.SetPixel(x, y, new Color(1, 1, 1, Mathf.Max(fill, rim)));
                }
                _ring.Apply();
                return _ring;
            }
        }

        public static Sprite CircleSprite
        {
            get
            {
                if (_circleSprite != null) return _circleSprite;
                const int n = 128;
                var t = new Texture2D(n, n, TextureFormat.RGBA32, false) { name = "UICircle", wrapMode = TextureWrapMode.Clamp };
                for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++)
                {
                    float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(n / 2f, n / 2f));
                    t.SetPixel(x, y, new Color(1, 1, 1, Mathf.Clamp01(n / 2f - d)));
                }
                t.Apply();
                _circleSprite = Sprite.Create(t, new Rect(0, 0, n, n), new Vector2(0.5f, 0.5f), 100f);
                return _circleSprite;
            }
        }

        public static Sprite RingSprite
        {
            get
            {
                if (_ringSprite != null) return _ringSprite;
                const int n = 128;
                var t = new Texture2D(n, n, TextureFormat.RGBA32, false) { name = "UIRing", wrapMode = TextureWrapMode.Clamp };
                for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++)
                {
                    float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(n / 2f, n / 2f));
                    float outer = Mathf.Clamp01(n / 2f - d);
                    float inner = Mathf.Clamp01(d - (n / 2f - 6f));
                    t.SetPixel(x, y, new Color(1, 1, 1, outer * inner));
                }
                t.Apply();
                _ringSprite = Sprite.Create(t, new Rect(0, 0, n, n), new Vector2(0.5f, 0.5f), 100f);
                return _ringSprite;
            }
        }

        /// <summary>Flagstone floor texture: 4x4 slabs with dark grout and a little colour noise.</summary>
        public static Texture2D StoneTexture
        {
            get
            {
                if (_stone != null) return _stone;
                const int n = 256, slabs = 4;
                _stone = new Texture2D(n, n, TextureFormat.RGBA32, true) { name = "Flagstones", wrapMode = TextureWrapMode.Repeat, filterMode = FilterMode.Bilinear };
                var rng = new System.Random(7);
                var slabTint = new float[slabs * slabs];
                for (int i = 0; i < slabTint.Length; i++) slabTint[i] = 0.85f + (float)rng.NextDouble() * 0.3f;
                int s = n / slabs;
                var baseCol = new Color(0.34f, 0.32f, 0.36f);
                for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++)
                {
                    int sx = x / s, sy = y / s;
                    int lx = x % s, ly = y % s;
                    int edge = Mathf.Min(Mathf.Min(lx, s - 1 - lx), Mathf.Min(ly, s - 1 - ly));
                    float grout = edge < 2 ? 0.35f : edge < 4 ? 0.75f : 1f;
                    float noise = Mathf.PerlinNoise(x * 0.08f, y * 0.08f) * 0.25f + 0.85f;
                    var c = baseCol * slabTint[sy * slabs + sx] * noise * grout;
                    c.a = 1f;
                    _stone.SetPixel(x, y, c);
                }
                _stone.Apply(true);
                return _stone;
            }
        }
    }
}
