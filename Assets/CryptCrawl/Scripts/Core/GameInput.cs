using UnityEngine;
#if ENABLE_INPUT_SYSTEM && !ENABLE_LEGACY_INPUT_MANAGER
using UnityEngine.InputSystem;
#endif

namespace CryptCrawl
{
    /// <summary>
    /// One place that reads touch, mouse and keyboard, so the rest of the game never
    /// has to care which device (or which Unity input setting) is in use.
    /// A single finger (or the left mouse button) acts as the thumb.
    /// </summary>
    public static class GameInput
    {
        public static bool PointerDown { get; private set; }
        public static bool PointerHeld { get; private set; }
        public static bool PointerUp { get; private set; }
        public static Vector2 PointerPosition { get; private set; }

        /// <summary>WASD / arrow keys, for testing in the editor without a phone.</summary>
        public static Vector2 KeyboardMove { get; private set; }

        static bool _wasHeld;

        /// <summary>Called once per frame by GameManager before anything else updates.</summary>
        public static void Poll()
        {
            bool held;
            Vector2 pos;
            Vector2 keys;
            ReadDevices(out held, out pos, out keys);

            PointerDown = held && !_wasHeld;
            PointerUp = !held && _wasHeld;
            PointerHeld = held;
            if (held) PointerPosition = pos; // on release, keep the last position
            KeyboardMove = keys.sqrMagnitude > 1f ? keys.normalized : keys;
            _wasHeld = held;
        }

#if ENABLE_INPUT_SYSTEM && !ENABLE_LEGACY_INPUT_MANAGER
        static void ReadDevices(out bool held, out Vector2 pos, out Vector2 keys)
        {
            held = false;
            pos = Vector2.zero;
            var touch = Touchscreen.current;
            if (touch != null && touch.primaryTouch.press.isPressed)
            {
                held = true;
                pos = touch.primaryTouch.position.ReadValue();
            }
            else if (Mouse.current != null && Mouse.current.leftButton.isPressed)
            {
                held = true;
                pos = Mouse.current.position.ReadValue();
            }

            keys = Vector2.zero;
            var kb = Keyboard.current;
            if (kb != null)
            {
                if (kb.aKey.isPressed || kb.leftArrowKey.isPressed) keys.x -= 1f;
                if (kb.dKey.isPressed || kb.rightArrowKey.isPressed) keys.x += 1f;
                if (kb.sKey.isPressed || kb.downArrowKey.isPressed) keys.y -= 1f;
                if (kb.wKey.isPressed || kb.upArrowKey.isPressed) keys.y += 1f;
            }
        }
#else
        static void ReadDevices(out bool held, out Vector2 pos, out Vector2 keys)
        {
            held = false;
            pos = Vector2.zero;
            if (Input.touchCount > 0)
            {
                var t = Input.GetTouch(0);
                held = t.phase != TouchPhase.Ended && t.phase != TouchPhase.Canceled;
                pos = t.position;
            }
            else if (Input.GetMouseButton(0))
            {
                held = true;
                pos = Input.mousePosition;
            }

            keys = Vector2.zero;
            if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow)) keys.x -= 1f;
            if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow)) keys.x += 1f;
            if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow)) keys.y -= 1f;
            if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow)) keys.y += 1f;
        }
#endif
    }
}
