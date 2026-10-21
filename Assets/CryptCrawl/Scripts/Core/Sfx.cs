using System.Collections.Generic;
using UnityEngine;

namespace CryptCrawl
{
    public enum Sound { Shoot, Hit, EnemyDie, PlayerHurt, DoorOpen, Upgrade, Warn, Explode, BossRoar, Victory }

    /// <summary>
    /// Placeholder sound effects synthesised in code, so the slice has audio with no
    /// files imported. Swap them for a free CC0 sound pack later (see the setup guide).
    /// </summary>
    public class Sfx : MonoBehaviour
    {
        static Sfx _instance;
        readonly Dictionary<Sound, AudioClip> _clips = new Dictionary<Sound, AudioClip>();
        AudioSource _source;
        const int Rate = 22050;

        public static void Play(Sound s, float volume = 1f)
        {
            if (_instance == null) return;
            if (_instance._clips.TryGetValue(s, out var clip))
                _instance._source.PlayOneShot(clip, volume * Random.Range(0.9f, 1f));
        }

        void Awake()
        {
            _instance = this;
            _source = gameObject.AddComponent<AudioSource>();
            _source.playOnAwake = false;
            _source.spatialBlend = 0f;

            _clips[Sound.Shoot] = Synth("shoot", 0.12f, t => Sweep(t, 900, 300) * Env(t, 0.12f) * 0.35f);
            _clips[Sound.Hit] = Synth("hit", 0.1f, t => (Noise() * 0.6f + Square(t, 140) * 0.4f) * Env(t, 0.1f) * 0.5f);
            _clips[Sound.EnemyDie] = Synth("die", 0.3f, t => (Noise() * 0.7f + Sweep(t, 400, 60) * 0.3f) * Env(t, 0.3f) * 0.5f);
            _clips[Sound.PlayerHurt] = Synth("hurt", 0.25f, t => Square(t, 110 - t * 200) * Env(t, 0.25f) * 0.4f);
            _clips[Sound.DoorOpen] = Synth("door", 0.6f, t => (Noise() * 0.3f + Square(t, 55) * 0.2f) * Env(t, 0.6f) * 0.5f);
            _clips[Sound.Upgrade] = Synth("upgrade", 0.45f, t => (Sine(t, 523) + Sine(t, t > 0.15f ? 784 : 659)) * Env(t, 0.45f) * 0.25f);
            _clips[Sound.Warn] = Synth("warn", 0.18f, t => Sine(t, 1200) * Env(t, 0.18f) * 0.15f);
            _clips[Sound.Explode] = Synth("explode", 0.5f, t => Noise() * Env(t, 0.5f) * 0.6f);
            _clips[Sound.BossRoar] = Synth("roar", 1.1f, t => (Square(t, 70 + Mathf.Sin(t * 30) * 8) * 0.5f + Noise() * 0.3f) * Env(t, 1.1f) * 0.6f);
            _clips[Sound.Victory] = Synth("victory", 1.2f, t => (Sine(t, 523) + Sine(t, 659) * (t > 0.3f ? 1 : 0) + Sine(t, 784) * (t > 0.6f ? 1 : 0)) * Env(t, 1.2f) * 0.2f);
        }

        static AudioClip Synth(string name, float seconds, System.Func<float, float> wave)
        {
            int n = Mathf.CeilToInt(seconds * Rate);
            var data = new float[n];
            for (int i = 0; i < n; i++) data[i] = Mathf.Clamp(wave(i / (float)Rate), -1f, 1f);
            var clip = AudioClip.Create(name, n, 1, Rate, false);
            clip.SetData(data, 0);
            return clip;
        }

        static readonly System.Random Rng = new System.Random(3);
        static float Noise() => (float)(Rng.NextDouble() * 2.0 - 1.0);
        static float Sine(float t, float hz) => Mathf.Sin(2f * Mathf.PI * hz * t);
        static float Square(float t, float hz) => Mathf.Sign(Mathf.Sin(2f * Mathf.PI * hz * t));
        static float Sweep(float t, float from, float to) => Mathf.Sin(2f * Mathf.PI * Mathf.Lerp(from, to, t * 4f) * t);
        static float Env(float t, float len) => Mathf.Clamp01(t / 0.005f) * Mathf.Pow(1f - Mathf.Clamp01(t / len), 2f);
    }
}
