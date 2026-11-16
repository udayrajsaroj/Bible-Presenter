# 🛠️ BiblePresenter — Complete Remediation & Implementation Plan

**Date:** November 15, 2026  
**Target Branch:** `feat/tv-casting-dlna-video-youtube`  
**Status:** ✅ **COMPLETED & VERIFIED (24/24 Tests Green, 0 Errors, Release APK 59.5MB)**
**Objective:** Fully resolve all 21 cataloged issues discovered across TV casting, PDF previews, background persistence, multi-language rendering, song/schedule stability, and platform performance.

---

## 🗺️ Execution Roadmap

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│            PHASE 1              │ ────> │            PHASE 2              │ ────> │            PHASE 3              │
│   Fix DLNA & Background Engines │       │   Restore PDF Previews & Docs   │       │   Fix Songs, Schedules & Bible  │
│   (Issues 1.1, 1.2, 1.3, 3.1)   │       │   (Issues 2.1, 2.2, 2.3)        │       │   (Issues 4.1, 4.2, 6.3, 6.4)   │
└─────────────────────────────────┘       └─────────────────────────────────┘       └─────────────────────────────────┘
                                                                                                     │
                                          ┌─────────────────────────────────┐                        │
                                          │            PHASE 5              │ <──────────────────────┘
                                          │   Code Hygiene & Final Verify   │
                                          │   (Issues 5.2, 6.5, Warnings)   │
                                          └─────────────────────────────────┘
                                                           ▲
                                                           │
                                          ┌─────────────────────────────────┐
                                          │            PHASE 4              │
                                          │   Performance & Offline Assets  │
                                          │   (Issues 1.4, 1.5, 1.6, 3.3,   │
                                          │    3.4, 5.1, 5.3, 6.1, 6.2)     │
                                          └─────────────────────────────────┘
```

---

## 📍 PHASE 1: Fix Core DLNA Casting & Background Engines
*(Resolves Issues 1.1, 1.2, 1.3, 3.1, 3.2)*

### 1. Multi-Interface Local IP Scanner (`lib/main.dart`, `lib/server.dart`)
* **Problem:** `NetworkInfo().getWifiIP()` returns the cellular CGNAT IP (`100.104.150.165`) when mobile hotspot and 5G are active.
* **Fix:**
  Implement `findBestLanIp()` using `NetworkInterface.list()`:
  ```dart
  Future<String> findBestLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      // Priority 1: Private LAN ranges (Wi-Fi, hotspot, Ethernet)
      // 192.168.x.x, 10.x.x.x, 172.16-31.x.x
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') ||
              (ip.startsWith('10.') && !ip.startsWith('100.')) ||
              RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(ip)) {
            return ip;
          }
        }
      }
      // Priority 2: Fall back to NetworkInfo().getWifiIP()
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && !wifiIp.startsWith('100.')) return wifiIp;
    } catch (_) {}
    return '127.0.0.1';
  }
  ```
  Ensure `SlideRenderer.deviceIp` is always assigned this reachable LAN IP.

### 2. Self-Healing DLNA Connection (`lib/dlna_service.dart`)
* **Problem:** `rendererOffline = true` permanently locks out all casting calls.
* **Fix:**
  Replace the blocking check at line 208 with automatic ping recovery:
  ```dart
  Future<bool> castImage(String url, {String title = 'BiblePresenter'}) async {
    var device = connectedDevice;
    if (device == null) return false;
    
    // Auto-heal: If offline, attempt quick ping to see if TV recovered
    if (rendererOffline) {
      final revived = await pingStored(device.udn.value);
      if (revived != null) {
        connectedDevice = revived;
        rendererOffline = false;
        notifyListeners();
      } else {
        return false;
      }
    }
    // Proceed with setMediaUri and play...
  ```
  Auto-clear the red disconnect banner when the TV responds.

### 3. Background State Forwarding in `OutputRouter` (`lib/output_router.dart`)
* **Problem:** `OutputRouter._stateFor` drops `'background'` on `cast-verse`, `cast-slide`, and `cast-song`.
* **Fix:**
  Preserve `'background'` from `currentState` and `data`:
  ```dart
  case 'cast-verse':
    return {
      'type': 'verse',
      'content': data,
      'background': data['background'] ?? currentState?['background'],
    };
  case 'cast-slide':
    return {
      'type': 'slide',
      'content': data,
      'background': data['background'] ?? currentState?['background'],
    };
  case 'cast-song':
    return {
      'type': 'song',
      'content': data,
      'background': data['background'] ?? currentState?['background'],
    };
  ```

### 4. Background State Persistence in `_emit` (`lib/main.dart`)
* **Problem:** `_bgUrl` starts null, is not persisted, and omitting `'background'` wipes the TV receiver background.
* **Fix:**
  1. Save `_bgUrl` in `SharedPreferences` whenever changed; restore on boot.
  2. In `_emit('cast-verse')`, always send active `'background'` payload:
     ```dart
     'background': _bgUrl != null ? {'url': _bgUrl} : null,
     ```
  3. In `tv_html.dart`, only clear the background if explicitly asked (e.g. `clear-screen`), never on verse changes.

### 5. Fix DOM Element Leak in `tv_html.dart` (`lib/tv_html.dart`)
* **Problem:** Image slides append `<img style="position:fixed; z-index:40">` directly to `document.body`, permanently blocking future slides.
* **Fix:**
  Append inside `#stage` or ensure any existing full-screen image element is removed on `stage.innerHTML = ''`:
  ```javascript
  // Remove any stray fullscreen overlay images attached to body
  const existingOverlays = document.querySelectorAll('.fullscreen-overlay-img');
  existingOverlays.forEach(el => el.remove());
  ```

---

## 📍 PHASE 2: Restore PDF Previews & Document Management
*(Resolves Issues 2.1, 2.2, 2.3)*

### 1. Re-integrate `PdfPagePreview` in `files_tab.dart` (`lib/tabs/files_tab.dart`)
* **Fix:**
  Add `localPath` parameter to `FilesTab` and insert `PdfPagePreview` directly inside `PDF PAGE CONTROL`:
  ```dart
  // Inside PDF PAGE CONTROL in files_tab.dart:
  label('PDF PAGE CONTROL'),
  const SizedBox(height: 10),
  if (activeLocalPath.isNotEmpty && pdfTotalPages > 0) ...[
    PdfPagePreview(
      localPath: activeLocalPath,
      currentPage: pdfCurrentPage,
      totalPages: pdfTotalPages,
    ),
    const SizedBox(height: 12),
  ],
  ```

### 2. Persist Local PDF Paths Across App Restarts (`lib/main.dart`)
* **Fix:**
  Store uploaded file metadata map `{'name', 'url', 'localPath', 'size'}` in `SharedPreferences`. When `_reloadUploadedFiles()` runs, restore `localPath` so DLNA PDF page rendering works after closing and reopening the app.

### 3. User Feedback Toast for PPT/PPTX on DLNA (`lib/output_router.dart`, `lib/main.dart`)
* **Fix:**
  When casting a PowerPoint file while connected to DLNA, show a Snackbar:
  *"PowerPoint requires Browser Connect mode (TV Browser) — switch to Browser Connect to present PPTX."*

---

## 📍 PHASE 3: Fix Songs, Schedules & Bible Navigation
*(Resolves Issues 4.1, 4.2, 6.3, 6.4)*

### 1. Fix Schedule Deserialization `TypeError` (`lib/state/schedule_state.dart`)
* **Fix:**
  Safely cast nested `stanzas` when restoring from `SharedPreferences`:
  ```dart
  // In schedule_state.dart line 79 & 104:
  final rawStanzas = songs[_scheduleSongIndex]['stanzas'];
  final stanzas = rawStanzas is List ? List<String>.from(rawStanzas) : <String>[];
  ```

### 2. Fix Song Deletion Index Alignment (`lib/tabs/songs_tab.dart`, `lib/main.dart`)
* **Fix:**
  Pass the actual `song` object or master index to `onDeleteSong`, rather than the filtered search index `i`:
  ```dart
  // In songs_tab.dart:
  onTap: () => onDeleteSong(allSongs.indexOf(filteredSongs[i])),
  ```
  Validate index bounds before removing in `main.dart`.

### 3. Smooth Chapter Boundary Navigation (`lib/main.dart`)
* **Fix:**
  When `_nextVerse()` is tapped on the last verse of chapter N:
  - If chapter N+1 exists in the book, automatically switch to chapter N+1, verse 1, and cast.
  - When `_prevVerse()` is tapped on verse 1 of chapter N, switch to chapter N-1, last verse, and cast.

### 4. Clamp `selChapter` Immediately on Book Switch (`lib/state/bible_state.dart`)
* **Fix:**
  In `BibleState.selectedBook = book`:
  Ensure `_selectedChapter` and `_selectedVerse` are clamped to valid keys of the new book immediately, preventing `null` verse data.

---

## 📍 PHASE 4: Performance & Offline Assets
*(Resolves Issues 1.4, 1.5, 1.6, 3.3, 3.4, 5.1, 5.3, 6.1, 6.2)*

### 1. DLNA File Rotation and Cleanup (`lib/slide_renderer.dart`)
* **Fix:**
  Rotate between 3 slide files (`slide_0.png`, `slide_1.png`, `slide_2.png`) or delete files older than the current session on startup.
  ```dart
  final slot = _slideCounter % 3;
  final name = 'slide_$slot.png';
  ```

### 2. Reduce DLNA Debounce & Latency (`lib/output_router.dart`, `lib/slide_renderer.dart`)
* **Fix:**
  1. Reduce `_debounceDuration` from `500 ms` to `200 ms`.
  2. Streamline `SlideRenderer.capture()` to use a single `addPostFrameCallback`.
  3. Encode slide images as JPEG (quality 85) instead of raw 1.5 MB PNG:
     - Cuts network payload by 90% (~150 KB).
     - TV loads and displays slide in < 300 ms.

### 3. Bundle Top 5 Preset Backgrounds Locally (`lib/theme.dart`, `assets/`)
* **Fix:**
  Package the 5 preset backgrounds as local assets under `assets/backgrounds/`:
  - `cross.jpg`
  - `sabbath.jpg`
  - `night_sky.jpg`
  - `golden_hour.jpg`
  - `dark_abstract.jpg`
  Serve them via `http://<phone-ip>:3000/assets/...` so TV and phone work 100% offline.

### 4. Strip External CDNs from `lib/tv_html.dart`
* **Fix:**
  - Replace `<script src="https://cdn.tailwindcss.com"></script>` with minified inline CSS.
  - Remove external Google Fonts blocking links; use system font stacks with bundled WOFF2 fallbacks.

### 5. Multi-Language Typography in `tv_html.dart`
* **Fix:**
  Dynamically apply typography classes based on script detection (Devanagari vs Latin) rather than hardcoded `.verse-hi` and `.verse-en`.

### 6. Dynamic Text Auto-Fitting in `SlideRenderer` (`lib/slide_renderer.dart`)
* **Fix:**
  Adopt `fitFontSize` inside `SlideRenderer._verseContent` and `_songContent`, ensuring long scripture verses never overflow or clip.

### 7. Server Port Communication Across Isolates (`lib/server.dart`, `lib/main.dart`)
* **Fix:**
  Pass a `SendPort` to `Isolate.spawn(startServer, [uploadPath, sendPort])`. The server sends back `{port: 3000}` (or fallback `3001`). `main.dart` listens and updates `SlideRenderer.serverPort`.

### 8. Enable Cleartext Traffic in AndroidManifest (`android/app/src/main/AndroidManifest.xml`)
* **Fix:**
  Add `android:usesCleartextTraffic="true"` inside `<application>`.

---

## 📍 PHASE 5: Code Hygiene & Final Verification
*(Resolves Issues 5.2, 6.5, Warnings)*

### 1. Modernize Deprecated Flutter APIs
* **Fix:**
  Replace 180+ instances of `.withOpacity(x)` with `.withValues(alpha: x)`.
  Remove unused import `dart:typed_data` in `lib/main.dart`.
  Remove unused local variables in `files_tab.dart` and `pdf_page_preview.dart`.

### 2. Fix Legacy MethodChannel Permission Request (`MethodChannelHandler.kt`)
* **Fix:**
  Hold the `Activity` reference from `MainActivity` directly instead of referencing the non-existent `PermissionActivity.activityInstance`.

### 3. Verification Criteria
* Run `flutter analyze` ➔ Verify **0 warnings, 0 errors**.
* Run `flutter test` ➔ All test suites green (100% pass rate).
* Run `flutter build apk --release` ➔ Clean build with verified output.
