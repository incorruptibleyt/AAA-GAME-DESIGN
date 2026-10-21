using System.Collections.Generic;
using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// Shared skeleton behaviour: rising out of the ground, pushing apart from each other,
    /// contact damage, health bar and death. Each enemy type overrides Think().
    /// </summary>
    public abstract class Enemy : Actor
    {
        public float moveSpeed = 2.5f;
        public float contactDamage = 10f;

        /// <summary>Can't be hit (or targeted) while still climbing out of the floor.</summary>
        public override bool CanBeHit => base.CanBeHit && Ready;

        protected Hero Target => GameManager.Instance != null ? GameManager.Instance.Hero : null;
        protected bool Ready => _spawnTimer <= 0f;

        float _spawnTimer = 0.9f;
        float _contactCooldown;
        WorldHealthBar _bar;
        readonly List<Telegraph> _telegraphs = new List<Telegraph>();

        public static Enemy Spawn(char kind, Vector3 position)
        {
            var go = new GameObject("Enemy " + kind);
            go.transform.position = position;
            go.transform.rotation = Quaternion.Euler(0, 180, 0); // face the hero's side of the room
            Enemy e;
            switch (kind)
            {
                case 'w': e = go.AddComponent<SkeletonWarrior>(); break;
                case 'a': e = go.AddComponent<SkeletonArcher>(); break;
                case 'g': e = go.AddComponent<SkeletonMage>(); break;
                case 'K': e = go.AddComponent<SkeletonKing>(); break;
                default: e = go.AddComponent<SkeletonMinion>(); break;
            }
            e.team = Team.Undead;
            e.Setup();
            e._bar = WorldHealthBar.Create(e);
            Fx.Dust(position, 18);
            return e;
        }

        /// <summary>Set health, speed and the look here.</summary>
        protected abstract void Setup();

        /// <summary>Decide what to do this frame.</summary>
        protected abstract void Think(Hero hero);

        protected static CharacterVisual.Look Bones(string key, float height, Color eyes)
        {
            return new CharacterVisual.Look
            {
                artKey = key,
                height = height,
                body = new Color(0.86f, 0.84f, 0.76f),
                accent = new Color(0.32f, 0.28f, 0.3f),
                eyes = eyes,
            };
        }

        protected virtual void Update()
        {
            if (IsDead) return;

            if (_spawnTimer > 0f)
            {
                // Rise out of the floor.
                _spawnTimer -= Time.deltaTime;
                float k = 1f - Mathf.Clamp01(_spawnTimer / 0.9f);
                Visual.transform.localPosition = Vector3.down * (1f - k) * 1.6f;
                return;
            }
            Visual.transform.localPosition = Vector3.zero;

            var gm = GameManager.Instance;
            var hero = Target;
            if (gm == null || gm.State != GameState.Playing || hero == null || hero.IsDead)
            {
                Visual.SetMoving(false);
                MoveBy(Vector3.zero);
                return;
            }

            Think(hero);
            Separate();
            TouchDamage(hero);
        }

        void Separate()
        {
            foreach (var a in All)
            {
                if (a == this || a.team != team || a.IsDead) continue;
                var d = transform.position - a.transform.position;
                d.y = 0f;
                float min = radius + a.radius;
                float sq = d.sqrMagnitude;
                if (sq < min * min && sq > 0.0001f)
                {
                    float len = Mathf.Sqrt(sq);
                    var push = d / len * (min - len) * 0.5f;
                    transform.position = Room.Current != null ? Room.Current.ResolveMove(transform.position, push, radius) : transform.position + push;
                }
            }
        }

        void TouchDamage(Hero hero)
        {
            _contactCooldown -= Time.deltaTime;
            if (contactDamage <= 0f || _contactCooldown > 0f) return;
            var d = hero.transform.position - transform.position;
            d.y = 0f;
            float reach = radius + hero.radius + 0.1f;
            if (d.sqrMagnitude < reach * reach)
            {
                _contactCooldown = 0.8f;
                hero.TakeDamage(contactDamage, d, 9f);
            }
        }

        /// <summary>Walk towards (or away from) a point.</summary>
        protected void Walk(Vector3 direction, float speedScale = 1f)
        {
            direction.y = 0f;
            if (direction.sqrMagnitude < 0.0001f) { Visual.SetMoving(false); MoveBy(Vector3.zero); return; }
            direction.Normalize();
            MoveBy(direction * moveSpeed * speedScale * Time.deltaTime);
            Face(direction, 10f);
            Visual.SetMoving(true);
        }

        protected void Stand()
        {
            Visual.SetMoving(false);
            MoveBy(Vector3.zero);
        }

        protected Telegraph Track(Telegraph t)
        {
            _telegraphs.RemoveAll(x => x == null);
            _telegraphs.Add(t);
            return t;
        }

        public override void TakeDamage(float amount, Vector3 direction, float knockback, bool crit = false)
        {
            if (!CanBeHit) return;
            base.TakeDamage(amount, direction, knockback * KnockbackScale, crit);
            if (_bar != null) _bar.Show();
        }

        /// <summary>Heavier enemies get pushed less.</summary>
        protected virtual float KnockbackScale => 1f;

        protected override void OnDeath()
        {
            foreach (var t in _telegraphs) if (t != null) t.Cancel();
            _telegraphs.Clear();
            Visual.Die();
            Fx.BoneBurst(transform.position);
            Sfx.Play(Sound.EnemyDie, 0.8f);
            Juice.HitStop(0.035f);
            Juice.Shake(0.12f);
            if (_bar != null) Destroy(_bar.gameObject);
            var hero = Target;
            if (hero != null) hero.OnKill();
            if (GameManager.Instance != null) GameManager.Instance.OnEnemyDied(this);
            Destroy(gameObject, 2.5f);
        }
    }
}
