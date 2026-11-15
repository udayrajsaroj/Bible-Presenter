# DLNA "TV Direct" — Discovery Verification Notes (Phase D2)

How to verify SSDP discovery and slide casting **without owning a TV**,
per the implementation plan (Chapter 10.1). The release gate remains the
real-TV matrix in Chapter 10.2.

## Dev setup (no TV required)

1. **Browser TV (Channel A regression baseline).** Chrome at
   `http://<phone-ip>:3000/tv.html` on the same LAN as the phone.
2. **Kodi as the DLNA renderer (Channel B).** Install Kodi
   (Windows/macOS/Linux), then enable:
   `Settings → Services → UPnP/DLNA → "Allow remote control via UPnP"`.
   Kodi then advertises itself as a MediaRenderer (`urn:schemas-upnp-org:
   device:MediaRenderer:1`) and renders PNGs we push via SetAVTransportURI.
   Alternative virtual renderer: BubbleUPnP Server (it is a MediaServer +
   renderer combo; our picker keeps only MediaRenderer devices).
3. **Network.** Phone and laptop on one LAN segment. The phone's own
   hotspot is the most reliable isolated test network — office/guest
   networks often enable AP isolation, which silently blocks both SSDP
   replies and slide downloads (risk R7).

## Windows firewall watch-out

If the device list stays empty on Windows, the firewall is silently
dropping Kodi's **SSDP replies on UDP 1900**. Allow Kodi through the
firewall before debugging the app.

## Verification steps

| # | Step | Expected |
|---|------|----------|
| 1 | Launch app on Android device, open Cast dialog | Kodi appears in the picker within ~10 s with friendly name "Kodi (medialaptop)" |
| 2 | Tap Kodi, cast a verse | Kodi picture view shows the full-HD PNG (Hindi text + gold reference render correctly) |
| 3 | Tap next verse rapidly (3–4 taps) | Debounce holds; Kodi shows a coherent sequence, no queue pileup |
| 4 | Stop / clear-screen | Kodi returns to idle |
| 5 | Kill Kodi, cast again | Disconnect banner appears (renderer-offline); restart Kodi, Reconnect works |
| 6 | Second app session | Reconnect banner "Cast to Kodi (medialaptop) — tap to connect" (stored UDN via SharedPreferences) |

## Fixture-driven checks (automated)

`test/dlna_service_test.dart` validates the MediaRenderer filter against
`test/fixtures/dlna_devices.json` — realistic URNs from Kodi, Samsung
Tizen, LG webOS, Sony Bravia, an Android TV stick, plus two devices that
must be excluded (BubbleUPnP MediaServer, router InternetGatewayDevice).

Run: `flutter test test/dlna_service_test.dart`
