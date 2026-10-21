using System.Collections;
using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// The boss at the end of the floor. Cycles through four attacks, each with a clear
    /// warning, and gets faster and angrier below half health.
    /// </summary>
    public class SkeletonKing : Enemy
    {
        public const string DisplayName = "The Skeleton King";
        bool _enraged;
        Coroutine _brain;

        public override float CenterHeight => 1.4f;
        protected override float KnockbackScale => 0.08f;

        protected override void Setup()
        {
            InitHealth(750f);
            moveSpeed = 1.8f;
            contactDamage = 18f;
            radius = 0.95f;
            var key = ArtLibrary.Get(ArtKeys.SkeletonGolem) != null ? ArtKeys.SkeletonGolem : ArtKeys.SkeletonWarrior;
            var look = Bones(key, 3.2f, new Color(1f, 0.25f, 0.15f));
            look.crown = true;
            look.horns = true;
            CreateVisual(look);
        }

        protected override void Think(Hero hero)
        {
            if (_brain == null)
            {
                Sfx.Play(Sound.BossRoar);
                Juice.Shake(0.5f);
                _brain = StartCoroutine(Brain());
            }
            if (!_enraged && Health < maxHealth * 0.5f)
            {
                _enraged = true;
                moveSpeed *= 1.35f;
                Sfx.Play(Sound.BossRoar);
                Juice.Shake(0.4f);
                Fx.Magic(Center, new Color(1f, 0.3f, 0.2f), 40);
            }
        }

        bool _busy;

        protected override void Update()
        {
            base.Update();
            // Walk towards the hero between attacks.
            if (!IsDead && Ready && !_busy && Target != null && GameManager.Instance.State == GameState.Playing)
            {
                var to = Target.transform.position - transform.position;
                if (to.magnitude > 2.5f) Walk(to); else Stand();
            }
        }

        IEnumerator Brain()
        {
            yield return new WaitForSeconds(1.2f);
            int step = 0;
            while (!IsDead)
            {
                _busy = true;
                switch (step % 4)
                {
                    case 0: yield return BoneRing(); break;
                    case 1: yield return Charge(); break;
                    case 2: yield return Meteors(); break;
                    case 3: yield return Summon(); break;
                }
                _busy = false;
                step++;
                yield return new WaitForSeconds(_enraged ? 1.0f : 1.6f);
            }
        }

        IEnumerator BoneRing()
        {
            Stand();
            Visual.Attack(true);
            Fx.Magic(Center, new Color(1f, 0.3f, 0.2f), 20);
            yield return new WaitForSeconds(0.6f);
            int waves = _enraged ? 4 : 3;
            int count = _enraged ? 20 : 16;
            for (int w = 0; w < waves; w++)
            {
                float offset = w * (180f / count);
                for (int i = 0; i < count; i++)
                {
                    var dir = Quaternion.Euler(0, offset + i * 360f / count, 0) * Vector3.forward;
                    Projectile.Fire(Team.Undead, transform.position + Vector3.up * 1.0f + dir * 1.1f, dir, 12f, 6.5f, new Color(1f, 0.35f, 0.25f), 0.28f);
                }
                Sfx.Play(Sound.Shoot, 0.8f);
                yield return new WaitForSeconds(0.45f);
            }
        }

        IEnumerator Charge()
        {
            var hero = Target;
            if (hero == null) yield break;
            Stand();
            var dir = hero.transform.position - transform.position;
            dir.y = 0f;
            dir.Normalize();
            bool done = false;
            Track(Telegraph.Line(transform.position, dir, 11f, radius * 2.2f, _enraged ? 0.6f : 0.85f, () => done = true));
            while (!done && !IsDead) { Face(dir, 20f); yield return null; }
            if (IsDead) yield break;

            Visual.Attack();
            contactDamage = 28f;
            float t = 0f;
            while (t < 0.6f && !IsDead)
            {
                t += Time.deltaTime;
                MoveBy(dir * 17f * Time.deltaTime);
                yield return null;
            }
            contactDamage = 18f;
            Juice.Shake(0.3f);
            Fx.Dust(transform.position, 25);
            yield return new WaitForSeconds(0.7f);
        }

        IEnumerator Meteors()
        {
            var hero = Target;
            if (hero == null) yield break;
            Stand();
            Visual.Attack(true);
            int n = _enraged ? 5 : 3;
            for (int i = 0; i < n; i++)
            {
                var spot = hero.transform.position + (i == 0 ? Vector3.zero : new Vector3(Random.Range(-3f, 3f), 0, Random.Range(-3f, 3f)));
                spot = Room.Current.ResolveMove(spot, Vector3.zero, 0.5f);
                Track(Telegraph.Circle(spot, 1.9f, 1.1f, () => SkeletonMage.Explode(spot, 1.9f, 20f)));
                yield return new WaitForSeconds(0.25f);
            }
            yield return new WaitForSeconds(0.9f);
        }

        IEnumerator Summon()
        {
            Stand();
            Visual.Attack(true);
            Sfx.Play(Sound.BossRoar, 0.6f);
            int n = _enraged ? 4 : 2;
            var gm = GameManager.Instance;
            for (int i = 0; i < n && gm.AliveEnemies < 7; i++)
            {
                var offset = Quaternion.Euler(0, i * 360f / n + Random.Range(-20f, 20f), 0) * Vector3.forward * 3f;
                var spot = Room.Current.ResolveMove(transform.position + offset, Vector3.zero, 0.4f);
                gm.SpawnEnemy('m', spot);
            }
            yield return new WaitForSeconds(1.0f);
        }

        protected override void OnDeath()
        {
            if (_brain != null) StopCoroutine(_brain);
            Sfx.Play(Sound.BossRoar, 0.8f);
            Juice.HitStop(0.25f);
            Juice.Shake(0.8f);
            for (int i = 0; i < 4; i++) Fx.BoneBurst(transform.position + Random.insideUnitSphere);
            base.OnDeath();
        }
    }
}
