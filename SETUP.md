# Crypt Crawl: setup guide

This guide gets the game running on your computer and then on your phone. You don't need
any coding or Unity experience. Each step says exactly what to click.

The game already works before you download any art. It uses simple placeholder shapes,
and step 4 swaps in the real KayKit models.

---

## 1. Install Unity (about 30 minutes, mostly waiting)

1. Download **Unity Hub** from <https://unity.com/download> and install it.
2. Open Unity Hub and sign in (a free Unity account is fine; choose the **Personal** license if asked).
3. Go to **Installs → Install Editor** and pick the newest **Unity 6** version marked **LTS**.
4. When it asks for modules, tick:
   - **Android Build Support** (with *OpenJDK* and *Android SDK & NDK Tools* inside it), to play on an Android phone.
   - **iOS Build Support**, only if you have a Mac and an iPhone.
   - **Microsoft Visual Studio Community** (Windows) if offered. It's handy for reading the code later.
5. Click **Install** and wait.

## 2. Get the project onto your computer

The easiest way is **GitHub Desktop**:

1. Install it from <https://desktop.github.com> and sign in with your GitHub account.
2. **File → Clone repository**, pick `incorruptibleyt/AAA-GAME-DESIGN`, choose a folder, and click **Clone**.

(No GitHub Desktop? On the repository page click **Code → Download ZIP** and unzip it. That works too,
but then you can't easily pull future updates.)

## 3. Open it and press Play

1. In Unity Hub click **Add → Add project from disk** and choose the `AAA-GAME-DESIGN` folder.
2. Click the project to open it. If Hub says the version is different from the one you installed,
   choose your installed Unity 6 version and continue.
3. The first open takes a few minutes while Unity imports everything. If a box asks whether to
   enable the **new Input System backends**, click **Yes**. Unity will restart itself, and the game works either way.
4. In the menu bar at the top, click **Crypt Crawl → Play**.

**Make it look like a phone:** above the game picture there's a dropdown that says *Free Aspect*.
Change it to a portrait phone size (for example *1080x1920 Portrait*, or click **+** to add one).

**Controls on the computer:**
- Click and drag with the mouse, the same as a thumb on a phone. You can also use **WASD** or the arrow keys.
- Stop moving and your hero shoots the nearest skeleton automatically.
- Clear a room, pick one of three blessings, then walk through the glowing door at the top.
- Five rooms, then the Skeleton King.

Press the Play button again to stop.

## 4. Add the KayKit art (about 15 minutes)

All four packs are free and CC0, so you never need to credit anyone (though it's nice to).
On each page, click **Download Now**, then **No thanks, just take me to the downloads**, and download the free version.

| Pack | Link | What it gives you |
|---|---|---|
| Adventurers | <https://kaylousberg.itch.io/kaykit-adventurers> | The hero |
| Skeletons | <https://kaylousberg.itch.io/kaykit-skeletons> | All four skeleton enemies |
| Character Animations | <https://kaylousberg.itch.io/kaykit-character-animations> | Running, shooting, getting hit, dying |
| Dungeon Pack | <https://kaylousberg.itch.io/kaykit-dungeon-pack> | Floors, walls, pillars, barrels, torches |

Then:

1. Unzip each download.
2. In Unity's **Project** window (bottom of the screen), right-click **Assets → Create → Folder** and name it `KayKit`.
3. From each unzipped pack, find the folder of **.fbx** files (usually called `fbx` or `Assets/fbx`)
   and drag that folder into `Assets/KayKit`. Wait for the import bar to finish.
4. Click **Crypt Crawl → Link KayKit Assets**. A window lists which models it found.
5. Press **Crypt Crawl → Play** again. The hero, skeletons and dungeon now use the KayKit art.

If something looks wrong (for example walls showing their back side), click the
`Assets/CryptCrawl/Resources/CryptCrawl/ArtLibrary` file and tick **Flip Walls** in the Inspector on the right.
To go back to placeholders, use **Crypt Crawl → Unlink KayKit Assets**.

## 5. Play it on your phone

### Android

1. On the phone, turn on **Developer options**: Settings → About phone → tap **Build number** seven times.
2. In Developer options, turn on **USB debugging**, then plug the phone into your computer and allow it.
3. In Unity: **File → Build Profiles** (called *Build Settings* in older versions), click **Android**, then **Switch Platform**.
4. Click **Build And Run**, choose a place to save the `.apk`, and the game opens on your phone.

### iPhone

You need a Mac with **Xcode** installed. Switch the platform to **iOS** in Build Profiles, click **Build**,
open the folder it makes in Xcode, pick your phone, and press Run. Xcode will walk you through signing
in with your Apple ID the first time.

## 6. Easy things to change yourself

| What | Where |
|---|---|
| Room layouts (pillars, which skeletons, where) | `Assets/CryptCrawl/Scripts/World/RoomLayouts.cs` (rooms are drawn as letters) |
| The blessing cards | `Assets/CryptCrawl/Scripts/Player/Upgrades.cs` |
| Hero health, speed, damage | `HeroStats` at the top of `Upgrades.cs` |
| Skeleton health and speed | `Setup()` in `Assets/CryptCrawl/Scripts/Enemies/SkeletonTypes.cs` |
| Boss health and attacks | `Assets/CryptCrawl/Scripts/Enemies/SkeletonKing.cs` |

Double-click a script in Unity to open it, change a number, save, and press Play.

## Troubleshooting

- **Red errors in the Console when opening the project.** Take a screenshot of the first red line and
  send it to me in the project chat. I'll fix it.
- **The screen is black when I press Play.** Make sure you used **Crypt Crawl → Play** (it opens the right scene),
  and that the Game tab is showing.
- **"Link KayKit Assets" says nothing was found.** The `.fbx` files need to be somewhere inside the `Assets` folder.
  Zip files and `.gltf`-only folders won't be picked up.
- **Characters stand in a T-pose.** The Character Animations pack is missing or wasn't linked. Import it and run
  **Link KayKit Assets** again.
