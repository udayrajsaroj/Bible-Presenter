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
- **Screen Mirror** — App enters fullscreen landscape, cast phone screen to TV via Miracast
- **Browser Connect** — Open `http://<phone-ip>:3000/tv.html` on TV browser
- Floating controller overlay in fullscreen mode (Prev, Next, Cast, Blackout, Logo)
- Real-time WebSocket connection between phone and TV

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

1. **Phone** runs an embedded Shelf HTTP + WebSocket server on port 3000
2. **TV** opens `http://<phone-ip>:3000/tv.html` in its browser
3. Phone sends cast events (`cast-verse`, `cast-slide`, `cast-song`, `cast-pdf`, `cast-logo`, etc.)
4. TV renders content in real-time with animated backgrounds, transitions, and styling

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
git clone https://github.com/udayrajsaroj/BiblePresenter.git
cd BiblePresenter

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release --split-per-abi
```

### Setup
1. Install the app on your Android phone
2. Connect your phone and TV to the **same WiFi network**
3. Open the app — it automatically starts the server
4. On your TV browser, enter the URL shown at the bottom of the app
5. Start casting!

---

## 📁 Project Structure

```
lib/
├── main.dart          # Main Flutter app (controller UI)
├── server.dart        # Shelf HTTP + WebSocket server
└── tv_html.dart       # TV display HTML/CSS/JS page

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
| FILES     | Upload and cast PDF/PPT files              |
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
- TV must have a **web browser** (Smart TV, Fire TV Stick + browser, etc.)
- Phone IP address must be accessible from TV (no AP isolation)

---

## 📄 License

This project is licensed under the **MIT License**.

```
MIT License

Copyright (c) 2025 Udayraj

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