using System.Collections.Generic;
using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// Arrows, bolts and bone shards. Moves in a straight line, hits the first actor of
    /// the other team it touches, and stops at walls and pillars.
    /// </summary>
    public class Projectile : MonoBehaviour
    {
        public Team owner;
        public float damage;
        public float speed;
        public float radius = 0.2f;
        public int pierce;
        public float knockback = 4f;
        public float critChance;
        public float burnDps;
        public float life = 4f;

        Vector3 _dir;
        readonly HashSet<Actor> _alreadyHit = new HashSet<Actor>();

        public static Projectile Fire(Team owner, Vector3 origin, Vector3 direction, float damage, float speed, Color color, float size = 0.22f)
        {
            var go = new GameObject(owner == Team.Hero ? "Bolt" : "Enemy Shot");
            if (Room.Current != null) go.transform.SetParent(Room.Current.transform, false); // cleaned up with the room
            go.transform.position = origin;
            direction.y = 0f;
            direction.Normalize();
            go.transform.rotation = Quaternion.LookRotation(direction);

            var core = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            Destroy(core.GetComponent<Collider>());
            core.transform.SetParent(go.transform, false);
            core.transform.localScale = new Vector3(size, size, size * (owner == Team.Hero ? 2.6f : 1.4f));
            var r = core.GetComponent<Renderer>();
            r.sharedMaterial = MaterialLibrary.Lit(color, 0.5f, 2.5f);
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;

            var trail = go.AddComponent<TrailRenderer>();
            trail.time = 0.12f;
            trail.widthMultiplier = size * 0.9f;
            trail.widthCurve = AnimationCurve.Linear(0, 1, 1, 0);
            trail.sharedMaterial = MaterialLibrary.Unlit(Color.white, MaterialLibrary.SoftCircle);
            trail.startColor = new Color(color.r, color.g, color.b, 0.9f);
            trail.endColor = new Color(color.r, color.g, color.b, 0f);
            trail.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;

            var p = go.AddComponent<Projectile>();
            p.owner = owner;
            p._dir = direction;
            p.damage = damage;
            p.speed = speed;
            p.radius = size;
            return p;
        }

        void Update()
        {
            life -= Time.deltaTime;
            var step = _dir * speed * Time.deltaTime;
            var next = transform.position + step;

            var room = Room.Current;
            if (life <= 0f || (room != null && room.BlocksProjectile(next, radius * 0.5f)))
            {
                Fx.HitSparks(transform.position, owner == Team.Hero ? (Color?)null : new Color(0.7f, 0.5f, 1f));
                Destroy(gameObject);
                return;
            }
            transform.position = next;

            var target = owner == Team.Hero ? Team.Undead : Team.Hero;
            for (int i = Actor.All.Count - 1; i >= 0; i--)
            {
                var a = Actor.All[i];
                if (a.team != target || !a.CanBeHit || _alreadyHit.Contains(a)) continue;
                var d = a.transform.position - next;
                d.y = 0f;
                float reach = a.radius + radius;
                if (d.sqrMagnitude > reach * reach) continue;

                _alreadyHit.Add(a);
                bool crit = Random.value < critChance;
                a.TakeDamage(crit ? damage * 2f : damage, _dir, knockback, crit);
                if (burnDps > 0f && !a.IsDead) Burning.Apply(a, burnDps, 2.5f);
                if (owner == Team.Hero) Sfx.Play(Sound.Hit, 0.6f);

                if (pierce-- <= 0)
                {
                    Destroy(gameObject);
                    return;
                }
            }
        }
    }

    /// <summary>Damage over time from the Fire Bolts upgrade.</summary>
    public class Burning : MonoBehaviour
    {
        float _dps, _remaining, _tick;
        Actor _actor;

        public static void Apply(Actor a, float dps, float seconds)
        {
            var b = a.GetComponent<Burning>();
            if (b == null) b = a.gameObject.AddComponent<Burning>();
            b._actor = a;
            b._dps = Mathf.Max(b._dps, dps);
            b._remaining = seconds;
        }

        void Update()
        {
            _remaining -= Time.deltaTime;
            _tick -= Time.deltaTime;
            if (_actor == null || _actor.IsDead || _remaining <= 0f) { Destroy(this); return; }
            if (_tick <= 0f)
            {
                _tick = 0.5f;
                Fx.Magic(_actor.Center, new Color(1f, 0.5f, 0.1f), 6);
                _actor.TakeDamage(_dps * 0.5f, Vector3.zero, 0f);
            }
        }
    }
}
