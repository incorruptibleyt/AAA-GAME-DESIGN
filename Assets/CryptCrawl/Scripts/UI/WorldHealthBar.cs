using UnityEngine;

namespace CryptCrawl
{
    /// <summary>A small health bar that floats over an enemy once it has been hurt.</summary>
    public class WorldHealthBar : MonoBehaviour
    {
        Actor _owner;
        Transform _fill;
        float _width;
        float _height;
        float _visibleTimer;
        GameObject _root;

        public static WorldHealthBar Create(Actor owner)
        {
            if (owner is SkeletonKing) return null; // the boss uses the big bar at the top of the screen
            var go = new GameObject("Health Bar");
            var bar = go.AddComponent<WorldHealthBar>();
            bar._owner = owner;
            bar._width = Mathf.Clamp(owner.radius * 2.4f, 0.9f, 1.6f);
            bar._height = owner.CenterHeight * 2f + 0.5f;
            bar._root = new GameObject("Root");
            bar._root.transform.SetParent(go.transform, false);
            Quad(bar._root.transform, new Vector3(bar._width + 0.08f, 0.2f, 1f), new Color(0f, 0f, 0f, 0.7f), 0f);
            bar._fill = Quad(bar._root.transform, new Vector3(bar._width, 0.12f, 1f), new Color(0.9f, 0.2f, 0.2f, 1f), -0.01f);
            bar._root.SetActive(false);
            return bar;
        }

        static Transform Quad(Transform parent, Vector3 scale, Color color, float z)
        {
            var q = GameObject.CreatePrimitive(PrimitiveType.Quad);
            Destroy(q.GetComponent<Collider>());
            q.transform.SetParent(parent, false);
            q.transform.localScale = scale;
            q.transform.localPosition = new Vector3(0, 0, z);
            var r = q.GetComponent<Renderer>();
            r.sharedMaterial = MaterialLibrary.Unlit(color);
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            r.receiveShadows = false;
            return q.transform;
        }

        public void Show() => _visibleTimer = 3f;

        void LateUpdate()
        {
            if (_owner == null) { Destroy(gameObject); return; }
            transform.position = _owner.transform.position + Vector3.up * _height;
            var cam = GameManager.Instance != null && GameManager.Instance.CameraRig != null ? GameManager.Instance.CameraRig.Cam : Camera.main;
            if (cam != null) transform.rotation = cam.transform.rotation;

            _visibleTimer -= Time.deltaTime;
            _root.SetActive(_visibleTimer > 0f);
            float k = Mathf.Clamp01(_owner.Health / _owner.maxHealth);
            _fill.localScale = new Vector3(_width * k, 0.12f, 1f);
            _fill.localPosition = new Vector3(-_width * (1f - k) * 0.5f, 0f, -0.01f);
        }
    }
}
