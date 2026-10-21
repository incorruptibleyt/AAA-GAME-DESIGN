using System;
using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// A red marker on the floor that warns where an attack is about to land, then fires
    /// a callback. Fair warnings like this are what make dodging feel skilful, not random.
    /// </summary>
    public class Telegraph : MonoBehaviour
    {
        float _duration, _elapsed;
        Action _onDone;
        Transform _fill;
        Material _mat;
        bool _isLine;
        Vector3 _fullScale;

        static GameObject Quad(Transform parent, Texture tex, Color color, out Material mat)
        {
            var q = GameObject.CreatePrimitive(PrimitiveType.Quad);
            Destroy(q.GetComponent<Collider>());
            q.transform.SetParent(parent, false);
            q.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
            mat = new Material(MaterialLibrary.Unlit(color, tex));
            var r = q.GetComponent<Renderer>();
            r.sharedMaterial = mat;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            r.receiveShadows = false;
            return q;
        }

        /// <summary>A circle of the given radius at a point.</summary>
        public static Telegraph Circle(Vector3 position, float radius, float seconds, Action onDone)
        {
            var go = new GameObject("Telegraph Circle");
            if (Room.Current != null) go.transform.SetParent(Room.Current.transform, false);
            go.transform.position = new Vector3(position.x, 0.03f, position.z);
            var t = go.AddComponent<Telegraph>();
            var outline = Quad(go.transform, MaterialLibrary.Ring, new Color(1f, 0.15f, 0.1f, 0.5f), out _);
            outline.transform.localScale = Vector3.one * radius * 2f;
            var fill = Quad(go.transform, MaterialLibrary.SoftCircle, new Color(1f, 0.2f, 0.1f, 0.8f), out t._mat);
            fill.transform.localPosition = Vector3.up * 0.01f;
            t._fill = fill.transform;
            t._fullScale = Vector3.one * radius * 2f;
            t._fill.localScale = Vector3.zero;
            t._duration = seconds;
            t._onDone = onDone;
            Sfx.Play(Sound.Warn, 0.6f);
            return t;
        }

        /// <summary>A strip from an origin in a direction (for charges and aimed shots).</summary>
        public static Telegraph Line(Vector3 origin, Vector3 direction, float length, float width, float seconds, Action onDone)
        {
            direction.y = 0f;
            var go = new GameObject("Telegraph Line");
            if (Room.Current != null) go.transform.SetParent(Room.Current.transform, false);
            go.transform.position = new Vector3(origin.x, 0.03f, origin.z);
            go.transform.rotation = Quaternion.LookRotation(direction.normalized);
            var t = go.AddComponent<Telegraph>();
            t._isLine = true;
            var bg = Quad(go.transform, null, new Color(1f, 0.15f, 0.1f, 0.25f), out _);
            bg.transform.localPosition = new Vector3(0, 0, length * 0.5f);
            bg.transform.localScale = new Vector3(width, length, 1f);
            var fill = Quad(go.transform, null, new Color(1f, 0.25f, 0.1f, 0.6f), out t._mat);
            fill.transform.localPosition = new Vector3(0, 0.01f, 0);
            t._fill = fill.transform;
            t._fullScale = new Vector3(width, length, 1f);
            t._fill.localScale = new Vector3(width, 0f, 1f);
            t._duration = seconds;
            t._onDone = onDone;
            Sfx.Play(Sound.Warn, 0.6f);
            return t;
        }

        void Update()
        {
            _elapsed += Time.deltaTime;
            float k = Mathf.Clamp01(_elapsed / _duration);
            if (_isLine)
            {
                _fill.localScale = new Vector3(_fullScale.x, _fullScale.y * k, 1f);
                _fill.localPosition = new Vector3(0, 0.01f, _fullScale.y * k * 0.5f);
            }
            else _fill.localScale = _fullScale * k;

            // Pulse faster as the hit approaches.
            float pulse = 0.6f + 0.4f * Mathf.Sin(_elapsed * Mathf.Lerp(8f, 30f, k));
            var c = _mat.color;
            c.a = 0.45f + 0.4f * pulse * k;
            _mat.color = c;

            if (_elapsed >= _duration)
            {
                var cb = _onDone;
                _onDone = null;
                Destroy(gameObject);
                cb?.Invoke();
            }
        }

        /// <summary>Cancel without firing (for example when the caster dies).</summary>
        public void Cancel()
        {
            _onDone = null;
            Destroy(gameObject);
        }
    }
}
