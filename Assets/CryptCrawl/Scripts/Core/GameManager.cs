using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace CryptCrawl
{
    public enum GameState { Title, Playing, Upgrade, Transition, Paused, Dead, Victory }

    /// <summary>
    /// Runs the game: title screen, the run through the rooms of a floor, upgrade picks,
    /// the boss, and the win/lose screens. It builds the whole scene from code when Play
    /// is pressed, so you never have to set anything up by hand.
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public class GameManager : MonoBehaviour
    {
        public static GameManager Instance { get; private set; }

        public GameState State { get; private set; }
        public Hero Hero { get; private set; }
        public Hud Hud { get; private set; }
        public CameraRig CameraRig { get; private set; }
        public SkeletonKing Boss { get; private set; }
        public int AliveEnemies => _alive;
        public bool IsPaused => State == GameState.Paused || State == GameState.Upgrade;

        const int EasyRooms = 2, MediumRooms = 2, HardRooms = 1;
        const string BestRoomKey = "cc_best_room", WinsKey = "cc_wins";

        readonly List<string[]> _run = new List<string[]>();
        readonly Dictionary<string, int> _taken = new Dictionary<string, int>();
        int _roomIndex;
        int _alive;
        int _kills;
        float _runTime;
        float _stateTime;
        GameState _stateBeforePause;

        int CombatRoomCount => _run.Count - 1;
        bool InBossRoom => _roomIndex == _run.Count - 1;

        void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;

            Application.targetFrameRate = 60;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;

            SetupLighting();
            SetupCamera();
            gameObject.AddComponent<Sfx>();
            Hud = Hud.Create();
            Hud.SetFade(1f);
        }

        void Start()
        {
            BuildRun();
            LoadRoom(0, spawnEnemies: false);
            Hero.PlaceAt(new Vector3(0f, 0f, -2f));
            CameraRig.Snap();
            SetState(GameState.Title);
            Hud.ShowHud(false);
            Hud.ShowTitle(true, BestText());
            StartCoroutine(Fade(1f, 0f, 0.6f));
        }

        void Update()
        {
            GameInput.Poll();
            _stateTime += Time.unscaledDeltaTime;
            if (State == GameState.Playing) _runTime += Time.deltaTime;

            switch (State)
            {
                case GameState.Title:
                    if (GameInput.PointerDown) StartRun();
                    break;
                case GameState.Dead:
                case GameState.Victory:
                    if (_stateTime > 1.5f && (GameInput.PointerDown)) StartCoroutine(Restart());
                    break;
                case GameState.Paused:
                    if (GameInput.PointerDown) Resume();
                    break;
            }
        }

        void OnApplicationPause(bool paused)
        {
            if (paused && State == GameState.Playing) Pause();
        }

        // ------------------------------------------------------------------ setup

        void SetupLighting()
        {
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.17f, 0.16f, 0.24f);
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Exponential;
            RenderSettings.fogDensity = 0.018f;
            RenderSettings.fogColor = new Color(0.02f, 0.02f, 0.04f);
            QualitySettings.shadowDistance = 45f;

            var moon = new GameObject("Moonlight").AddComponent<Light>();
            moon.type = LightType.Directional;
            moon.transform.rotation = Quaternion.Euler(55f, -35f, 0f);
            moon.color = new Color(0.55f, 0.6f, 0.9f);
            moon.intensity = 0.45f;
            moon.shadows = LightShadows.Soft;
            moon.shadowStrength = 0.75f;
            RenderSettings.sun = moon;
        }

        void SetupCamera()
        {
            var cam = Camera.main;
            if (cam == null)
            {
                cam = new GameObject("Main Camera").AddComponent<Camera>();
                cam.tag = "MainCamera";
                cam.gameObject.AddComponent<AudioListener>();
            }
            CameraRig = cam.gameObject.GetComponent<CameraRig>();
            if (CameraRig == null) CameraRig = cam.gameObject.AddComponent<CameraRig>();
        }

        // ------------------------------------------------------------------ run flow

        void BuildRun()
        {
            _run.Clear();
            AddShuffled(RoomLayouts.Easy, EasyRooms);
            AddShuffled(RoomLayouts.Medium, MediumRooms);
            AddShuffled(RoomLayouts.Hard, HardRooms);
            _run.Add(RoomLayouts.Boss);
        }

        void AddShuffled(string[][] pool, int count)
        {
            var list = new List<string[]>(pool);
            for (int i = 0; i < count && list.Count > 0; i++)
            {
                int pick = Random.Range(0, list.Count);
                _run.Add(list[pick]);
                list.RemoveAt(pick);
            }
        }

        void StartRun()
        {
            Hud.ShowTitle(false);
            Hud.ShowHud(true);
            _runTime = 0f;
            _kills = 0;
            _taken.Clear();
            StartCoroutine(GoToRoom(0));
        }

        IEnumerator Restart()
        {
            SetState(GameState.Transition);
            yield return Fade(0f, 1f, 0.4f);
            Hud.ShowEnd(false);
            if (Hero != null) Destroy(Hero.gameObject);
            Hero = null;
            BuildRun();
            _runTime = 0f;
            _kills = 0;
            _taken.Clear();
            Hud.ShowHud(true);
            LoadRoom(0, spawnEnemies: true);
            yield return Fade(1f, 0f, 0.4f);
        }

        public void EnterNextRoom()
        {
            if (State != GameState.Playing) return;
            StartCoroutine(GoToRoom(_roomIndex + 1));
        }

        IEnumerator GoToRoom(int index)
        {
            SetState(GameState.Transition);
            if (index > 0) yield return Fade(0f, 1f, 0.35f);
            LoadRoom(index, spawnEnemies: true);
            yield return Fade(1f, 0f, 0.35f);
        }

        void LoadRoom(int index, bool spawnEnemies)
        {
            _roomIndex = index;
            _alive = 0;
            Boss = null;
            var room = Room.Build(_run[index], InBossRoom ? "Boss" : (index + 1).ToString());

            if (Hero == null) Hero = Hero.Spawn(room.PlayerStart);
            Hero.PlaceAt(room.PlayerStart);
            CameraRig.target = Hero.transform;
            CameraRig.SetRoom(Room.HalfWidth, Room.HalfLength);
            CameraRig.Snap();

            if (!spawnEnemies) return;

            Hud.SetRoom(index + 1, CombatRoomCount, InBossRoom);
            Hud.ShowBanner(InBossRoom ? "The Throne Room" : $"Room {index + 1}");
            foreach (var s in room.Spawns) SpawnEnemy(s.kind, s.position);
            SetState(GameState.Playing);
            if (_alive == 0) room.OpenDoor();
        }

        public Enemy SpawnEnemy(char kind, Vector3 position)
        {
            var e = Enemy.Spawn(kind, position);
            if (Room.Current != null) e.transform.SetParent(Room.Current.transform, true);
            _alive++;
            if (e is SkeletonKing king) Boss = king;
            return e;
        }

        public void OnEnemyDied(Enemy e)
        {
            _alive = Mathf.Max(0, _alive - 1);
            _kills++;
            if (State != GameState.Playing) return;

            if (e is SkeletonKing)
            {
                // Any minions left crumble with their king.
                foreach (var a in new List<Actor>(Actor.All))
                    if (a != e && a.team == Team.Undead && !a.IsDead) a.TakeDamage(9999f, Vector3.zero, 0f);
                StartCoroutine(Win());
            }
            else if (_alive == 0 && !InBossRoom)
            {
                StartCoroutine(RoomCleared());
            }
        }

        IEnumerator RoomCleared()
        {
            Hud.ShowBanner("Room Cleared");
            yield return new WaitForSeconds(0.9f);
            if (State != GameState.Playing) yield break;

            var choices = Upgrade.RollChoices(_taken);
            if (choices.Count == 0) { Room.Current.OpenDoor(); yield break; }

            SetState(GameState.Upgrade);
            Time.timeScale = 0f;
            Hud.ShowUpgrades(choices, i =>
            {
                var u = choices[i];
                _taken.TryGetValue(u.id, out int n);
                _taken[u.id] = n + 1;
                u.apply(Hero.stats, Hero);
                Sfx.Play(Sound.Upgrade);
                Fx.Magic(Hero.Center, u.color, 30);
                Time.timeScale = 1f;
                SetState(GameState.Playing);
                Room.Current.OpenDoor();
                Hud.ShowBanner(u.title, u.color);
            });
        }

        IEnumerator Win()
        {
            SetState(GameState.Victory);
            Hud.HideBoss();
            yield return new WaitForSecondsRealtime(1.2f);
            Sfx.Play(Sound.Victory);
            PlayerPrefs.SetInt(WinsKey, PlayerPrefs.GetInt(WinsKey, 0) + 1);
            SaveBest(_run.Count);
            Hud.ShowEnd(true, true, $"The Skeleton King has fallen.\n\nTime  {FormatTime(_runTime)}\nSkeletons destroyed  {_kills}");
            _stateTime = 0f;
        }

        public void OnHeroDied()
        {
            if (State == GameState.Dead) return;
            SetState(GameState.Dead);
            StartCoroutine(Lose());
        }

        IEnumerator Lose()
        {
            yield return new WaitForSecondsRealtime(1.4f);
            SaveBest(_roomIndex + 1);
            string where = InBossRoom ? "the throne room" : $"room {_roomIndex + 1} of {CombatRoomCount}";
            Hud.ShowEnd(true, false, $"You fell in {where}.\n\nTime  {FormatTime(_runTime)}\nSkeletons destroyed  {_kills}");
            _stateTime = 0f;
        }

        void Pause()
        {
            _stateBeforePause = State;
            SetState(GameState.Paused);
            Time.timeScale = 0f;
            Hud.ShowPause(true);
        }

        void Resume()
        {
            Hud.ShowPause(false);
            Time.timeScale = 1f;
            SetState(_stateBeforePause);
        }

        void SetState(GameState s)
        {
            State = s;
            _stateTime = 0f;
            if (s != GameState.Upgrade && s != GameState.Paused) Time.timeScale = 1f;
        }

        IEnumerator Fade(float from, float to, float seconds)
        {
            float t = 0f;
            while (t < seconds)
            {
                t += Time.unscaledDeltaTime;
                Hud.SetFade(Mathf.Lerp(from, to, t / seconds));
                yield return null;
            }
            Hud.SetFade(to);
        }

        // ------------------------------------------------------------------ saving

        void SaveBest(int roomReached)
        {
            if (roomReached > PlayerPrefs.GetInt(BestRoomKey, 0)) PlayerPrefs.SetInt(BestRoomKey, roomReached);
            PlayerPrefs.Save();
        }

        string BestText()
        {
            int wins = PlayerPrefs.GetInt(WinsKey, 0);
            int best = PlayerPrefs.GetInt(BestRoomKey, 0);
            if (wins > 0) return $"Kings defeated: {wins}";
            if (best > 0) return $"Deepest room reached: {best}";
            return "";
        }

        static string FormatTime(float seconds) => $"{(int)seconds / 60}:{(int)seconds % 60:00}";
    }

    /// <summary>Starts the game automatically in whatever scene you press Play in.</summary>
    static class GameBootstrap
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            if (GameManager.Instance == null) new GameObject("Game").AddComponent<GameManager>();
        }
    }
}
