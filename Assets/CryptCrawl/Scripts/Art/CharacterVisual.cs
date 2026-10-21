using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// The look of a character. Uses the KayKit model and animations when they are linked,
    /// otherwise builds a stylised placeholder from simple shapes and animates it in code.
    /// Gameplay scripts only call SetMoving / Attack / Hit / Die, so they work either way.
    /// </summary>
    public class CharacterVisual : MonoBehaviour
    {
        public struct Look
        {
            public string artKey;
            public float height;
            public Color body, accent, eyes;
            public bool hat, horns, crown, hood;
        }

        Transform _model;
        Animator _animator;
        bool _usingKayKit;
        bool _moving;
        float _bob;
        float _punch;
        float _baseScale = 1f;
        Renderer[] _renderers;
        Material[][] _originalMaterials;
        Coroutine _flash;
        Material _flashMaterial;
        bool _dead;

        static readonly int IdleState = Animator.StringToHash("Idle");
        static readonly int RunState = Animator.StringToHash("Run");
        static readonly int AttackState = Animator.StringToHash("Attack");
        static readonly int CastState = Animator.StringToHash("Cast");
        static readonly int HitState = Animator.StringToHash("Hit");
        static readonly int DeathState = Animator.StringToHash("Death");
        int _current;

        public void Build(Look look)
        {
            var prefab = ArtLibrary.Get(look.artKey);
            var lib = ArtLibrary.Instance;
            if (prefab != null)
            {
                _usingKayKit = true;
                _model = Instantiate(prefab, transform).transform;
                _model.localPosition = Vector3.zero;
                _model.localRotation = Quaternion.identity;
                FitHeight(_model, look.height);
                _animator = _model.GetComponentInChildren<Animator>();
                if (_animator == null) _animator = _model.gameObject.AddComponent<Animator>();
                _animator.applyRootMotion = false;
                _animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;
                if (lib != null && lib.characterController != null) _animator.runtimeAnimatorController = lib.characterController;
                if (_animator.runtimeAnimatorController == null) _animator = null;
                foreach (var c in _model.GetComponentsInChildren<Collider>()) Destroy(c);
            }
            else
            {
                _model = BuildPlaceholder(look).transform;
            }

            _baseScale = _model.localScale.x;
            _renderers = _model.GetComponentsInChildren<Renderer>();
            _originalMaterials = new Material[_renderers.Length][];
            for (int i = 0; i < _renderers.Length; i++)
            {
                _originalMaterials[i] = _renderers[i].sharedMaterials;
                _renderers[i].shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            }
            _flashMaterial = MaterialLibrary.Unlit(Color.white);
            Play(IdleState);
        }

        static void FitHeight(Transform model, float height)
        {
            var renderers = model.GetComponentsInChildren<Renderer>();
            if (renderers.Length == 0) return;
            var b = renderers[0].bounds;
            foreach (var r in renderers) b.Encapsulate(r.bounds);
            if (b.size.y > 0.01f) model.localScale *= height / b.size.y;
        }

        // ----------------------------------------------------------------- API

        public void SetMoving(bool moving)
        {
            if (_dead) return;
            _moving = moving;
            if (_animator != null && (_current == IdleState || _current == RunState)) Play(moving ? RunState : IdleState);
        }

        public void Attack(bool spell = false)
        {
            if (_dead) return;
            _punch = 1f;
            if (_animator != null) Play(spell ? CastState : AttackState, true);
        }

        public void Hit()
        {
            if (_dead) return;
            if (_flash != null) StopCoroutine(_flash);
            _flash = StartCoroutine(FlashRoutine());
            if (_animator != null && _current != AttackState && _current != CastState) Play(HitState, true);
        }

        public void Die()
        {
            if (_dead) return;
            _dead = true;
            if (_animator != null) Play(DeathState, true);
            StartCoroutine(DeathRoutine());
        }

        public void SetVisible(bool visible)
        {
            foreach (var r in _renderers)
                if (r != null) r.enabled = visible;
        }

        // ----------------------------------------------------------------- internals

        void Play(int state, bool restart = false)
        {
            if (_animator == null) return;
            if (_current == state && !restart) return;
            if (!_animator.HasState(0, state)) return;
            _current = state;
            _animator.CrossFadeInFixedTime(state, 0.1f, 0, 0f);
        }

        void Update()
        {
            if (_model == null) return;

            if (_animator != null && !_dead && (_current == AttackState || _current == CastState || _current == HitState))
            {
                var info = _animator.GetCurrentAnimatorStateInfo(0);
                if (info.shortNameHash == _current && info.normalizedTime >= 0.9f) Play(_moving ? RunState : IdleState);
            }

            if (_usingKayKit || _dead) return;

            // Placeholder animation: bob while walking, squash on attack.
            _bob += Time.deltaTime * (_moving ? 14f : 3f);
            float bobY = _moving ? Mathf.Abs(Mathf.Sin(_bob)) * 0.12f : Mathf.Sin(_bob) * 0.02f;
            float lean = _moving ? 8f : 0f;
            _punch = Mathf.MoveTowards(_punch, 0f, Time.deltaTime * 6f);
            float squash = 1f + _punch * 0.2f;
            _model.localPosition = new Vector3(0f, bobY, _punch * 0.15f);
            _model.localRotation = Quaternion.Euler(lean, 0f, Mathf.Sin(_bob * 0.5f) * (_moving ? 4f : 0f));
            _model.localScale = new Vector3(_baseScale * squash, _baseScale / squash, _baseScale * squash);
        }

        IEnumerator FlashRoutine()
        {
            SetFlash(true);
            yield return new WaitForSeconds(0.07f);
            SetFlash(false);
            _flash = null;
        }

        void SetFlash(bool on)
        {
            for (int i = 0; i < _renderers.Length; i++)
            {
                if (_renderers[i] == null) continue;
                if (on)
                {
                    var mats = new Material[_originalMaterials[i].Length];
                    for (int m = 0; m < mats.Length; m++) mats[m] = _flashMaterial;
                    _renderers[i].sharedMaterials = mats;
                }
                else _renderers[i].sharedMaterials = _originalMaterials[i];
            }
        }

        IEnumerator DeathRoutine()
        {
            if (_flash != null) { StopCoroutine(_flash); SetFlash(false); }
            if (_usingKayKit && _animator != null)
            {
                yield return new WaitForSeconds(1.2f);
            }
            else
            {
                // Placeholder: topple over.
                float t = 0f;
                var start = _model.localRotation;
                while (t < 1f)
                {
                    t += Time.deltaTime * 4f;
                    _model.localRotation = Quaternion.Slerp(start, Quaternion.Euler(-85f, 0f, 0f), t);
                    yield return null;
                }
                yield return new WaitForSeconds(0.4f);
            }
            // Sink into the floor.
            float s = 0f;
            var p = _model.localPosition;
            while (s < 1f)
            {
                s += Time.deltaTime * 1.5f;
                _model.localPosition = p + Vector3.down * s * 1.2f;
                yield return null;
            }
        }

        // ----------------------------------------------------------------- placeholder model

        static GameObject Part(PrimitiveType type, Transform parent, Vector3 pos, Vector3 scale, Material mat)
        {
            var go = GameObject.CreatePrimitive(type);
            Object.Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            return go;
        }

        GameObject BuildPlaceholder(Look look)
        {
            var root = new GameObject("Placeholder");
            root.transform.SetParent(transform, false);
            var t = root.transform;
            var body = MaterialLibrary.Lit(look.body, 0.2f);
            var accent = MaterialLibrary.Lit(look.accent, 0.35f);
            var eyes = MaterialLibrary.Lit(look.eyes, 0.5f, 2.5f);
            float h = look.height;

            Part(PrimitiveType.Capsule, t, new Vector3(0, h * 0.33f, 0), new Vector3(h * 0.38f, h * 0.3f, h * 0.32f), body);   // torso
            Part(PrimitiveType.Cube, t, new Vector3(0, h * 0.26f, 0), new Vector3(h * 0.42f, h * 0.08f, h * 0.36f), accent);   // belt
            var head = Part(PrimitiveType.Sphere, t, new Vector3(0, h * 0.74f, 0), Vector3.one * h * 0.36f, body);
            Part(PrimitiveType.Sphere, t, new Vector3(-h * 0.07f, h * 0.76f, h * 0.15f), Vector3.one * h * 0.07f, eyes);
            Part(PrimitiveType.Sphere, t, new Vector3(h * 0.07f, h * 0.76f, h * 0.15f), Vector3.one * h * 0.07f, eyes);
            Part(PrimitiveType.Capsule, t, new Vector3(-h * 0.25f, h * 0.38f, 0), new Vector3(h * 0.12f, h * 0.16f, h * 0.12f), body); // arms
            Part(PrimitiveType.Capsule, t, new Vector3(h * 0.25f, h * 0.38f, 0), new Vector3(h * 0.12f, h * 0.16f, h * 0.12f), body);
            Part(PrimitiveType.Cube, t, new Vector3(h * 0.3f, h * 0.38f, h * 0.18f), new Vector3(h * 0.05f, h * 0.05f, h * 0.45f), accent); // weapon

            if (look.hat)
            {
                var hat = Part(PrimitiveType.Cylinder, t, new Vector3(0, h * 0.93f, 0), new Vector3(h * 0.42f, h * 0.02f, h * 0.42f), accent);
                Part(PrimitiveType.Cylinder, hat.transform, new Vector3(0, 6f, 0), new Vector3(0.6f, 6f, 0.6f), accent);
            }
            if (look.hood)
                Part(PrimitiveType.Sphere, t, new Vector3(0, h * 0.8f, -h * 0.04f), new Vector3(h * 0.42f, h * 0.36f, h * 0.4f), accent);
            if (look.horns)
            {
                var l = Part(PrimitiveType.Capsule, head.transform, new Vector3(-0.45f, 0.45f, 0), new Vector3(0.18f, 0.35f, 0.18f), accent);
                l.transform.localRotation = Quaternion.Euler(0, 0, 35);
                var r = Part(PrimitiveType.Capsule, head.transform, new Vector3(0.45f, 0.45f, 0), new Vector3(0.18f, 0.35f, 0.18f), accent);
                r.transform.localRotation = Quaternion.Euler(0, 0, -35);
            }
            if (look.crown)
            {
                var gold = MaterialLibrary.Lit(new Color(1f, 0.78f, 0.25f), 0.8f, 0.6f);
                Part(PrimitiveType.Cylinder, t, new Vector3(0, h * 0.92f, 0), new Vector3(h * 0.3f, h * 0.05f, h * 0.3f), gold);
                for (int i = 0; i < 5; i++)
                {
                    float a = i / 5f * Mathf.PI * 2f;
                    Part(PrimitiveType.Cube, t, new Vector3(Mathf.Cos(a) * h * 0.13f, h * 0.98f, Mathf.Sin(a) * h * 0.13f), Vector3.one * h * 0.06f, gold);
                }
            }

            foreach (var r in root.GetComponentsInChildren<Renderer>())
                r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            return root;
        }
    }
}
