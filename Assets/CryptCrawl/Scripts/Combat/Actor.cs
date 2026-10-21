using System;
using System.Collections.Generic;
using UnityEngine;

namespace CryptCrawl
{
    public enum Team { Hero, Undead }

    /// <summary>
    /// Anything that has health and can be hit: the hero, skeletons and the boss.
    /// </summary>
    public abstract class Actor : MonoBehaviour
    {
        public static readonly List<Actor> All = new List<Actor>();

        public Team team;
        public float radius = 0.45f;
        public float maxHealth = 100f;
        public float Health { get; protected set; }
        public bool IsDead { get; private set; }
        public CharacterVisual Visual { get; protected set; }

        /// <summary>Height of the body centre, used to aim projectiles and place effects.</summary>
        public virtual float CenterHeight => 0.8f;

        public event Action<Actor> Died;
        public event Action<Actor, float> Damaged;

        protected Vector3 Knockback;

        protected virtual void OnEnable() => All.Add(this);
        protected virtual void OnDisable() => All.Remove(this);

        protected void InitHealth(float max)
        {
            maxHealth = max;
            Health = max;
        }

        protected CharacterVisual CreateVisual(CharacterVisual.Look look)
        {
            var go = new GameObject("Visual");
            go.transform.SetParent(transform, false);
            Visual = go.AddComponent<CharacterVisual>();
            Visual.Build(look);
            return Visual;
        }

        public Vector3 Center => transform.position + Vector3.up * CenterHeight;

        public virtual bool CanBeHit => !IsDead;

        public virtual void TakeDamage(float amount, Vector3 direction, float knockback, bool crit = false)
        {
            if (!CanBeHit) return;
            Health -= amount;
            direction.y = 0f;
            Knockback += direction.normalized * knockback;
            Damaged?.Invoke(this, amount);
            DamageNumbers.Show(Center + Vector3.up * 0.6f, amount, team == Team.Hero ? new Color(1f, 0.35f, 0.35f) : crit ? new Color(1f, 0.85f, 0.2f) : Color.white, crit);
            Fx.HitSparks(Center);
            if (Visual != null) Visual.Hit();

            if (Health <= 0f)
            {
                Health = 0f;
                IsDead = true;
                OnDeath();
                Died?.Invoke(this);
            }
        }

        public void Heal(float amount)
        {
            if (IsDead) return;
            Health = Mathf.Min(maxHealth, Health + amount);
            DamageNumbers.Show(Center + Vector3.up * 0.6f, amount, new Color(0.4f, 1f, 0.5f), false, "+");
        }

        protected abstract void OnDeath();

        /// <summary>Move with the room's collision, and bleed off any knockback.</summary>
        protected void MoveBy(Vector3 delta)
        {
            delta += Knockback * Time.deltaTime;
            Knockback = Vector3.MoveTowards(Knockback, Vector3.zero, 40f * Time.deltaTime);
            var room = Room.Current;
            transform.position = room != null ? room.ResolveMove(transform.position, delta, radius) : transform.position + delta;
        }

        protected void Face(Vector3 direction, float sharpness = 18f)
        {
            direction.y = 0f;
            if (direction.sqrMagnitude < 0.0001f) return;
            var goal = Quaternion.LookRotation(direction);
            transform.rotation = Quaternion.Slerp(transform.rotation, goal, 1f - Mathf.Exp(-sharpness * Time.deltaTime));
        }

        public static Actor Nearest(Vector3 from, Team team, float maxDistance = float.MaxValue)
        {
            Actor best = null;
            float bestSq = maxDistance * maxDistance;
            foreach (var a in All)
            {
                if (a.team != team || !a.CanBeHit) continue;
                float sq = (a.transform.position - from).sqrMagnitude;
                if (sq < bestSq) { bestSq = sq; best = a; }
            }
            return best;
        }
    }
}
