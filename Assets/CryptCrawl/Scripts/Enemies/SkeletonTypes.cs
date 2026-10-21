using UnityEngine;

namespace CryptCrawl
{
    /// <summary>Small, fast and fragile. Comes in groups and runs straight at you.</summary>
    public class SkeletonMinion : Enemy
    {
        float _wobble;

        protected override void Setup()
        {
            InitHealth(22f);
            moveSpeed = 3.1f;
            contactDamage = 10f;
            radius = 0.38f;
            _wobble = Random.value * 10f;
            CreateVisual(Bones(ArtKeys.SkeletonMinion, 1.15f, new Color(0.4f, 1f, 0.5f)));
        }

        protected override void Think(Hero hero)
        {
            _wobble += Time.deltaTime;
            var to = hero.transform.position - transform.position;
            // A little side-to-side weave so a group doesn't move as one blob.
            var side = Vector3.Cross(Vector3.up, to.normalized) * Mathf.Sin(_wobble * 3f) * 0.4f;
            Walk(to.normalized + side);
        }
    }

    /// <summary>Slow and tough. Warns with a red strip, then lunges along it.</summary>
    public class SkeletonWarrior : Enemy
    {
        enum Mode { Approach, WindUp, Lunge, Recover }
        Mode _mode;
        float _timer;
        Vector3 _lungeDir;

        protected override float KnockbackScale => 0.4f;

        protected override void Setup()
        {
            InitHealth(60f);
            moveSpeed = 2.1f;
            contactDamage = 12f;
            radius = 0.5f;
            CreateVisual(Bones(ArtKeys.SkeletonWarrior, 1.75f, new Color(1f, 0.35f, 0.2f)));
        }

        protected override void Think(Hero hero)
        {
            var to = hero.transform.position - transform.position;
            to.y = 0f;
            _timer -= Time.deltaTime;
            switch (_mode)
            {
                case Mode.Approach:
                    Walk(to);
                    if (to.magnitude < 4.2f && _timer <= 0f)
                    {
                        _mode = Mode.WindUp;
                        _timer = 0.65f;
                        _lungeDir = to.normalized;
                        Track(Telegraph.Line(transform.position, _lungeDir, 5f, 1.1f, 0.65f, null));
                    }
                    break;
                case Mode.WindUp:
                    Stand();
                    Face(_lungeDir, 25f);
                    if (_timer <= 0f) { _mode = Mode.Lunge; _timer = 0.32f; Visual.Attack(); contactDamage = 22f; }
                    break;
                case Mode.Lunge:
                    MoveBy(_lungeDir * 14f * Time.deltaTime);
                    if (_timer <= 0f) { _mode = Mode.Recover; _timer = 0.9f; contactDamage = 12f; Fx.Dust(transform.position, 8); }
                    break;
                case Mode.Recover:
                    Stand();
                    if (_timer <= 0f) { _mode = Mode.Approach; _timer = 0.8f; }
                    break;
            }
        }
    }

    /// <summary>Keeps its distance and fires aimed arrows after a short warning line.</summary>
    public class SkeletonArcher : Enemy
    {
        float _shotTimer = 1.5f;
        bool _aiming;
        float _strafe = 1f;

        protected override void Setup()
        {
            InitHealth(28f);
            moveSpeed = 2.4f;
            contactDamage = 8f;
            radius = 0.42f;
            CreateVisual(Bones(ArtKeys.SkeletonRogue, 1.5f, new Color(1f, 0.85f, 0.2f)));
        }

        protected override void Think(Hero hero)
        {
            var to = hero.transform.position - transform.position;
            to.y = 0f;
            float dist = to.magnitude;
            _shotTimer -= Time.deltaTime;

            if (_aiming) { Stand(); Face(to, 20f); return; }

            if (dist < 5f) Walk(-to);                       // too close: back off
            else if (dist > 9f) Walk(to);                   // too far: close in
            else
            {
                if (Random.value < Time.deltaTime * 0.5f) _strafe = -_strafe;
                Walk(Vector3.Cross(Vector3.up, to.normalized) * _strafe, 0.6f);
            }

            if (_shotTimer <= 0f && dist < 12f)
            {
                _aiming = true;
                var dir = to.normalized;
                Track(Telegraph.Line(transform.position, dir, Mathf.Min(dist + 2f, 12f), 0.35f, 0.55f, () =>
                {
                    _aiming = false;
                    _shotTimer = Random.Range(2.0f, 2.6f);
                    if (IsDead) return;
                    Visual.Attack();
                    var p = Projectile.Fire(Team.Undead, transform.position + Vector3.up * 0.9f + dir * 0.5f, dir, 12f, 10f, new Color(1f, 0.8f, 0.3f), 0.2f);
                    p.knockback = 5f;
                }));
            }
        }
    }

    /// <summary>Marks a circle where you're standing, then blows it up. Keep moving!</summary>
    public class SkeletonMage : Enemy
    {
        float _castTimer = 1.8f;
        bool _casting;

        protected override void Setup()
        {
            InitHealth(34f);
            moveSpeed = 1.6f;
            contactDamage = 8f;
            radius = 0.42f;
            var look = Bones(ArtKeys.SkeletonMage, 1.55f, new Color(0.7f, 0.4f, 1f));
            look.hat = true;
            look.accent = new Color(0.3f, 0.18f, 0.45f);
            CreateVisual(look);
        }

        protected override void Think(Hero hero)
        {
            var to = hero.transform.position - transform.position;
            to.y = 0f;
            _castTimer -= Time.deltaTime;

            if (_casting) { Stand(); Face(to); return; }
            if (to.magnitude > 7f) Walk(to);
            else if (to.magnitude < 4f) Walk(-to);
            else Stand();
            Face(to);

            if (_castTimer <= 0f)
            {
                _casting = true;
                Visual.Attack(true);
                var spot = hero.transform.position;
                Fx.Magic(Center + transform.forward * 0.4f, new Color(0.7f, 0.4f, 1f), 14);
                Track(Telegraph.Circle(spot, 1.7f, 1.0f, () => Explode(spot, 1.7f, 18f)));
                Invoke(nameof(EndCast), 0.5f);
            }
        }

        void EndCast()
        {
            _casting = false;
            _castTimer = Random.Range(2.8f, 3.4f);
        }

        public static void Explode(Vector3 spot, float radius, float damage)
        {
            Fx.Magic(spot + Vector3.up * 0.3f, new Color(0.75f, 0.45f, 1f), 30);
            Sfx.Play(Sound.Explode, 0.7f);
            Juice.Shake(0.15f);
            var hero = GameManager.Instance != null ? GameManager.Instance.Hero : null;
            if (hero == null) return;
            var d = hero.transform.position - spot;
            d.y = 0f;
            if (d.magnitude < radius + hero.radius * 0.5f) hero.TakeDamage(damage, d, 8f);
        }
    }
}
