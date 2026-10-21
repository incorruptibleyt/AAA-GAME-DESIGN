using UnityEngine;
using UnityEngine.UI;

namespace CryptCrawl
{
    /// <summary>Small helpers for building UI from code (so no prefabs are needed).</summary>
    public static class Ui
    {
        static Font _font;

        public static Font Font
        {
            get
            {
                if (_font != null) return _font;
                // Unity 2022.2+ ships LegacyRuntime.ttf; older versions used Arial.ttf.
                try { _font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); } catch { _font = null; }
                if (_font == null)
                {
                    try { _font = Resources.GetBuiltinResource<Font>("Arial.ttf"); } catch { _font = null; }
                }
                return _font;
            }
        }

        public static RectTransform Rect(string name, Transform parent, Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin = default, Vector2 offsetMax = default)
        {
            var go = new GameObject(name, typeof(RectTransform));
            var rt = (RectTransform)go.transform;
            rt.SetParent(parent, false);
            rt.anchorMin = anchorMin;
            rt.anchorMax = anchorMax;
            rt.offsetMin = offsetMin;
            rt.offsetMax = offsetMax;
            return rt;
        }

        /// <summary>A rectangle anchored at a point with a fixed size.</summary>
        public static RectTransform Box(string name, Transform parent, Vector2 anchor, Vector2 position, Vector2 size)
        {
            var rt = Rect(name, parent, anchor, anchor);
            rt.pivot = anchor;
            rt.anchoredPosition = position;
            rt.sizeDelta = size;
            return rt;
        }

        public static Image Image(RectTransform rt, Color color, Sprite sprite = null)
        {
            var img = rt.gameObject.AddComponent<Image>();
            img.color = color;
            img.sprite = sprite;
            img.raycastTarget = false;
            return img;
        }

        public static Text Label(RectTransform rt, string text, int size, TextAnchor align = TextAnchor.MiddleCenter, Color? color = null, bool bold = false)
        {
            var t = rt.gameObject.AddComponent<Text>();
            t.font = Font;
            t.text = text;
            t.fontSize = size;
            t.alignment = align;
            t.color = color ?? Color.white;
            t.fontStyle = bold ? FontStyle.Bold : FontStyle.Normal;
            t.raycastTarget = false;
            t.horizontalOverflow = HorizontalWrapMode.Wrap;
            t.verticalOverflow = VerticalWrapMode.Overflow;
            var shadow = rt.gameObject.AddComponent<Outline>();
            shadow.effectColor = new Color(0f, 0f, 0f, 0.8f);
            shadow.effectDistance = new Vector2(2f, -2f);
            return t;
        }

        /// <summary>A horizontal bar: dark frame plus a coloured fill you resize with SetFill.</summary>
        public static RectTransform Bar(string name, Transform parent, Vector2 anchor, Vector2 position, Vector2 size, Color fill, out RectTransform fillRect)
        {
            var frame = Box(name, parent, anchor, position, size);
            Image(frame, new Color(0f, 0f, 0f, 0.65f));
            var back = Rect("Back", frame, Vector2.zero, Vector2.one, new Vector2(4, 4), new Vector2(-4, -4));
            Image(back, new Color(0.15f, 0.05f, 0.06f, 0.9f));
            fillRect = Rect("Fill", back, Vector2.zero, Vector2.one);
            Image(fillRect, fill);
            return frame;
        }

        public static void SetFill(RectTransform fill, float amount)
        {
            fill.anchorMax = new Vector2(Mathf.Clamp01(amount), 1f);
        }

        public static bool Contains(RectTransform rt, Vector2 screenPoint) =>
            RectTransformUtility.RectangleContainsScreenPoint(rt, screenPoint, null);
    }
}
