using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// Particle effects built from code: hit sparks, death poofs, spawn dust and
    /// pickup glints. One shared particle system per effect type, positioned and
    /// "emitted" on demand, which is cheap enough for phones.
    /// </summary>
    public static class Fx
    {
        static ParticleSystem _sparks, _bones, _dust, _magic;

        static ParticleSystem Make(string name, Color color, float size, float speed, float life, float gravity, bool additive)
        {
            var go = new GameObject("FX_" + name);
            Object.DontDestroyOnLoad(go);
            var ps = go.AddComponent<ParticleSystem>();
            ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);

            var main = ps.main;
            main.playOnAwake = false;
            main.loop = false;
            main.duration = 1f;
            main.startLifetime = new ParticleSystem.MinMaxCurve(life * 0.6f, life);
            main.startSpeed = new ParticleSystem.MinMaxCurve(speed * 0.4f, speed);
            main.startSize = new ParticleSystem.MinMaxCurve(size * 0.5f, size);
            main.startColor = color;
            main.gravityModifier = gravity;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = 400;
            main.useUnscaledTime = false;

            var emission = ps.emission;
            emission.rateOverTime = 0f;

            var shape = ps.shape;
            shape.shapeType = ParticleSystemShapeType.Sphere;
            shape.radius = 0.15f;

            var sizeOverLife = ps.sizeOverLifetime;
            sizeOverLife.enabled = true;
            sizeOverLife.size = new ParticleSystem.MinMaxCurve(1f, AnimationCurve.Linear(0, 1, 1, 0));

            var renderer = go.GetComponent<ParticleSystemRenderer>();
            var c = additive ? new Color(color.r, color.g, color.b, 1f) : color;
            renderer.sharedMaterial = MaterialLibrary.Unlit(c, MaterialLibrary.SoftCircle);
            renderer.renderMode = ParticleSystemRenderMode.Billboard;
            return ps;
        }

        static void Emit(ref ParticleSystem ps, System.Func<ParticleSystem> create, Vector3 pos, int count, Color? tint = null)
        {
            if (ps == null) ps = create();
            var p = new ParticleSystem.EmitParams { position = pos, applyShapeToPosition = true };
            if (tint.HasValue) p.startColor = tint.Value;
            ps.Emit(p, count);
        }

        public static void HitSparks(Vector3 pos, Color? tint = null) =>
            Emit(ref _sparks, () => Make("Sparks", new Color(1f, 0.85f, 0.5f), 0.25f, 7f, 0.35f, 0.5f, true), pos, 10, tint);

        public static void BoneBurst(Vector3 pos) =>
            Emit(ref _bones, () => Make("Bones", new Color(0.92f, 0.9f, 0.82f), 0.32f, 6f, 0.8f, 2.2f, false), pos + Vector3.up * 0.6f, 22);

        public static void Dust(Vector3 pos, int count = 14) =>
            Emit(ref _dust, () => Make("Dust", new Color(0.55f, 0.5f, 0.6f, 0.6f), 0.7f, 1.6f, 0.9f, -0.05f, false), pos + Vector3.up * 0.2f, count);

        public static void Magic(Vector3 pos, Color color, int count = 18) =>
            Emit(ref _magic, () => Make("Magic", Color.white, 0.35f, 4f, 0.6f, -0.2f, true), pos, count, color);
    }
}
