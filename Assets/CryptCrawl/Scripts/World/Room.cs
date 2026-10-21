using System.Collections.Generic;
using UnityEngine;

namespace CryptCrawl
{
    /// <summary>
    /// Builds one crypt room from a text layout (see RoomLayouts) and answers the
    /// "can I stand here?" questions for movement and arrows. Collision is simple
    /// circles and a rectangle, which is fast and predictable on phones.
    /// </summary>
    public class Room : MonoBehaviour
    {
        public static Room Current { get; private set; }

        public const float Cell = 4f / 3f;
        public const float HalfWidth = RoomLayouts.Columns * Cell * 0.5f;   // 6
        public const float HalfLength = RoomLayouts.Rows * Cell * 0.5f;     // 10
        const float WallHeight = 2.6f;
        const float DoorHalfWidth = 1.2f;

        public struct Obstacle
        {
            public Vector3 position;
            public float radius;
        }

        public struct Spawn
        {
            public char kind;
            public Vector3 position;
        }

        public readonly List<Obstacle> Obstacles = new List<Obstacle>();
        public readonly List<Spawn> Spawns = new List<Spawn>();
        public Vector3 PlayerStart => new Vector3(0f, 0f, -HalfLength + 1.4f);
        public bool DoorOpen { get; private set; }

        Transform _portcullis;
        Light _exitLight;
        GameObject _exitGlow;
        readonly List<Renderer> _placeholderWalls = new List<Renderer>();

        // ------------------------------------------------------------------ building

        public static Room Build(string[] layout, string name)
        {
            if (Current != null) Destroy(Current.gameObject);
            var go = new GameObject("Room - " + name);
            var room = go.AddComponent<Room>();
            Current = room;
            room.BuildShell();
            room.ReadLayout(layout);
            return room;
        }

        public static Vector3 CellToWorld(int col, int row)
        {
            float x = (col - (RoomLayouts.Columns - 1) * 0.5f) * Cell;
            float z = ((RoomLayouts.Rows - 1) * 0.5f - row) * Cell;
            return new Vector3(x, 0f, z);
        }

        GameObject Block(string name, Vector3 center, Vector3 size, Material mat, Transform parent = null)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent != null ? parent : transform, false);
            go.transform.localPosition = center;
            go.transform.localScale = size;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            return go;
        }

        GameObject Cylinder(string name, Vector3 baseCenter, float radius, float height, Material mat, Transform parent = null)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            go.name = name;
            Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent != null ? parent : transform, false);
            go.transform.localPosition = baseCenter + Vector3.up * height * 0.5f;
            go.transform.localScale = new Vector3(radius * 2f, height * 0.5f, radius * 2f);
            go.GetComponent<Renderer>().sharedMaterial = mat;
            return go;
        }

        void BuildShell()
        {
            var wallMat = MaterialLibrary.Lit(new Color(0.23f, 0.21f, 0.27f), 0.1f);
            var trimMat = MaterialLibrary.Lit(new Color(0.36f, 0.33f, 0.4f), 0.2f);
            var voidMat = MaterialLibrary.Lit(new Color(0.03f, 0.03f, 0.05f), 0f);

            // Floor: a textured slab, with a dark surround so the room edges read clearly.
            var floor = Block("Floor", new Vector3(0, -0.1f, 0), new Vector3(HalfWidth * 2f, 0.2f, HalfLength * 2f), MaterialLibrary.Floor(new Vector2(3f, 5f)));
            floor.GetComponent<Renderer>().receiveShadows = true;
            Block("Surround", new Vector3(0, -0.3f, 0), new Vector3(60f, 0.2f, 80f), voidMat);

            // Walls: west, east, south, and the north wall in two halves around the door.
            float t = 1f;
            AddWall(Block("Wall W", new Vector3(-HalfWidth - t * 0.5f, WallHeight * 0.5f, 0), new Vector3(t, WallHeight, HalfLength * 2f + t * 2f), wallMat));
            AddWall(Block("Wall E", new Vector3(HalfWidth + t * 0.5f, WallHeight * 0.5f, 0), new Vector3(t, WallHeight, HalfLength * 2f + t * 2f), wallMat));
            AddWall(Block("Wall S", new Vector3(0, WallHeight * 0.5f, -HalfLength - t * 0.5f), new Vector3(HalfWidth * 2f, WallHeight, t), wallMat));
            float side = HalfWidth - DoorHalfWidth;
            AddWall(Block("Wall N-L", new Vector3(-DoorHalfWidth - side * 0.5f, WallHeight * 0.5f, HalfLength + t * 0.5f), new Vector3(side, WallHeight, t), wallMat));
            AddWall(Block("Wall N-R", new Vector3(DoorHalfWidth + side * 0.5f, WallHeight * 0.5f, HalfLength + t * 0.5f), new Vector3(side, WallHeight, t), wallMat));

            // Trim along the top of the side walls.
            Block("Trim W", new Vector3(-HalfWidth - 0.5f, WallHeight + 0.08f, 0), new Vector3(1.2f, 0.16f, HalfLength * 2f + 2f), trimMat);
            Block("Trim E", new Vector3(HalfWidth + 0.5f, WallHeight + 0.08f, 0), new Vector3(1.2f, 0.16f, HalfLength * 2f + 2f), trimMat);

            BuildDoor(trimMat, voidMat);
            BuildKayKitShell();

            // Torches along the side walls light the room in warm pools.
            foreach (float z in new[] { -6f, 0f, 6f })
            {
                AddTorch(new Vector3(-HalfWidth + 0.05f, 1.7f, z), Quaternion.Euler(0, 90, 0));
                AddTorch(new Vector3(HalfWidth - 0.05f, 1.7f, z), Quaternion.Euler(0, -90, 0));
            }
        }

        void AddWall(GameObject wall) => _placeholderWalls.Add(wall.GetComponent<Renderer>());

        void BuildDoor(Material trim, Material dark)
        {
            var door = new GameObject("Door").transform;
            door.SetParent(transform, false);
            door.localPosition = new Vector3(0, 0, HalfLength);

            Block("Arch L", new Vector3(-DoorHalfWidth - 0.2f, 1.6f, 0.4f), new Vector3(0.5f, 3.2f, 1.3f), trim, door);
            Block("Arch R", new Vector3(DoorHalfWidth + 0.2f, 1.6f, 0.4f), new Vector3(0.5f, 3.2f, 1.3f), trim, door);
            Block("Arch Top", new Vector3(0, 3.2f, 0.4f), new Vector3(DoorHalfWidth * 2f + 0.9f, 0.5f, 1.3f), trim, door);
            Block("Tunnel", new Vector3(0, 1.4f, 2.2f), new Vector3(DoorHalfWidth * 2f, 2.8f, 0.2f), dark, door);

            _exitGlow = Block("Exit Glow", new Vector3(0, 1.4f, 2.0f), new Vector3(DoorHalfWidth * 2f, 2.8f, 0.05f),
                MaterialLibrary.Lit(new Color(0.2f, 0.4f, 1f), 0f, 1.5f), door);
            _exitGlow.SetActive(false);

            _portcullis = new GameObject("Portcullis").transform;
            _portcullis.SetParent(door, false);
            _portcullis.localPosition = new Vector3(0, 0, 0.1f);
            var iron = MaterialLibrary.Lit(new Color(0.18f, 0.18f, 0.2f), 0.6f);
            for (int i = 0; i < 6; i++)
            {
                float x = Mathf.Lerp(-DoorHalfWidth + 0.15f, DoorHalfWidth - 0.15f, i / 5f);
                Block("Bar", new Vector3(x, 1.45f, 0), new Vector3(0.1f, 2.9f, 0.1f), iron, _portcullis);
            }
            Block("Crossbar", new Vector3(0, 1.0f, 0), new Vector3(DoorHalfWidth * 2f, 0.1f, 0.12f), iron, _portcullis);
            Block("Crossbar", new Vector3(0, 2.1f, 0), new Vector3(DoorHalfWidth * 2f, 0.1f, 0.12f), iron, _portcullis);

            var lightGo = new GameObject("Exit Light");
            lightGo.transform.SetParent(door, false);
            lightGo.transform.localPosition = new Vector3(0, 1.5f, -0.8f);
            _exitLight = lightGo.AddComponent<Light>();
            _exitLight.type = LightType.Point;
            _exitLight.color = new Color(0.4f, 0.6f, 1f);
            _exitLight.range = 6f;
            _exitLight.intensity = 0f;
        }

        void AddTorch(Vector3 pos, Quaternion rot)
        {
            var root = new GameObject("Torch").transform;
            root.SetParent(transform, false);
            root.localPosition = pos;
            root.localRotation = rot;

            var prefab = ArtLibrary.Get(ArtKeys.Torch);
            if (prefab != null) PlaceProp(prefab, root, 0.9f);
            else
            {
                Block("Bracket", new Vector3(0, -0.15f, 0.15f), new Vector3(0.12f, 0.12f, 0.3f), MaterialLibrary.Lit(new Color(0.2f, 0.18f, 0.16f), 0.4f), root);
                Block("Stick", new Vector3(0, 0f, 0.25f), new Vector3(0.1f, 0.4f, 0.1f), MaterialLibrary.Lit(new Color(0.35f, 0.22f, 0.12f)), root);
                var flame = GameObject.CreatePrimitive(PrimitiveType.Sphere);
                Destroy(flame.GetComponent<Collider>());
                flame.transform.SetParent(root, false);
                flame.transform.localPosition = new Vector3(0, 0.28f, 0.25f);
                flame.transform.localScale = new Vector3(0.2f, 0.3f, 0.2f);
                flame.GetComponent<Renderer>().sharedMaterial = MaterialLibrary.Lit(new Color(1f, 0.6f, 0.2f), 0f, 3f);
                flame.GetComponent<Renderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            }

            var lightGo = new GameObject("Torch Light");
            lightGo.transform.SetParent(root, false);
            lightGo.transform.localPosition = new Vector3(0, 0.4f, 0.8f);
            var light = lightGo.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = new Color(1f, 0.62f, 0.3f);
            light.range = 6.5f;
            light.intensity = 1.6f;
            light.shadows = LightShadows.None;
            lightGo.AddComponent<Flicker>();
        }

        /// <summary>When the KayKit dungeon pack is linked, dress the room with its floor tiles and walls.</summary>
        void BuildKayKitShell()
        {
            var floorPrefab = ArtLibrary.Get(ArtKeys.Floor);
            if (floorPrefab != null)
            {
                var size = MeasureFootprint(floorPrefab);
                if (size.x > 0.1f && size.y > 0.1f)
                {
                    int nx = Mathf.Max(1, Mathf.RoundToInt(HalfWidth * 2f / size.x));
                    int nz = Mathf.Max(1, Mathf.RoundToInt(HalfLength * 2f / size.y));
                    float sx = HalfWidth * 2f / (nx * size.x), sz = HalfLength * 2f / (nz * size.y);
                    for (int x = 0; x < nx; x++)
                    for (int z = 0; z < nz; z++)
                    {
                        var tile = Instantiate(floorPrefab, transform);
                        tile.transform.localPosition = new Vector3(-HalfWidth + (x + 0.5f) * size.x * sx, 0.005f, -HalfLength + (z + 0.5f) * size.y * sz);
                        tile.transform.localScale = Vector3.Scale(tile.transform.localScale, new Vector3(sx, 1f, sz));
                        StripColliders(tile);
                    }
                }
            }

            var wallPrefab = ArtLibrary.Get(ArtKeys.Wall);
            if (wallPrefab != null)
            {
                foreach (var r in _placeholderWalls) r.enabled = false;
                WallRun(wallPrefab, new Vector3(-HalfWidth, 0, -HalfLength), new Vector3(-HalfWidth, 0, HalfLength));
                WallRun(wallPrefab, new Vector3(HalfWidth, 0, HalfLength), new Vector3(HalfWidth, 0, -HalfLength));
                WallRun(wallPrefab, new Vector3(HalfWidth, 0, -HalfLength), new Vector3(-HalfWidth, 0, -HalfLength));
                WallRun(wallPrefab, new Vector3(-HalfWidth, 0, HalfLength), new Vector3(-DoorHalfWidth - 0.4f, 0, HalfLength));
                WallRun(wallPrefab, new Vector3(DoorHalfWidth + 0.4f, 0, HalfLength), new Vector3(HalfWidth, 0, HalfLength));
            }
        }

        void WallRun(GameObject prefab, Vector3 from, Vector3 to)
        {
            float length = MeasureFootprint(prefab).x;
            if (length < 0.1f) return;
            float span = Vector3.Distance(from, to);
            int count = Mathf.Max(1, Mathf.RoundToInt(span / length));
            float stretch = span / (count * length);
            var dir = (to - from).normalized;
            // Yaw the piece so its local X runs along the wall. The room interior is then on its local -Z side;
            // tick "Flip Walls" on the ArtLibrary asset if the decorated face points the wrong way.
            float yaw = Mathf.Atan2(-dir.z, dir.x) * Mathf.Rad2Deg;
            var lib = ArtLibrary.Instance;
            if (lib != null && lib.flipWalls) yaw += 180f;
            var rot = Quaternion.Euler(0f, yaw, 0f);
            for (int i = 0; i < count; i++)
            {
                var w = Instantiate(prefab, transform);
                w.transform.localPosition = from + dir * (i + 0.5f) * length * stretch;
                w.transform.localRotation = rot;
                w.transform.localScale = Vector3.Scale(w.transform.localScale, new Vector3(stretch, 1f, 1f));
                StripColliders(w);
            }
        }

        static Vector2 MeasureFootprint(GameObject prefab)
        {
            var probe = Instantiate(prefab);
            probe.transform.position = Vector3.zero;
            probe.transform.rotation = Quaternion.identity;
            var rs = probe.GetComponentsInChildren<Renderer>();
            Vector2 size = Vector2.zero;
            if (rs.Length > 0)
            {
                var b = rs[0].bounds;
                foreach (var r in rs) b.Encapsulate(r.bounds);
                size = new Vector2(b.size.x, b.size.z);
            }
            DestroyImmediate(probe);
            return size;
        }

        static void StripColliders(GameObject go)
        {
            foreach (var c in go.GetComponentsInChildren<Collider>()) Destroy(c);
        }

        /// <summary>Instantiate a KayKit prop under a parent and scale it to a target height.</summary>
        static GameObject PlaceProp(GameObject prefab, Transform parent, float height)
        {
            var go = Instantiate(prefab, parent);
            go.transform.localPosition = Vector3.zero;
            go.transform.localRotation = Quaternion.identity;
            var rs = go.GetComponentsInChildren<Renderer>();
            if (rs.Length > 0)
            {
                var b = rs[0].bounds;
                foreach (var r in rs) b.Encapsulate(r.bounds);
                if (b.size.y > 0.01f) go.transform.localScale *= height / b.size.y;
            }
            StripColliders(go);
            return go;
        }

        void ReadLayout(string[] layout)
        {
            var stone = MaterialLibrary.Lit(new Color(0.42f, 0.4f, 0.46f), 0.15f);
            var wood = MaterialLibrary.Lit(new Color(0.45f, 0.28f, 0.15f), 0.1f);
            var iron = MaterialLibrary.Lit(new Color(0.2f, 0.2f, 0.22f), 0.5f);

            for (int row = 0; row < RoomLayouts.Rows && row < layout.Length; row++)
            {
                string line = layout[row];
                for (int col = 0; col < RoomLayouts.Columns && col < line.Length; col++)
                {
                    char ch = line[col];
                    var p = CellToWorld(col, row);
                    switch (ch)
                    {
                        case '#':
                            AddObstacle(p, 0.6f);
                            var pillar = ArtLibrary.Get(ArtKeys.Pillar);
                            if (pillar != null) { var pr = new GameObject("Pillar").transform; pr.SetParent(transform, false); pr.localPosition = p; PlaceProp(pillar, pr, WallHeight + 0.4f); }
                            else
                            {
                                Block("Pillar Base", p + Vector3.up * 0.15f, new Vector3(1.2f, 0.3f, 1.2f), stone);
                                Cylinder("Pillar", p, 0.45f, WallHeight + 0.4f, stone);
                                Block("Pillar Cap", p + Vector3.up * (WallHeight + 0.4f), new Vector3(1.1f, 0.25f, 1.1f), stone);
                            }
                            break;
                        case 'b':
                            AddObstacle(p, 0.45f);
                            var barrel = ArtLibrary.Get(ArtKeys.Barrel);
                            if (barrel != null) { var br = new GameObject("Barrel").transform; br.SetParent(transform, false); br.localPosition = p; br.localRotation = Quaternion.Euler(0, Random.Range(0, 360f), 0); PlaceProp(barrel, br, 1.0f); }
                            else
                            {
                                Cylinder("Barrel", p, 0.4f, 0.95f, wood);
                                Cylinder("Band", p + Vector3.up * 0.2f, 0.42f, 0.06f, iron);
                                Cylinder("Band", p + Vector3.up * 0.7f, 0.42f, 0.06f, iron);
                            }
                            break;
                        case 'c':
                            AddObstacle(p, 0.6f);
                            var crates = ArtLibrary.Get(ArtKeys.Crates);
                            if (crates != null) { var cr = new GameObject("Crates").transform; cr.SetParent(transform, false); cr.localPosition = p; PlaceProp(crates, cr, 1.4f); }
                            else
                            {
                                var a = Block("Crate", p + Vector3.up * 0.45f, Vector3.one * 0.9f, wood);
                                a.transform.localRotation = Quaternion.Euler(0, Random.Range(-15f, 15f), 0);
                                var b = Block("Crate", p + new Vector3(0.1f, 1.15f, 0.05f), Vector3.one * 0.55f, wood);
                                b.transform.localRotation = Quaternion.Euler(0, Random.Range(20f, 50f), 0);
                            }
                            break;
                        case 'm': case 'w': case 'a': case 'g': case 'K':
                            Spawns.Add(new Spawn { kind = ch, position = p });
                            break;
                    }
                }
            }
        }

        void AddObstacle(Vector3 p, float r) => Obstacles.Add(new Obstacle { position = p, radius = r });

        // ------------------------------------------------------------------ queries

        /// <summary>Moves a circle of the given radius by delta, sliding along walls and around obstacles.</summary>
        public Vector3 ResolveMove(Vector3 position, Vector3 delta, float radius)
        {
            var p = position + delta;
            p.y = 0f;

            // While the door is open the hero may walk into the doorway.
            float maxZ = HalfLength - radius;
            if (DoorOpen && Mathf.Abs(p.x) < DoorHalfWidth - radius * 0.5f) maxZ = HalfLength + 1.2f;

            p.x = Mathf.Clamp(p.x, -HalfWidth + radius, HalfWidth - radius);
            p.z = Mathf.Clamp(p.z, -HalfLength + radius, maxZ);
            if (p.z > HalfLength - radius) p.x = Mathf.Clamp(p.x, -DoorHalfWidth + radius, DoorHalfWidth - radius);

            foreach (var o in Obstacles)
            {
                var d = p - o.position;
                d.y = 0f;
                float min = o.radius + radius;
                float sq = d.sqrMagnitude;
                if (sq < min * min)
                {
                    float len = Mathf.Sqrt(sq);
                    p = len > 0.0001f ? o.position + d / len * min : o.position + Vector3.right * min;
                    p.y = 0f;
                }
            }
            return p;
        }

        public bool BlocksProjectile(Vector3 p, float radius)
        {
            if (Mathf.Abs(p.x) > HalfWidth - radius || Mathf.Abs(p.z) > HalfLength - radius) return true;
            foreach (var o in Obstacles)
            {
                var d = p - o.position;
                d.y = 0f;
                if (d.sqrMagnitude < (o.radius + radius) * (o.radius + radius)) return true;
            }
            return false;
        }

        public bool IsInside(Vector3 p, float radius) =>
            Mathf.Abs(p.x) <= HalfWidth - radius && Mathf.Abs(p.z) <= HalfLength - radius && !BlocksProjectile(p, radius);

        public bool IsAtExit(Vector3 p) => DoorOpen && p.z > HalfLength - 0.2f;

        public void OpenDoor()
        {
            if (DoorOpen) return;
            DoorOpen = true;
            Sfx.Play(Sound.DoorOpen);
            Juice.Shake(0.15f);
            Fx.Dust(new Vector3(0, 0, HalfLength), 30);
            _exitGlow.SetActive(true);
            StartCoroutine(RaisePortcullis());
        }

        System.Collections.IEnumerator RaisePortcullis()
        {
            float t = 0f;
            while (t < 1f)
            {
                t += Time.deltaTime * 1.2f;
                _portcullis.localPosition = new Vector3(0, Mathf.SmoothStep(0, 2.9f, t), 0.1f);
                _exitLight.intensity = Mathf.Lerp(0f, 2.5f, t);
                yield return null;
            }
        }
    }

    /// <summary>Makes a light flicker like a flame.</summary>
    public class Flicker : MonoBehaviour
    {
        Light _light;
        float _base, _seed;

        void Awake()
        {
            _light = GetComponent<Light>();
            _base = _light.intensity;
            _seed = Random.value * 100f;
        }

        void Update()
        {
            float n = Mathf.PerlinNoise(_seed, Time.time * 6f);
            _light.intensity = _base * (0.75f + n * 0.5f);
        }
    }
}
