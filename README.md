# 📖 BiblePresenter

**Cast Bible verses, slides, songs, PDFs, and PPTs to your TV — wirelessly from your phone.**

BiblePresenter turns your Android phone into a church presentation controller. It runs a built-in web server, and any TV with a browser can connect to display verses, slides, songs, and documents in beautiful full-screen layouts — no HDMI cables, no laptops, no expensive software needed.

---

## ✨ Features

### 📖 Bible Casting
- Full Bible loaded from JSON assets (English + Hindi)
- Book → Chapter → Verse selector
- Cast individual verses to TV with one tap
- Dual-language display (Hindi + English) on TV
- Prev/Next verse navigation

### 🎤 Slides
- Pre-built slides for Welcome, Prayer, Announcements, Offering
- Add custom slides with title + content
- Cast any slide to TV instantly
- Delete or reorder slides

### 🎵 Songs
- Built-in song library from `songs.json`
- Search songs by title or lyrics
- Add custom songs with multiple stanzas
- Stanza-by-stanza casting with dot indicators
- **Song Schedules** — create schedules for services, add songs, and present them in order

### 📂 Files (PDF / PPT)
- Upload PDF and PPT/PPTX files from phone
- PDF page-by-page navigation on TV
- PPT slides displayed on TV
- File list with size, type badges, and cast buttons

### 🖼️ Backgrounds
- 5 preset backgrounds (Glowing Cross, Night Sky, etc.)
- 5 animated CSS backgrounds (Aurora, Divine Light, Sunset, Ocean, Fire)
- Upload custom background images
- Backgrounds apply to all cast content (verses, slides, songs)

### ⛪ Church Logo
- Cast your church logo full-screen to TV
- Logo loaded from `assets/church_logo.png`
- One-tap logo button in the app bar

### 📺 TV Connection
- **TV Direct (DLNA)** — Cast to any Smart TV with **no app and no URL**: pick the TV from the Cast dialog, done. Two taps the first time, one tap afterwards via the reconnect banner
- **Browser Connect** — Open `http://<phone-ip>:3000/tv.html` on TV browser (lowest latency — best for fast verse-by-verse singing)
- **Screen Mirror** — App enters fullscreen landscape, cast phone screen to TV via Miracast
- Floating controller overlay in fullscreen mode (Prev, Next, Cast, Blackout, Logo)
- Real-time WebSocket connection between phone and TV

### 🎬 Local Video Casting
- Upload MP4 (H.264 recommended), WebM, MOV, MKV, AVI files
- Streaming upload straight to disk — 1–2 GB files never buffer in phone memory
- Phone-side remote: play/pause, seek slider, stop
- Over TV Direct the TV's **native player** takes over: hardware decoding, best quality, and the TV remote itself can pause and seek

### ▶️ YouTube Casting
- Paste any `youtube.com/watch?v=`, `youtu.be/` or `shorts/` link
- Fullscreen IFrame-API playback on the TV browser with a genuine phone remote (play/pause/seek/volume)
- Playlist queue with thumbnails that advances automatically on `ended`
- Requires internet on the TV; videos that disable embedding show a friendly error

### 🎛️ Settings
- Font size slider (24px–80px) for TV display
- Background selector with preview
- Server status monitor (WebSocket, IP, URL)
- Reconnect button

---

## 📸 How It Works

```
┌─────────────────┐         WebSocket          ┌─────────────────┐
│   Android Phone  │◄────────────────────────►│   TV Browser     │
│  (Controller App)│    http://IP:3000/tv.html │  (Display Only)  │
└─────────────────┘                            └─────────────────┘
```

### Channel A — Browser Connect
1. **Phone** runs an embedded Shelf HTTP + WebSocket server on port 3000
2. **TV** opens `http://<phone-ip>:3000/tv.html` in its browser
3. Phone sends cast events (`cast-verse`, `cast-slide`, `cast-song`, `cast-pdf`, `cast-video`, `cast-youtube`, etc.)
4. TV renders content in real-time with animated backgrounds, transitions, and styling

### Channel B — TV Direct (DLNA)
```
┌──────────────────┐  SSDP discovery (UDP 1900)  ┌──────────────────┐
│   Android Phone   │◄──────────────────────────►│   Smart TV        │
│  (Controller +    │  SetAVTransportURI + Play   │  (MediaRenderer)  │
│   Media Server)   │◄───────────────────────────►│                   │
└──────────────────┘   TV pulls content over HTTP  └──────────────────┘
```
1. The app discovers the TV's DLNA **MediaRenderer** over SSDP (10-second scan)
2. Cast commands go to the TV's AVTransport service (two plain HTTP/SOAP calls)
3. The TV **downloads** the actual content from the phone's server — a full-HD PNG per slide (DLNA cannot render HTML), or the video file itself
4. Both channels can run at the same time; YouTube only ever travels over Browser Connect (no direct stream URL exists for DLNA)

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x)
- Android Studio / VS Code
- Android device (for running the app)
- TV with a web browser (on the same WiFi network)

### Installation

```bash
# Clone the repository
git clone https://github.com/udayrajsaroj/Bible-Presenter.git
cd Bible-Presenter

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release --split-per-abi
```

### Setup — TV Direct (recommended)
1. Install the app on your Android phone
2. Connect phone and TV to the **same WiFi network** and make sure the TV is **turned on** (TVs in deep standby don't answer discovery)
3. Tap **Cast → TV Direct** and pick your TV from the list
4. Done — the current content is cast immediately. Next session, the banner *“Cast to <your TV> — tap to connect”* restores the connection in one tap

### Setup — Browser Connect
1. Connect phone and TV to the same WiFi network
2. Open the app — it automatically starts the server
3. On your TV browser, enter the URL shown at the bottom of the app
4. Start casting!

---

## 🔌 TV Direct: brand notes & troubleshooting

Where the DLNA renderer switch typically lives (menus shift between firmware versions):

| Brand | Renderer support | Watch-out |
|-------|------------------|-----------|
| Samsung (Tizen) | Built-in, usually always on | Check the connected-devices permission list if casting is refused |
| LG (webOS) | Built-in (SmartShare / Home Dashboard) | Verify the TV is on the same network profile |
| Sony (Bravia) | Built-in behind a dedicated toggle | `Settings → Network → Home Network Setup → Rendered via network: ON` — the classic miss |
| Panasonic | Built-in, on by default | The Media Player app opens when a photo is pushed |
| Android TV / Google TV | Weak or absent native renderer | Use Browser Connect instead |

**If the picker says “No TV found”:**
- Make sure the TV is on and on the **same Wi-Fi** as the phone
- Some office and guest networks block casting between devices (**AP isolation**) — try your phone's hotspot
- Give the scan its full ~10 seconds; the list fills in live

**Developer testing without a TV:** Kodi (free) on a laptop acts as a DLNA renderer — enable `Settings → Services → UPnP/DLNA → “Allow remote control via UPnP”`. On Windows, allow Kodi through the firewall or SSDP replies on UDP 1900 are silently dropped. See `test/dlna_discovery_notes.md` for the full recipe.

---

## 📁 Project Structure

```
lib/
├── main.dart          # Main Flutter app (controller UI)
├── server.dart        # Shelf HTTP + WebSocket server (streaming upload, Range, /dlna/)
├── tv_html.dart       # TV display HTML/CSS/JS page (slides + video + YouTube)
├── dlna_service.dart  # DLNA discovery + AVTransport control (media_cast_dlna)
├── slide_renderer.dart# Off-screen 1920×1080 PNG renderer for TV Direct
├── output_router.dart # Fan-out: Browser Connect + TV Direct from one state
├── tabs/              # Slides / Bible / Songs / Files / Settings tab UIs
├── widgets/           # Shared widgets, pickers, fullscreen screens
└── state/             # Provider stores (Bible, Songs, Schedules)

assets/
├── bible_en.json      # English Bible data
├── bible_hi.json      # Hindi Bible data
├── songs.json         # Song library
├── church_logo.png    # Church logo for casting
└── icon/
    └── app_icon.png   # App icon

android/
└── app/src/main/
    ├── AndroidManifest.xml
    └── res/xml/
        └── network_security_config.xml
```

---

## 🌐 Bible Languages (VerseVIEW Import)

The app ships with **English + Hindi** built in. Any number of extra languages
can be imported from the [VerseVIEW bible-database](https://www.verseview.com/bible-database)
(60+ translations in 40+ languages: Malayalam, Tamil, Telugu, Bengali, Kannada, …):

1. Download a bible file from the VerseVIEW database (Zefania `.xml`)
2. In the app: **Bible tab → Add Language → pick the file**
3. Choose it as **Primary** (big on TV) and optionally a **Secondary** language

The import runs on the phone (streaming XML parser, no PC step), the language
is stored in app documents and persists across restarts. VerseVIEW also offers
an app-format JSON, which imports the same way.

**Bulk converting on a PC** (optional): `scripts/zefania_to_app_json.py`
converts Zefania XML to the app JSON format:

```bash
python3 scripts/zefania_to_app_json.py "Malayalam Bible.xml" -o converted/
# see a working sample: download/bible_kjv_en.json (public-domain KJV)
```

> ⚠️ **Licensing**: the VerseVIEW database mixes public-domain translations
> (KJV, ASV, WEB, …) and copyright-restricted ones (NIV, ESV, …). Import and
> use in your ministry according to each version's own terms; do not
> redistribute converted copyrighted files.

---


## 🛠️ Tech Stack

| Component       | Technology                          |
|-----------------|-------------------------------------|
| Frontend        | Flutter (Dart)                      |
| Web Server      | Shelf (Dart) — embedded in app      |
| Real-time Comm  | WebSocket (dart:io)                 |
| TV Display      | HTML5 + CSS3 + Vanilla JS           |
| File Handling   | dart:io, file_picker                |
| Persistence     | SharedPreferences                   |
| Network Info    | network_info_plus                   |
| PDF/PPT View    | PDF.js (browser), PptxGenJS         |
| DLNA Casting    | media_cast_dlna (SSDP + AVTransport) |
| PDF→Image       | pdfx (phone-side page rendering)     |
| Video Upload    | HTTP streaming to disk (1–2 GB)      |

---

## 📡 WebSocket Events

| Event               | Description                        |
|---------------------|------------------------------------|
| `cast-verse`        | Cast a Bible verse to TV           |
| `cast-slide`        | Cast a slide to TV                 |
| `cast-song`         | Cast a song stanza to TV           |
| `cast-pdf`          | Cast a PDF document to TV          |
| `cast-pptx`         | Cast a PPT/PPTX to TV             |
| `cast-logo`         | Cast church logo full-screen       |
| `pdf-page`          | Change PDF page on TV              |
| `update-background` | Change TV background               |
| `clear-screen`      | Blackout / clear TV display        |
| `cast-video`        | Play a local video file on TV      |
| `video-control`     | Play / pause the TV video player   |
| `video-seek`        | Seek the TV video player           |
| `video-stop`        | Stop and clear the video           |
| `video-ended`       | TV → phone: playback finished      |
| `video-progress`    | TV → phone: position every ~1 s    |
| `cast-youtube`      | Play a YouTube video (Browser Connect only) |
| `yt-play` / `yt-pause` | Remote control the IFrame player |
| `yt-seek` / `yt-volume` | Seek / set volume (0–100)      |
| `yt-state` / `yt-error` | TV → phone: player state / embed error |

---

## 🎨 TV Display Features

- **Animated backgrounds**: Aurora, Divine Light, Sunset Glow, Ocean Deep, Fire Altar
- **Gradient overlays** for text readability
- **Smooth CSS transitions** between content changes
- **Dual-language** verse display (Hindi + English)
- **Song stanza dots** navigation indicator
- **PDF page rendering** with PDF.js
- **Full-screen logo** display for church branding

---

## 📱 App UI

The app has a 5-tab interface:

| Tab       | Purpose                                    |
|-----------|--------------------------------------------|
| SLIDES    | Manage and cast presentation slides        |
| BIBLE     | Browse and cast Bible verses               |
| SONGS     | Search, add, schedule, and cast songs      |
| FILES     | Upload and cast PDF/PPT/video files + YouTube |
| SETTINGS  | Font size, backgrounds, server status      |

---

## 🔧 Configuration

### Custom Church Logo
Replace `assets/church_logo.png` with your church logo. The logo is cast to TV in full-screen mode with a subtle glow effect.

### Custom Songs
Add songs to `assets/songs.json` in this format:
```json
[
  {
    "title": "Amazing Grace",
    "stanzas": [
      "Amazing grace, how sweet the sound\nThat saved a wretch like me",
      "Through many dangers, toils and snares\nI have already come"
    ]
  }
]
```

You can also add songs directly from the app — they are saved to SharedPreferences and persist across sessions.

### Bible Data
Replace `assets/bible_en.json` and `assets/bible_hi.json` with your preferred translation. Format:
```json
{
  "Genesis": {
    "1": {
      "1": "In the beginning God created the heaven and the earth.",
      "2": "And the earth was without form, and void..."
    }
  }
}
```

---

## ⚠️ Requirements

- Both phone and TV must be on the **same WiFi network**
- **TV Direct (DLNA):** Android only; the TV must be on and awake; MP4 (H.264/AAC) is the safe video codec — MKV/AVI often fail on TV players
- **Browser Connect:** TV must have a **web browser** (Smart TV, Fire TV Stick + browser, etc.); YouTube needs internet on the TV
- Phone IP address must be accessible from TV (no AP isolation)

---

## 📄 License

This project is licensed under the **MIT License**.

```
MIT License

Copyright (c) 2026 Udayraj

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

See the full license in the [LICENSE](LICENSE) file.

---

## 🙏 Acknowledgements

- Bible data sourced from open public domain translations
- Background images from [Unsplash](https://unsplash.com)
- Built with [Flutter](https://flutter.dev) and [Shelf](https://pub.dev/packages/shelf)
- PDF rendering powered by [PDF.js](https://mozilla.github.io/pdf.js/)

---

<p align="center">
  Made with ❤️ for churches everywhere
</p>