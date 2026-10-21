using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace CryptCrawl
{
    /// <summary>
    /// Everything on screen that isn't the 3D world: the floating thumb joystick, health,
    /// room counter, boss bar, upgrade cards, title and end screens, and fades.
    /// Built in code and laid out for a portrait phone (1080 x 1920 reference).
    /// </summary>
    public class Hud : MonoBehaviour
    {
        Canvas _canvas;
        RectTransform _root;

        // Joystick
        RectTransform _stickBase, _stickKnob;
        Vector2 _stickOrigin;
        bool _stickActive;
        const float StickRadius = 150f;
        public Vector2 JoystickVector { get; private set; }

        // HUD
        RectTransform _hudGroup, _hpFill, _bossGroup, _bossFill;
        Text _hpText, _roomText, _bossName, _banner;
        float _bannerTimer;
        float _shownHp = 1f;

        // Overlays
        RectTransform _upgradeGroup, _titleGroup, _endGroup, _pauseGroup;
        Text _endTitle, _endStats, _titleBest;
        readonly List<RectTransform> _cards = new List<RectTransform>();
        Action<int> _onCardPicked;
        bool _cardsArmed;
        Image _fade;

        public static Hud Create()
        {
            var go = new GameObject("HUD");
            var hud = go.AddComponent<Hud>();
            hud.Build();
            return hud;
        }

        void Build()
        {
            _canvas = gameObject.AddComponent<Canvas>();
            _canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            _canvas.sortingOrder = 10;
            var scaler = gameObject.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1080, 1920);
            scaler.matchWidthOrHeight = 0.5f;
            _root = (RectTransform)transform;

            var safe = Ui.Rect("Safe Area", _root, Vector2.zero, Vector2.one);
            safe.gameObject.AddComponent<SafeArea>();

            var damageLayer = Ui.Rect("Damage Numbers", _root, Vector2.zero, Vector2.one);
            DamageNumbers.Init(damageLayer);

            BuildHud(safe);
            BuildJoystick();
            BuildUpgrades();
            BuildTitle();
            BuildEnd();
            BuildPause();

            var fade = Ui.Rect("Fade", _root, Vector2.zero, Vector2.one);
            _fade = Ui.Image(fade, new Color(0, 0, 0, 0));
        }

        void BuildHud(RectTransform safe)
        {
            _hudGroup = Ui.Rect("HUD", safe, Vector2.zero, Vector2.one);

            Ui.Bar("Health", _hudGroup, new Vector2(0, 1), new Vector2(40, -40), new Vector2(460, 56), new Color(0.85f, 0.18f, 0.22f), out _hpFill);
            var hpText = Ui.Box("Health Text", _hudGroup, new Vector2(0, 1), new Vector2(40, -40), new Vector2(460, 56));
            _hpText = Ui.Label(hpText, "100 / 100", 34, TextAnchor.MiddleCenter, Color.white, true);

            var room = Ui.Box("Room", _hudGroup, new Vector2(1, 1), new Vector2(-40, -36), new Vector2(360, 64));
            _roomText = Ui.Label(room, "Room 1", 40, TextAnchor.MiddleRight, new Color(0.9f, 0.85f, 0.75f), true);

            _bossGroup = Ui.Rect("Boss", _hudGroup, new Vector2(0, 1), new Vector2(1, 1), new Vector2(60, -230), new Vector2(-60, -130));
            var bossName = Ui.Rect("Name", _bossGroup, new Vector2(0, 0.55f), Vector2.one);
            _bossName = Ui.Label(bossName, SkeletonKing.DisplayName, 38, TextAnchor.MiddleCenter, new Color(1f, 0.8f, 0.6f), true);
            var bar = Ui.Rect("Bar", _bossGroup, Vector2.zero, new Vector2(1, 0.5f));
            Ui.Image(bar, new Color(0, 0, 0, 0.7f));
            var back = Ui.Rect("Back", bar, Vector2.zero, Vector2.one, new Vector2(5, 5), new Vector2(-5, -5));
            Ui.Image(back, new Color(0.15f, 0.05f, 0.05f));
            _bossFill = Ui.Rect("Fill", back, Vector2.zero, Vector2.one);
            Ui.Image(_bossFill, new Color(0.75f, 0.1f, 0.12f));
            _bossGroup.gameObject.SetActive(false);

            var banner = Ui.Rect("Banner", _root, new Vector2(0, 0.55f), new Vector2(1, 0.7f));
            _banner = Ui.Label(banner, "", 96, TextAnchor.MiddleCenter, new Color(1f, 0.9f, 0.7f), true);
        }

        void BuildJoystick()
        {
            _stickBase = Ui.Box("Joystick", _root, new Vector2(0, 0), Vector2.zero, new Vector2(StickRadius * 2.2f, StickRadius * 2.2f));
            _stickBase.pivot = new Vector2(0.5f, 0.5f);
            Ui.Image(_stickBase, new Color(1, 1, 1, 0.12f), MaterialLibrary.CircleSprite);
            var ring = Ui.Rect("Ring", _stickBase, Vector2.zero, Vector2.one);
            Ui.Image(ring, new Color(1, 1, 1, 0.45f), MaterialLibrary.RingSprite);
            _stickKnob = Ui.Box("Knob", _stickBase, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(130, 130));
            _stickKnob.pivot = new Vector2(0.5f, 0.5f);
            Ui.Image(_stickKnob, new Color(1, 1, 1, 0.75f), MaterialLibrary.CircleSprite);
            _stickBase.gameObject.SetActive(false);
        }

        void BuildUpgrades()
        {
            _upgradeGroup = Ui.Rect("Upgrades", _root, Vector2.zero, Vector2.one);
            Ui.Image(_upgradeGroup, new Color(0.02f, 0.01f, 0.04f, 0.82f));
            var title = Ui.Rect("Title", _upgradeGroup, new Vector2(0, 0.78f), new Vector2(1, 0.9f));
            Ui.Label(title, "Choose a Blessing", 78, TextAnchor.MiddleCenter, new Color(1f, 0.85f, 0.55f), true);
            for (int i = 0; i < 3; i++)
            {
                float top = 0.72f - i * 0.2f;
                var card = Ui.Rect("Card " + i, _upgradeGroup, new Vector2(0.08f, top - 0.17f), new Vector2(0.92f, top));
                Ui.Image(card, new Color(0.12f, 0.1f, 0.16f, 0.98f));
                var stripe = Ui.Rect("Stripe", card, Vector2.zero, new Vector2(0.035f, 1f));
                Ui.Image(stripe, Color.white);
                var name = Ui.Rect("Name", card, new Vector2(0.08f, 0.5f), new Vector2(0.97f, 0.92f));
                Ui.Label(name, "", 52, TextAnchor.MiddleLeft, Color.white, true);
                var desc = Ui.Rect("Description", card, new Vector2(0.08f, 0.1f), new Vector2(0.97f, 0.5f));
                Ui.Label(desc, "", 38, TextAnchor.UpperLeft, new Color(0.8f, 0.8f, 0.85f));
                _cards.Add(card);
            }
            _upgradeGroup.gameObject.SetActive(false);
        }

        void BuildTitle()
        {
            _titleGroup = Ui.Rect("Title Screen", _root, Vector2.zero, Vector2.one);
            Ui.Image(_titleGroup, new Color(0.01f, 0.01f, 0.03f, 0.55f));
            var name = Ui.Rect("Name", _titleGroup, new Vector2(0, 0.6f), new Vector2(1, 0.78f));
            Ui.Label(name, "CRYPT CRAWL", 140, TextAnchor.MiddleCenter, new Color(1f, 0.85f, 0.55f), true);
            var sub = Ui.Rect("Subtitle", _titleGroup, new Vector2(0.1f, 0.52f), new Vector2(0.9f, 0.6f));
            Ui.Label(sub, "Drag to move. Stand still to shoot.", 44, TextAnchor.MiddleCenter, new Color(0.85f, 0.85f, 0.9f));
            var best = Ui.Rect("Best", _titleGroup, new Vector2(0, 0.44f), new Vector2(1, 0.5f));
            _titleBest = Ui.Label(best, "", 38, TextAnchor.MiddleCenter, new Color(0.7f, 0.7f, 0.8f));
            var tap = Ui.Rect("Tap", _titleGroup, new Vector2(0, 0.2f), new Vector2(1, 0.28f));
            Ui.Label(tap, "Tap to begin", 64, TextAnchor.MiddleCenter, Color.white, true).gameObject.AddComponent<Pulse>();
            _titleGroup.gameObject.SetActive(false);
        }

        void BuildEnd()
        {
            _endGroup = Ui.Rect("End Screen", _root, Vector2.zero, Vector2.one);
            Ui.Image(_endGroup, new Color(0.02f, 0.0f, 0.02f, 0.75f));
            var t = Ui.Rect("Title", _endGroup, new Vector2(0, 0.6f), new Vector2(1, 0.75f));
            _endTitle = Ui.Label(t, "", 120, TextAnchor.MiddleCenter, Color.white, true);
            var s = Ui.Rect("Stats", _endGroup, new Vector2(0.1f, 0.38f), new Vector2(0.9f, 0.58f));
            _endStats = Ui.Label(s, "", 46, TextAnchor.MiddleCenter, new Color(0.85f, 0.85f, 0.9f));
            var tap = Ui.Rect("Tap", _endGroup, new Vector2(0, 0.2f), new Vector2(1, 0.28f));
            Ui.Label(tap, "Tap to try again", 60, TextAnchor.MiddleCenter, Color.white, true).gameObject.AddComponent<Pulse>();
            _endGroup.gameObject.SetActive(false);
        }

        void BuildPause()
        {
            _pauseGroup = Ui.Rect("Paused", _root, Vector2.zero, Vector2.one);
            Ui.Image(_pauseGroup, new Color(0, 0, 0, 0.6f));
            var t = Ui.Rect("Text", _pauseGroup, new Vector2(0, 0.4f), new Vector2(1, 0.6f));
            Ui.Label(t, "Paused\n<size=50>Tap to continue</size>", 100, TextAnchor.MiddleCenter, Color.white, true);
            _pauseGroup.gameObject.SetActive(false);
        }

        // ------------------------------------------------------------------ per frame

        void Update()
        {
            var gm = GameManager.Instance;
            UpdateJoystick(gm != null && gm.State == GameState.Playing);

            if (gm != null && gm.Hero != null)
            {
                float k = gm.Hero.Health / gm.Hero.maxHealth;
                _shownHp = Mathf.MoveTowards(_shownHp, k, Time.unscaledDeltaTime * 1.5f);
                Ui.SetFill(_hpFill, _shownHp);
                _hpText.text = $"{Mathf.CeilToInt(gm.Hero.Health)} / {Mathf.RoundToInt(gm.Hero.maxHealth)}";
            }
            if (gm != null && gm.Boss != null && !gm.Boss.IsDead)
                Ui.SetFill(_bossFill, gm.Boss.Health / gm.Boss.maxHealth);

            if (_bannerTimer > 0f)
            {
                _bannerTimer -= Time.unscaledDeltaTime;
                var c = _banner.color;
                c.a = Mathf.Clamp01(_bannerTimer / 0.4f);
                _banner.color = c;
                _banner.rectTransform.localScale = Vector3.one * (1f + Mathf.Max(0f, _bannerTimer - 1.6f));
            }

            // A card is picked by pressing and releasing on it. Ignoring a finger that was already down when
            // the cards appeared stops the thumb you were moving with from choosing one by accident.
            if (_upgradeGroup.gameObject.activeSelf && GameInput.PointerDown) _cardsArmed = true;
            for (int i = 0; i < _cards.Count; i++)
            {
                bool pressed = _cardsArmed && GameInput.PointerHeld && Ui.Contains(_cards[i], GameInput.PointerPosition);
                _cards[i].localScale = Vector3.one * (pressed ? 0.96f : 1f);
            }
            if (_upgradeGroup.gameObject.activeSelf && _cardsArmed && GameInput.PointerUp)
            {
                for (int i = 0; i < _cards.Count; i++)
                    if (_cards[i].gameObject.activeSelf && Ui.Contains(_cards[i], GameInput.PointerPosition))
                    {
                        var cb = _onCardPicked;
                        _onCardPicked = null;
                        _upgradeGroup.gameObject.SetActive(false);
                        cb?.Invoke(i);
                        break;
                    }
            }

            DamageNumbers.Tick(gm != null && gm.CameraRig != null ? gm.CameraRig.Cam : Camera.main);
        }

        void UpdateJoystick(bool enabled)
        {
            float scale = _canvas.scaleFactor;
            if (!enabled)
            {
                _stickActive = false;
                JoystickVector = Vector2.zero;
                _stickBase.gameObject.SetActive(false);
                return;
            }

            if (GameInput.PointerDown)
            {
                _stickActive = true;
                _stickOrigin = GameInput.PointerPosition;
                _stickBase.gameObject.SetActive(true);
                _stickBase.anchoredPosition = _stickOrigin / scale;
            }
            if (_stickActive && GameInput.PointerHeld)
            {
                var delta = (GameInput.PointerPosition - _stickOrigin) / scale;
                // If the thumb drags past the edge, the stick follows it (feels nicer than a hard stop).
                if (delta.magnitude > StickRadius)
                {
                    var excess = delta - delta.normalized * StickRadius;
                    _stickOrigin += excess * scale;
                    _stickBase.anchoredPosition = _stickOrigin / scale;
                    delta = delta.normalized * StickRadius;
                }
                _stickKnob.anchoredPosition = delta;
                var v = delta / StickRadius;
                JoystickVector = v.magnitude < 0.15f ? Vector2.zero : v;
            }
            else
            {
                _stickActive = false;
                JoystickVector = Vector2.zero;
                _stickBase.gameObject.SetActive(false);
            }
        }

        // ------------------------------------------------------------------ API used by GameManager

        public void SetRoom(int index, int total, bool boss)
        {
            _roomText.text = boss ? "Boss" : $"Room {index} / {total}";
            _bossGroup.gameObject.SetActive(boss);
            if (boss) _bossName.text = SkeletonKing.DisplayName;
        }

        public void HideBoss() => _bossGroup.gameObject.SetActive(false);

        public void ShowBanner(string text, Color? color = null)
        {
            _banner.text = text;
            _banner.color = color ?? new Color(1f, 0.9f, 0.7f);
            _bannerTimer = 2f;
        }

        public void ShowHud(bool show) => _hudGroup.gameObject.SetActive(show);

        public void ShowUpgrades(List<Upgrade> choices, Action<int> onPicked)
        {
            _onCardPicked = onPicked;
            _cardsArmed = false;
            for (int i = 0; i < _cards.Count; i++)
            {
                bool has = i < choices.Count;
                _cards[i].gameObject.SetActive(has);
                if (!has) continue;
                var texts = _cards[i].GetComponentsInChildren<Text>();
                texts[0].text = choices[i].title;
                texts[0].color = choices[i].color;
                texts[1].text = choices[i].description;
                _cards[i].Find("Stripe").GetComponent<Image>().color = choices[i].color;
            }
            _upgradeGroup.gameObject.SetActive(true);
        }

        public void ShowTitle(bool show, string best = "")
        {
            _titleGroup.gameObject.SetActive(show);
            _titleBest.text = best;
        }

        public void ShowEnd(bool show, bool victory = false, string stats = "")
        {
            _endGroup.gameObject.SetActive(show);
            if (!show) return;
            _endTitle.text = victory ? "VICTORY" : "YOU DIED";
            _endTitle.color = victory ? new Color(1f, 0.85f, 0.4f) : new Color(0.9f, 0.2f, 0.2f);
            _endStats.text = stats;
        }

        public void ShowPause(bool show) => _pauseGroup.gameObject.SetActive(show);

        public bool AnyOverlayOpen => _upgradeGroup.gameObject.activeSelf || _titleGroup.gameObject.activeSelf || _endGroup.gameObject.activeSelf || _pauseGroup.gameObject.activeSelf;

        public void SetFade(float alpha) => _fade.color = new Color(0, 0, 0, alpha);
    }

    /// <summary>Gently pulses a label's transparency ("Tap to begin").</summary>
    public class Pulse : MonoBehaviour
    {
        Text _text;
        void Awake() => _text = GetComponent<Text>();
        void Update()
        {
            var c = _text.color;
            c.a = 0.55f + 0.45f * Mathf.Sin(Time.unscaledTime * 3f);
            _text.color = c;
        }
    }

    /// <summary>Keeps the HUD clear of phone notches and rounded corners.</summary>
    public class SafeArea : MonoBehaviour
    {
        Rect _last;
        void Update()
        {
            var safe = Screen.safeArea;
            if (safe == _last || Screen.width == 0 || Screen.height == 0) return;
            _last = safe;
            var rt = (RectTransform)transform;
            rt.anchorMin = new Vector2(safe.xMin / Screen.width, safe.yMin / Screen.height);
            rt.anchorMax = new Vector2(safe.xMax / Screen.width, safe.yMax / Screen.height);
            rt.offsetMin = rt.offsetMax = Vector2.zero;
        }
    }
}
