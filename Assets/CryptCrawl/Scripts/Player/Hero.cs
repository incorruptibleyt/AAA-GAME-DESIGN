using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// The player's hero. Drag your thumb to move; stand still and the hero
    /// automatically fires at the nearest skeleton.
    /// </summary>
    public class Hero : Actor
    {
        public HeroStats stats = new HeroStats();

        float _shotTimer;
        float _invulnerable;
        bool _moving;
        Light _lantern;

        public override float CenterHeight => 0.75f;
        public override bool CanBeHit => base.CanBeHit && _invulnerable <= 0f;

        public static Hero Spawn(Vector3 position)
        {
            var go = new GameObject("Hero");
            go.transform.position = position;
            var hero = go.AddComponent<Hero>();
            hero.team = Team.Hero;
            hero.radius = 0.4f;
            hero.InitHealth(hero.stats.maxHealth);

            string key = ArtLibrary.Get(ArtKeys.Ranger) != null ? ArtKeys.Ranger
                : ArtLibrary.Get(ArtKeys.Rogue) != null ? ArtKeys.Rogue : ArtKeys.Knight;
            hero.CreateVisual(new CharacterVisual.Look
            {
                artKey = key,
                height = 1.6f,
                body = new Color(0.25f, 0.45f, 0.75f),
                accent = new Color(0.85f, 0.75f, 0.5f),
                eyes = new Color(0.6f, 0.9f, 1f),
                hood = true,
            });

            // A soft light that travels with the hero so they never get lost in the dark.
            var lg = new GameObject("Lantern");
            lg.transform.SetParent(go.transform, false);
            lg.transform.localPosition = new Vector3(0, 2.2f, 0);
            hero._lantern = lg.AddComponent<Light>();
            hero._lantern.type = LightType.Point;
            hero._lantern.color = new Color(0.75f, 0.85f, 1f);
            hero._lantern.range = 7f;
            hero._lantern.intensity = 1.1f;
            hero._lantern.shadows = LightShadows.None;
            return hero;
        }

        public void PlaceAt(Vector3 position)
        {
            transform.position = position;
            transform.rotation = Quaternion.identity;
            Knockback = Vector3.zero;
            _shotTimer = 0.4f;
        }

        public void RefreshMaxHealth(float healBy)
        {
            maxHealth = stats.maxHealth;
            Heal(healBy);
        }

        public void OnKill()
        {
            if (stats.healOnKill > 0f) Heal(stats.healOnKill);
        }

        void Update()
        {
            if (IsDead) return;
            if (_invulnerable > 0f)
            {
                _invulnerable -= Time.deltaTime;
                // Blink while invulnerable.
                if (Visual != null) Visual.SetVisible(_invulnerable <= 0f || Mathf.Repeat(_invulnerable, 0.12f) > 0.05f);
            }

            var gm = GameManager.Instance;
            bool playing = gm != null && gm.State == GameState.Playing;
            Vector2 stick = playing ? gm.Hud.JoystickVector + GameInput.KeyboardMove : Vector2.zero;
            if (stick.sqrMagnitude > 1f) stick.Normalize();

            var move = new Vector3(stick.x, 0f, stick.y);
            _moving = move.sqrMagnitude > 0.02f;
            Visual.SetMoving(_moving);

            if (_moving)
            {
                MoveBy(move * stats.moveSpeed * Time.deltaTime);
                Face(move);
                // Firing resumes shortly after you stop.
                _shotTimer = Mathf.Max(_shotTimer, 0.12f);
            }
            else
            {
                MoveBy(Vector3.zero);
                if (playing) AutoAttack();
            }

            if (gm != null && playing && Room.Current != null && Room.Current.IsAtExit(transform.position))
                gm.EnterNextRoom();
        }

        void AutoAttack()
        {
            var target = Nearest(transform.position, Team.Undead);
            _shotTimer -= Time.deltaTime;
            if (target == null) return;

            var toTarget = target.transform.position - transform.position;
            Face(toTarget, 30f);
            if (_shotTimer > 0f) return;
            _shotTimer = 1f / stats.shotsPerSecond;
            Shoot(toTarget.normalized);
        }

        void Shoot(Vector3 forward)
        {
            Visual.Attack();
            Sfx.Play(Sound.Shoot, 0.5f);
            var right = Vector3.Cross(Vector3.up, forward);
            var origin = transform.position + Vector3.up * 0.9f + forward * 0.5f;
            var color = stats.burnDps > 0f ? new Color(1f, 0.55f, 0.2f) : new Color(0.55f, 0.85f, 1f);

            // Parallel bolts in front, spaced side by side.
            for (int i = 0; i < stats.frontBolts; i++)
            {
                float offset = (i - (stats.frontBolts - 1) * 0.5f) * 0.35f;
                Fire(origin + right * offset, forward, color);
            }
            for (int i = 0; i < stats.diagonalBolts; i++)
            {
                float angle = 30f + i * 15f;
                Fire(origin, Quaternion.Euler(0, angle, 0) * forward, color);
                Fire(origin, Quaternion.Euler(0, -angle, 0) * forward, color);
            }
            for (int i = 0; i < stats.rearBolts; i++)
                Fire(transform.position + Vector3.up * 0.9f - forward * 0.5f, -forward, color);
        }

        void Fire(Vector3 origin, Vector3 dir, Color color)
        {
            var p = Projectile.Fire(Team.Hero, origin, dir, stats.damage, stats.boltSpeed, color);
            p.pierce = stats.pierce;
            p.critChance = stats.critChance;
            p.burnDps = stats.burnDps;
        }

        public override void TakeDamage(float amount, Vector3 direction, float knockback, bool crit = false)
        {
            if (!CanBeHit) return;
            base.TakeDamage(amount, direction, knockback, crit);
            Sfx.Play(Sound.PlayerHurt);
            Juice.Shake(0.35f);
            Juice.HitStop(0.06f);
            _invulnerable = 0.7f;
        }

        protected override void OnDeath()
        {
            if (Visual != null) { Visual.SetVisible(true); Visual.Die(); }
            Juice.Shake(0.6f);
            if (GameManager.Instance != null) GameManager.Instance.OnHeroDied();
        }
    }
}
