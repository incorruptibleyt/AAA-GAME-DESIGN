using System.Collections;
using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// "Game feel" helpers: hit-stop (a tiny freeze when something is hit hard) and
    /// screen shake. These small touches are a big part of why combat feels good.
    /// </summary>
    public static class Juice
    {
        static Coroutine _hitStop;
        static float _baseTimeScale = 1f;

        public static void HitStop(float seconds)
        {
            var gm = GameManager.Instance;
            if (gm == null || gm.IsPaused) return;
            if (_hitStop != null) gm.StopCoroutine(_hitStop);
            _hitStop = gm.StartCoroutine(HitStopRoutine(seconds));
        }

        static IEnumerator HitStopRoutine(float seconds)
        {
            Time.timeScale = 0.05f;
            yield return new WaitForSecondsRealtime(seconds);
            if (GameManager.Instance != null && !GameManager.Instance.IsPaused) Time.timeScale = _baseTimeScale;
            _hitStop = null;
        }

        public static void Shake(float amount)
        {
            var gm = GameManager.Instance;
            if (gm != null && gm.CameraRig != null) gm.CameraRig.Shake(amount);
        }
    }
}
