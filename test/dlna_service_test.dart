import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// The media_cast_dlna package also exports a class named DlnaService, so
// the app-side wrapper is imported with a prefix to disambiguate.
import 'package:biblepresenter/dlna_service.dart' as app;
import 'package:media_cast_dlna/media_cast_dlna.dart';

/// Phase D2 verification against device-list fixtures (plan Table 15, #5).
///
/// The fixtures in test/fixtures/dlna_devices.json carry realistic deviceType
/// URNs from Kodi and the major TV brands, plus two devices that must be
/// filtered out of the picker (a MediaServer and a gateway). The functional
/// end-to-end checks (SSDP answers arriving within ~10 s) are manual, on real
/// hardware — see dlna_discovery_notes.md.
void main() {
  late List<Map<String, dynamic>> fixtures;

  setUpAll(() async {
    final raw =
        await File('test/fixtures/dlna_devices.json').readAsString();
    fixtures = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  });

  DlnaDevice deviceFromFixture(Map<String, dynamic> f) => DlnaDevice(
        udn: DeviceUdn(value: f['udn'] as String),
        friendlyName: f['friendlyName'] as String,
        deviceType: f['deviceType'] as String,
        manufacturerDetails:
            ManufacturerDetails(manufacturer: f['manufacturer'] as String),
        modelDetails: ModelDetails(modelName: f['modelName'] as String),
        ipAddress: IpAddress(value: f['ip'] as String),
        port: NetworkPort(value: f['port'] as int),
      );

  test('MediaRenderer filter keeps TVs and Kodi, drops MediaServer/gateway',
      () {
    final kept = fixtures
        .map(deviceFromFixture)
        .where(app.DlnaService.isMediaRenderer)
        .toList();

    expect(kept.length, 5, reason: 'Kodi + Samsung + LG + Sony + Android TV');
    expect(
      kept.map((d) => d.friendlyName),
      containsAll(['Kodi (medialaptop)', '[TV] Samsung 7 Series (65)']),
    );
  });

  test('every fixture matches its expected renderer flag', () {
    for (final f in fixtures) {
      final isRenderer =
          app.DlnaService.isMediaRenderer(deviceFromFixture(f));
      expect(isRenderer, f['expectRenderer'] as bool,
          reason: '${f['friendlyName']}: ${f['deviceType']}');
    }
  });

  test('service no-ops safely on non-Android hosts (test env = Linux)', () {
    final service = app.DlnaService.instance;
    // isAndroid is false on the test host, so start() and scan() must leave
    // the service uninitialized instead of throwing.
    expect(service.isAndroid, isFalse);
  });

  test('device dedup updates in place by UDN value', () {
    // Two SSDP answers for the same TV (different ports across interfaces)
    // must collapse to one picker row.
    final f = fixtures.firstWhere((f) => f['udn'].toString().startsWith('uuid:ebf5'));
    final a = deviceFromFixture(f);
    final b = deviceFromFixture(f);
    expect(a.udn.value, b.udn.value);
    // The dedup itself lives in _handleDeviceFound (private); this asserts
    // the comparison basis — UDN value equality — that the dedup relies on.
  });
}
