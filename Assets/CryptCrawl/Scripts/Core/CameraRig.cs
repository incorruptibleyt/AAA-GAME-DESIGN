using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// Angled top-down camera that follows the hero along the length of the room and
    /// always fits the full room width on screen, whatever the phone's shape.
    /// </summary>
    public class CameraRig : MonoBehaviour
    {
        public Transform target;
        public float pitch = 58f;
        public float fieldOfView = 42f;
        public float minDistance = 17f;
        public float followSharpness = 8f;

        Camera _cam;
        float _shake;
        float _roomHalfLength = 10f;
        float _roomHalfWidth = 6f;
        Vector3 _focus;

        public Camera Cam => _cam;

        void Awake()
        {
            _cam = GetComponent<Camera>();
            _cam.fieldOfView = fieldOfView;
            _cam.nearClipPlane = 0.3f;
            _cam.farClipPlane = 120f;
            _cam.clearFlags = CameraClearFlags.SolidColor;
            _cam.backgroundColor = new Color(0.02f, 0.02f, 0.035f);
        }

        public void SetRoom(float halfWidth, float halfLength)
        {
            _roomHalfWidth = halfWidth;
            _roomHalfLength = halfLength;
        }

        public void Snap()
        {
            if (target == null) return;
            _focus = ClampFocus(target.position);
            transform.position = DesiredPosition(_focus);
            transform.rotation = Quaternion.Euler(pitch, 0f, 0f);
        }

        public void Shake(float amount)
        {
            _shake = Mathf.Max(_shake, amount);
        }

        void LateUpdate()
        {
            if (target == null) return;
            var goal = ClampFocus(target.position);
            _focus = Vector3.Lerp(_focus, goal, 1f - Mathf.Exp(-followSharpness * Time.unscaledDeltaTime));
            var pos = DesiredPosition(_focus);

            if (_shake > 0.001f)
            {
                pos += Random.insideUnitSphere * _shake;
                _shake = Mathf.MoveTowards(_shake, 0f, Time.unscaledDeltaTime * 2.5f);
            }

            transform.position = pos;
            transform.rotation = Quaternion.Euler(pitch, 0f, 0f);
        }

        float Distance()
        {
            // Pick a distance where the room width (plus a margin) fits horizontally.
            float halfH = Mathf.Atan(Mathf.Tan(fieldOfView * 0.5f * Mathf.Deg2Rad) * _cam.aspect);
            float needed = (_roomHalfWidth + 1.2f) / Mathf.Tan(halfH);
            return Mathf.Max(minDistance, needed);
        }

        Vector3 DesiredPosition(Vector3 focus)
        {
            var rot = Quaternion.Euler(pitch, 0f, 0f);
            return focus - rot * Vector3.forward * Distance();
        }

        Vector3 ClampFocus(Vector3 p)
        {
            // Look slightly ahead (north) of the hero and stop at the room ends.
            float z = Mathf.Clamp(p.z + 1.5f, -_roomHalfLength + 5f, _roomHalfLength - 4f);
            return new Vector3(0f, 0f, z);
        }
    }
}
