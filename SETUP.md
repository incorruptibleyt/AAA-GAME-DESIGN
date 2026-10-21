# Setup (phone only)

You don't need a computer, a licence or any accounts besides GitHub.

## 1. Install the game

1. On your Android phone, open
   **https://github.com/incorruptibleyt/AAA-GAME-DESIGN/releases/tag/latest-build**
   (sign in to GitHub if it asks).
2. Under **Assets**, tap **crypt-crawl.apk** to download it.
3. Open the download. Android will say it can't install apps from this source: tap **Settings**,
   turn on **Allow from this source**, go back and tap **Install**.
4. If Play Protect warns you, tap **More details → Install anyway**. It warns because the app isn't from the
   Play Store, not because something is wrong.

Every time a change is pushed, GitHub builds a fresh app (about 5–10 minutes) and replaces the file
on that page. Download and install it the same way; it updates over the old one and keeps your best run.

To check on a build, open the repo's **Actions** tab. A green tick means the new app is ready.

## 2. How to play

- **Drag** anywhere on the screen to move. The joystick appears under your thumb.
- **Let go** to stand still, and the hero shoots the nearest skeleton automatically.
- **Red shapes on the floor** are warnings. Step out of them!
- After clearing a room, **pick one of three blessings**, then walk through the open door at the top.
- Beat the Skeleton King in room 6 to win.

## 3. Adding the real art (optional)

The game ships with simple shapes. To use KayKit's models:

1. On your phone, go to **https://kaylousberg.itch.io** and download (free, "No thanks, just take me
   to the downloads") these packs: **KayKit Adventurers**, **KayKit Skeletons** and **KayKit Dungeon Remastered**.
2. In the GitHub app or website, open the repo's **ArtZips** folder → **Add file → Upload files**,
   and upload the zips. GitHub's website accepts files up to 25 MB each; if one is bigger, tell Claude.
3. The next build uses them automatically.

## 4. Changing the game yourself (optional)

Ask Claude in the project chat. Or, if you're curious, install the free **Godot Editor** app from the
Play Store, download this repo as a zip, and open `project.godot` in it.
