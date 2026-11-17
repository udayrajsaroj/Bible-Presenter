import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:shared_preferences/shared_preferences.dart';
import 'server.dart';
import 'theme.dart';
import 'dlna_service.dart';
import 'output_router.dart';
import 'slide_renderer.dart';
import 'widgets/dlna_picker_sheet.dart';
import 'tabs/slides_tab.dart';
import 'tabs/bible_tab.dart';
import 'tabs/songs_tab.dart';
import 'tabs/files_tab.dart';
import 'tabs/settings_tab.dart';
import 'widgets/shared_widgets.dart';
import 'widgets/section_fullscreen.dart';
import 'widgets/schedule_detail_page.dart';
import 'widgets/schedule_fullscreen.dart';
import 'services/cast_service.dart';
import 'services/bible_import.dart';
import 'screens/bible_presenter_screen.dart';
import 'screens/pdf_presenter_screen.dart';
import 'screens/song_presenter_screen.dart';
import 'services/song_docx.dart';
import 'widgets/song_slide_editor.dart';
import 'services/cast_api.g.dart';
import 'widgets/cast_button.dart';
import 'state/bible_state.dart';
import 'state/song_state.dart';
import 'state/schedule_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BiblePresenterApp());
}

class BiblePresenterApp extends StatelessWidget {
  const BiblePresenterApp({super.key});
  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BibleState()),
          ChangeNotifierProvider(create: (_) => SongState()),
          ChangeNotifierProvider(create: (_) => ScheduleState()),
        ],
        child: MaterialApp(
          title: 'BiblePresenter',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: kBg,
            colorScheme:
                const ColorScheme.dark(primary: kAccent, surface: kBg2),
          ),
          home: const ControllerPage(),
        ),
      );
}

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});
  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage>
    with TickerProviderStateMixin {
  // ── Server / WS state ──
  WebSocketChannel? _channel;
  bool _connected = false;
  bool _serverStarted = false;
  String _deviceIp = '...';
  Map<String, dynamic> _tvState = {'type': 'idle'};

  // ── Collapsible chrome (scroll-driven + Focus Mode) ──
  bool _chromeVisible = true;
  bool _focusMode = false;
  double _scrollHideAccum = 0;

  /// Mirror of _tvState for routes outside this widget's tree (the
  /// presenter screens listen to it so the LIVE pill stays current).
  final ValueNotifier<Map<String, dynamic>> tvStateN =
      ValueNotifier({'type': 'idle'});

  void _setTvState(Map<String, dynamic> s) {
    _tvState = s;
    tvStateN.value = s;
  }

  // ── WS reconnection ──
  Timer? _reconnectTimer;
  int _reconnectDelay = 2;
  static const int _maxReconnectDelay = 15;

  // ── Tab ──
  late TabController _tabController;

  // ── Slides state ──
  List<Map<String, String>> _slides = List.from(defaultSlides);
  int _activeSlide = 0;

  // ── Settings ──
  String? _bgUrl;
  final _addTitleCtrl = TextEditingController();
  final _addContentCtrl = TextEditingController();

  // ── Files state ──
  List<Map<String, dynamic>> _uploadedFiles = [];
  bool _isUploading = false;
  bool _importingBible = false;
  bool _importingSongWord = false;
  int _pdfCurrentPage = 1;
  int _pdfTotalPages = 0;
  int _activeFileIndex = -1;
  String _currentlyCastUrl = '';
  String _currentPdfLocalPath = '';

  // ── Video remote state (Feature 2) ──
  double _videoPosition = 0;
  double _videoDuration = 0;
  bool _videoPlaying = false;
  bool _videoMutedByBrowser = false;
  bool _videoFinished = false;

  // ── DLNA "TV Direct" state (Feature 1) ──
  final DlnaService _dlna = DlnaService.instance;
  // One-tap reconnect banner: the stored TV from the last session.
  String _reconnectName = '';
  String _reconnectUdn = '';

  // ── YouTube state (Feature 3) ──
  bool _ytPlaying = false;
  double _ytPosition = 0;
  double _ytDuration = 0;
  double _ytVolumeVal = 100;
  List<String> _ytQueue = [];
  int _ytQueueIndex = -1;
  final _ytUrlCtrl = TextEditingController();

  // ── Bible state ──

  // ── Uploaded backgrounds ──
  List<Map<String, String>> _uploadedBgs = [];
  bool _isUploadingBg = false;

  // ── Full-screen state (screen mirror) ──
  bool _isFullScreen = false;
  bool _showFullScreenControls = true;
  static const _screenCastChannel = MethodChannel('biblepresenter/screencast');

  // ── Welcome screen state ──
  String _welcomeMessage = '';
  final _welcomeMsgCtrl = TextEditingController();

  // ── Custom logo ──
  String _customLogoPath = '';

  // ── Cast Service (Chromecast & AirPlay via Pigeon) ──
  final CastService _castService = CastService();

  // ── Dialog state ──
  final _songTitleCtrl = TextEditingController();
  final _songSearchCtrl = TextEditingController();
  final _scheduleNameCtrl = TextEditingController();
  late List<TextEditingController> _songStanzaCtrls;
  late DateTime _scheduleDate;

  @override
  void initState() {
    super.initState();
    _songStanzaCtrls = [TextEditingController(), TextEditingController()];
    _scheduleDate = DateTime.now();
    _tabController = TabController(length: 5, vsync: this)
      ..addListener(() => setState(() {}));
    // Register the Pigeon Flutter API handler so native → Flutter callbacks work
    CastFlutterApi.setUp(_castService);
    _dlna.addListener(_onDlnaChanged);
    _boot();
  }

  void _onDlnaChanged() {
    if (mounted) setState(() {});
    // Renderer went offline (TV powered off, Wi-Fi drop) — tell the user.
    if (_dlna.rendererOffline) {
      _showSnack('TV disconnected — check Wi-Fi or Reconnect', error: true);
    }
  }

  // ══════════════════ NETWORK RESOLUTION ══════════════════
  static Future<String> findBestLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      bool isCellular(String name) {
        final lower = name.toLowerCase();
        return lower.startsWith('rmnet') ||
            lower.startsWith('ccmni') ||
            lower.startsWith('pdp') ||
            lower.startsWith('dummy');
      }

      bool isPrivateLan(String ip) {
        if (ip.startsWith('100.')) return false; // Reject CGNAT
        if (ip.startsWith('127.')) return false; // Reject loopback
        if (ip.startsWith('169.254.')) return false; // Reject link-local
        if (ip.startsWith('192.168.')) return true;
        if (ip.startsWith('10.')) return true;
        final m = RegExp(r'^172\.(\d+)\.').firstMatch(ip);
        if (m != null) {
          final sec = int.tryParse(m.group(1)!) ?? 0;
          if (sec >= 16 && sec <= 31) return true;
        }
        return false;
      }

      // Priority 1: Non-cellular private LAN (Wi-Fi, hotspot WLAN, Ethernet)
      for (final iface in interfaces) {
        if (!isCellular(iface.name)) {
          for (final addr in iface.addresses) {
            if (isPrivateLan(addr.address)) {
              return addr.address;
            }
          }
        }
      }

      // Priority 2: Any private LAN interface
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (isPrivateLan(addr.address)) {
            return addr.address;
          }
        }
      }

      // Priority 3: Fall back to NetworkInfo().getWifiIP() if private
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && isPrivateLan(wifiIp)) {
        return wifiIp;
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  // ══════════════════ BOOT SEQUENCE ══════════════════
  Future<void> _boot() async {
    int serverPort = 3000;
    try {
      final receivePort = ReceivePort();
      final appDir = await getApplicationDocumentsDirectory();
      final uploadPath = '${appDir.path}/biblepresenter_uploads';
      await Isolate.spawn(startServer, [uploadPath, receivePort.sendPort]);
      receivePort.listen((msg) {
        if (msg is Map && msg.containsKey('port')) {
          final p = msg['port'] as int;
          serverPort = p;
          SlideRenderer.serverPort = p;
        }
      });
    } catch (e) {
      print('[BiblePresenter] Isolate.spawn failed: $e');
    }
    setState(() => _serverStarted = true);

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        await WebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:$serverPort/ws'),
        ).ready.timeout(const Duration(seconds: 2));
        break;
      } catch (_) {
        print('[BiblePresenter] Waiting for server... attempt ${i + 1}');
      }
    }

    try {
      final ip = await findBestLanIp();
      if (mounted) setState(() => _deviceIp = ip);
    } catch (_) {}

    // DLNA "TV Direct": boot the UPnP stack (Android-only, no-ops elsewhere)
    // and point the slide renderer at the folder the server isolate serves.
    final appDir = await getApplicationDocumentsDirectory();
    SlideRenderer.uploadDirPath =
        '${appDir.path}/biblepresenter_uploads';
    SlideRenderer.deviceIp = _deviceIp;
    SlideRenderer.serverPort = serverPort;
    await _dlna.start();
    await _checkReconnectBanner();

    _connectWS();
    _reloadUploadedFiles();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLogo = prefs.getString('custom_logo_base64') ?? '';
      if (savedLogo.isNotEmpty && mounted)
        setState(() => _customLogoPath = savedLogo);
      final savedMsg = prefs.getString('welcome_message') ?? '';
      if (savedMsg.isNotEmpty && mounted) {
        setState(() {
          _welcomeMessage = savedMsg;
          _welcomeMsgCtrl.text = savedMsg;
        });
      }
      final savedBg = prefs.getString('current_bg_url');
      if (savedBg != null && savedBg.isNotEmpty && mounted) {
        setState(() => _bgUrl = savedBg);
        _emit('update-background', {'url': savedBg});
      }
    } catch (_) {}
  }

  // ══════════════════ CONFIRM DELETE DIALOG ══════════════════
  Future<bool> _confirmDelete(String itemName) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kBg3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade400, size: 24),
              const SizedBox(width: 10),
              const Text('Confirm Delete',
                  style: TextStyle(color: kText, fontSize: 16)),
            ]),
            content: Text(
                'Are you sure you want to delete "$itemName"?\nThis action cannot be undone.',
                style:
                    const TextStyle(color: kMuted, fontSize: 13, height: 1.5)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: kMuted))),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    backgroundColor: Colors.red.shade900.withOpacity(0.2)),
                child: Text('Delete',
                    style: TextStyle(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
    return confirmed;
  }

  // ══════════════════ IP REFRESH ══════════════════
  Future<void> _refreshIp() async {
    try {
      final ip = await findBestLanIp();
      if (mounted) {
        setState(() => _deviceIp = ip);
        SlideRenderer.deviceIp = ip;
        if (ip == '127.0.0.1' || ip.isEmpty) {
          _showSnack('No Wi-Fi or Hotspot detected. Connect to Wi-Fi to cast to TV.', error: true);
        } else {
          _showSnack('IP refreshed: $ip');
        }
      }
    } catch (e) {
      _showSnack('IP refresh error: $e', error: true);
    }
  }

  // Bible and Songs loading is handled by the Provider state classes
  // (BibleState, SongState, ScheduleState) which initialize in their constructors

  // ══════════════════ RELOAD UPLOADED FILES ══════════════════
  Future<void> _reloadUploadedFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final uploadPath = '${appDir.path}/biblepresenter_uploads';
      final uri = Uri.parse('http://127.0.0.1:${SlideRenderer.serverPort}/api/uploads');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> files = jsonDecode(response.body) as List<dynamic>;
        final ip = _deviceIp == '...' ? '127.0.0.1' : _deviceIp;
        final List<Map<String, String>> reloadedBgs = [];
        final List<Map<String, dynamic>> reloadedFiles = [];
        for (final f in files) {
          final name = f['name'] as String? ?? '';
          final url = f['url'] as String? ?? '';
          final type = f['type'] as String? ?? 'other';
          final size = f['size'] as int? ?? 0;
          final fullUrl = 'http://$ip:${SlideRenderer.serverPort}$url';
          final diskFile = File('$uploadPath/$name');
          final resolvedLocalPath = diskFile.existsSync() ? diskFile.path : '';
          if (type == 'image') {
            reloadedBgs.add({'name': name, 'url': fullUrl});
          } else {
            reloadedFiles.add({
              'name': name,
              'url': url,
              'type': type,
              'size': size,
              'localPath': resolvedLocalPath,
            });
          }
        }
        if (mounted) {
          setState(() {
            _uploadedBgs = reloadedBgs;
            _uploadedFiles = reloadedFiles;
          });
        }
      }
    } catch (_) {}
  }

  void _addManualSong() {
    final songState = SongState.of(context);
    if (songState.songTitleController.text.trim().isEmpty) return;
    final stanzas = songState.songStanzaControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (stanzas.isEmpty) return;
    songState.addManualSong();
    Navigator.pop(context);
    _showSnack('Song "${songState.songTitleController.text.trim()}" added!');
  }

  void _deleteSong(int idx) {
    final songState = SongState.of(context);
    if (idx < 0 || idx >= songState.allSongs.length) return;
    final song = songState.allSongs[idx];
    if (song['source'] != 'manual') return;
    songState.deleteSong(idx);
    _showSnack('Song deleted');
  }

  // ── Song Word import/export + slide editor ──
  Future<void> _importSongWord() async {
    if (_importingSongWord) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        _showSnack('Could not read the file', error: true);
        return;
      }
      setState(() => _importingSongWord = true);
      final parsed = SongDocx.parseSongDocx(bytes);
      final ok = await SongState.of(context)
          .importSong(title: parsed.title, stanzas: parsed.stanzas);
      if (mounted) {
        setState(() => _importingSongWord = false);
        if (ok) {
          _showSnack('"${parsed.title}" imported — '
              '${parsed.stanzas.length} slides!');
        } else {
          _showSnack('No song content found', error: true);
        }
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => _importingSongWord = false);
        _showSnack(e.message, error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importingSongWord = false);
        _showSnack('Import failed: $e', error: true);
      }
    }
  }

  Future<void> _exportSongWord() async {
    final songState = SongState.of(context);
    final song = songState.selectedSong;
    if (song == null) return;
    try {
      final title = song['title'] as String? ?? 'Song';
      final stanzas = List<String>.from(song['stanzas'] as List? ?? []);
      final bytes = SongDocx.exportSongDocx(title, stanzas);
      final safeName =
          title.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
      final path = await FilePicker.platform.saveFile(
        fileName: safeName.isEmpty ? 'song.docx' : '$safeName.docx',
        bytes: Uint8List.fromList(bytes),
      );
      if (path != null) {
        _showSnack('Exported "${song['title']}" (${stanzas.length} slides)');
      }
    } catch (e) {
      _showSnack('Export failed: $e', error: true);
    }
  }

  Future<void> _openSongSlideEditor() async {
    final songState = SongState.of(context);
    final song = songState.selectedSong;
    if (song == null) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SongSlideEditorScreen(
          title: song['title'] as String? ?? '',
          stanzas: List<String>.from(song['stanzas'] as List? ?? []),
          isManualSong: song['source'] == 'manual',
          onPreviewSlide: (i, stanzas, title) {
            _emit('cast-song', {
              'title': title,
              'stanzas': _stripStanzaLabels(stanzas),
              'currentStanza': i,
              'totalStanzas': stanzas.length,
              'fontSize': BibleState.of(context).fontSize,
              if (_bgUrl != null) 'background': {'url': _bgUrl}
            });
          },
          onSave: (title, stanzas) => SongState.of(context).saveSongEdits(
              song: song, newTitle: title, newStanzas: stanzas),
        ),
      ),
    );
    if (result == 'updated') _showSnack('Song updated');
    if (result == 'copied') _showSnack('Saved as an editable copy');
  }

  // ══════════════════ SCHEDULE METHODS ══════════════════
  void _createSchedule(String name, String dateStr) {
    if (name.trim().isEmpty) return;
    final scheduleState = ScheduleState.of(context);
    scheduleState.createSchedule(name, dateStr);
    Navigator.pop(context);
    _showSnack('Schedule "$name" created!');
  }

  void _addSongToSchedule(int scheduleIdx, int songIdx) {
    final scheduleState = ScheduleState.of(context);
    if (scheduleIdx < 0 || scheduleIdx >= scheduleState.schedules.length)
      return;
    final songState = SongState.of(context);
    if (songIdx < 0 || songIdx >= songState.allSongs.length) return;
    final song = songState.allSongs[songIdx];
    scheduleState.addSongToSchedule(scheduleIdx, song);
    _showSnack('Song added to schedule!');
  }

  void _removeSongFromSchedule(int scheduleIdx, int songPosition) {
    final scheduleState = ScheduleState.of(context);
    if (scheduleIdx < 0 || scheduleIdx >= scheduleState.schedules.length)
      return;
    scheduleState.removeSongFromSchedule(scheduleIdx, songPosition);
  }

  void _deleteSchedule(int idx) {
    final scheduleState = ScheduleState.of(context);
    scheduleState.deleteSchedule(idx);
    _showSnack('Schedule deleted');
  }

  void _startSchedulePresentation(int scheduleIdx) {
    final scheduleState = ScheduleState.of(context);
    if (scheduleIdx < 0 || scheduleIdx >= scheduleState.schedules.length)
      return;
    final songs = scheduleState.schedules[scheduleIdx]['songs'] as List? ?? [];
    if (songs.isEmpty) {
      _showSnack('No songs in this schedule!', error: true);
      return;
    }
    scheduleState.startSchedulePresentation(scheduleIdx);
    _castScheduleSong();
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => ScheduleFullscreen(
        scheduleName: scheduleState.schedules[scheduleIdx]['name'] ?? '',
        scheduleDate: scheduleState.schedules[scheduleIdx]['date'] ?? '',
        songs: scheduleState.schedules[scheduleIdx]['songs'] as List? ?? [],
        currentSongIndex: scheduleState.scheduleSongIndex,
        currentStanzaIndex: scheduleState.scheduleStanzaIndex,
        fontSize: BibleState.of(context)
            .fontSize, // Using BibleState for font size as it's shared
        onPrev: _schedulePrev,
        onNext: _scheduleNext,
        onCast: _castScheduleSong,
        onJumpToSong: (songIdx) {
          final state = ScheduleState.of(context);
          state.scheduleSongIndex = songIdx;
          state.scheduleStanzaIndex = 0;
          _castScheduleSong();
        },
        onExit: () {
          _exitScheduleMode();
        },
        getState: () => {
          'songIndex': ScheduleState.of(context).scheduleSongIndex,
          'stanzaIndex': ScheduleState.of(context).scheduleStanzaIndex
        },
      ),
    ));
  }

  void _castScheduleSong() {
    final scheduleState = ScheduleState.of(context);
    if (scheduleState.activeScheduleIndex < 0 ||
        scheduleState.activeScheduleIndex >= scheduleState.schedules.length)
      return;
    final songs = scheduleState.schedules[scheduleState.activeScheduleIndex]
            ['songs'] as List? ??
        [];
    if (scheduleState.scheduleSongIndex < 0 ||
        scheduleState.scheduleSongIndex >= songs.length) return;
    final song = songs[scheduleState.scheduleSongIndex];
    final stanzas = List<String>.from(song['stanzas'] ?? []);
    _emit('cast-song', {
      'title': song['title'] ?? '',
      'stanzas': _stripStanzaLabels(stanzas),
      'currentStanza': scheduleState.scheduleStanzaIndex,
      'totalStanzas': stanzas.length,
      'fontSize': BibleState.of(context)
          .fontSize, // Using BibleState for font size as it's shared
      if (_bgUrl != null) 'background': {'url': _bgUrl}
    });
  }

  void _scheduleNext() {
    final scheduleState = ScheduleState.of(context);
    if (scheduleState.activeScheduleIndex < 0 ||
        scheduleState.activeScheduleIndex >= scheduleState.schedules.length)
      return;
    final songs = scheduleState.schedules[scheduleState.activeScheduleIndex]
            ['songs'] as List? ??
        [];
    if (songs.isEmpty) return;
    final currentStanzas = List<String>.from(
        songs[scheduleState.scheduleSongIndex]['stanzas'] ?? []);
    if (scheduleState.scheduleStanzaIndex < currentStanzas.length - 1) {
      scheduleState.scheduleStanzaIndex++;
    } else if (scheduleState.scheduleSongIndex < songs.length - 1) {
      scheduleState.scheduleSongIndex++;
      scheduleState.scheduleStanzaIndex = 0;
    }
    _castScheduleSong();
  }

  void _schedulePrev() {
    final scheduleState = ScheduleState.of(context);
    if (scheduleState.activeScheduleIndex < 0 ||
        scheduleState.activeScheduleIndex >= scheduleState.schedules.length)
      return;
    final songs = scheduleState.schedules[scheduleState.activeScheduleIndex]
            ['songs'] as List? ??
        [];
    if (songs.isEmpty) return;
    if (scheduleState.scheduleStanzaIndex > 0) {
      scheduleState.scheduleStanzaIndex--;
    } else if (scheduleState.scheduleSongIndex > 0) {
      scheduleState.scheduleSongIndex--;
      final prevStanzas = List<String>.from(
          songs[scheduleState.scheduleSongIndex]['stanzas'] ?? []);
      scheduleState.scheduleStanzaIndex =
          prevStanzas.length > 0 ? prevStanzas.length - 1 : 0;
    }
    _castScheduleSong();
  }

  void _exitScheduleMode() {
    final scheduleState = ScheduleState.of(context);
    scheduleState.exitScheduleMode();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  // Strips a leading [Label] line (e.g. "[Chorus]") from each stanza so part
  // labels show on the phone controller but never appear on the cast TV screen.
  List<String> _stripStanzaLabels(List<String> stanzas) => stanzas
      .map((s) => s.replaceFirst(RegExp(r'^\s*\[[^\]]*\]\s*\n?'), ''))
      .toList();

  void _castSong() {
    _currentlyCastUrl = '';
    setState(() => _activeFileIndex = -1);
    final songState = SongState.of(context);
    if (songState.selectedSongIndex < 0 ||
        songState.selectedSongIndex >= songState.filteredSongs.length) return;
    final song = songState.filteredSongs[songState.selectedSongIndex];
    final stanzas = song['stanzas'] as List<String>? ?? [];
    _emit('cast-song', {
      'title': song['title'] ?? '',
      'stanzas': _stripStanzaLabels(stanzas),
      'currentStanza': songState.selectedStanzaIndex,
      'totalStanzas': stanzas.length,
      'fontSize': BibleState.of(context).fontSize,
      if (_bgUrl != null) 'background': {'url': _bgUrl}
    });
    _preRenderNext();
  }

  void _prevStanza() {
    final songState = SongState.of(context);
    if (songState.selectedStanzaIndex > 0) {
      songState.selectedStanzaIndex--;
      _castSong();
    }
  }

  void _nextStanza() {
    final songState = SongState.of(context);
    if (songState.selectedSongIndex < 0 ||
        songState.selectedSongIndex >= songState.filteredSongs.length) return;
    final stanzas = songState.filteredSongs[songState.selectedSongIndex]
            ['stanzas'] as List<String>? ??
        [];
    if (songState.selectedStanzaIndex < stanzas.length - 1) {
      songState.selectedStanzaIndex++;
      _castSong();
    }
  }

  // ══════════════════ CAST LOGO ══════════════════
  void _castLogo() {
    _currentlyCastUrl = '';
    setState(() => _activeFileIndex = -1);
    final bibleState = BibleState.of(context);
    if (_customLogoPath.isNotEmpty) {
      _emit('cast-logo', {
        'image': 'data:image/png;base64,$_customLogoPath',
        'fontSize': bibleState.fontSize,
        if (_bgUrl != null) 'background': {'url': _bgUrl}
      });
    } else {
      rootBundle.load('assets/church_logo.png').then((data) {
        final base64Str = base64Encode(data.buffer.asUint8List());
        _emit('cast-logo', {
          'image': 'data:image/png;base64,$base64Str',
          'fontSize': bibleState.fontSize,
          if (_bgUrl != null) 'background': {'url': _bgUrl}
        });
      }).catchError((e) {
        _showSnack('Logo load error: $e', error: true);
      });
    }
  }

  void _castWelcome() {
    _currentlyCastUrl = '';
    setState(() => _activeFileIndex = -1);
    if (_customLogoPath.isNotEmpty) {
      _emit('cast-welcome', {
        'logo': 'data:image/png;base64,$_customLogoPath',
        'message': _welcomeMessage
      });
    } else {
      rootBundle.load('assets/church_logo.png').then((data) {
        final base64Str = base64Encode(data.buffer.asUint8List());
        _emit('cast-welcome', {
          'logo': 'data:image/png;base64,$base64Str',
          'message': _welcomeMessage
        });
      }).catchError((e) {
        _emit('cast-welcome', {'logo': '', 'message': _welcomeMessage});
      });
    }
  }

  Future<void> _uploadCustomLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
          allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) return;
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_logo_base64', base64Str);
      setState(() => _customLogoPath = base64Str);
      _showSnack('Custom logo uploaded!');
    } catch (e) {
      _showSnack('Logo upload error: $e', error: true);
    }
  }

  // ══════════════════ SCREEN MIRRORING / FULL-SCREEN ══════════════════
  Future<void> _openScreenMirrorSettings() async {
    try {
      await _screenCastChannel.invokeMethod('openScreenMirror');
    } on PlatformException {
      _showSnack('Turn on Screencast from phone quick settings', error: false);
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      _showFullScreenControls = true;
    });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  String _getFullScreenContent() {
    if (_tvState.isEmpty || _tvState['type'] == 'idle') return '';
    final type = _tvState['type'] as String? ?? '';
    final content = _tvState['content'] as Map<String, dynamic>? ?? {};
    if (type == 'verse') {
      final hi = content['textHi'] as String? ?? '';
      final en = content['textEn'] as String? ?? '';
      final ref =
          '${content['book'] ?? ''} ${content['chapter'] ?? ''}:${content['verse'] ?? ''}';
      if (hi.isNotEmpty && en.isNotEmpty) return '$hi\n\n"$en"\n\n— $ref';
      if (hi.isNotEmpty) return '$hi\n\n— $ref';
      if (en.isNotEmpty) return '"$en"\n\n— $ref';
      return content['text'] as String? ?? '';
    } else if (type == 'slide') {
      final title = content['title'] as String? ?? '';
      final text = content['text'] as String? ?? '';
      if (title.isNotEmpty && text.isNotEmpty) return '$title\n\n$text';
      return title + text;
    } else if (type == 'song') {
      final stanzas = content['stanzas'] as List? ?? [];
      final idx = content['currentStanza'] as int? ?? 0;
      if (idx < stanzas.length) return stanzas[idx].toString();
      return '';
    } else if (type == 'welcome') {
      return content['message'] as String? ?? '';
    }
    return '';
  }

  void _showCastDialog() {
    final tvUrl =
        'http://${_deviceIp == '...' ? '<DEVICE_IP>' : _deviceIp}:3000/tv.html';
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Cast to TV',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kText)),
                IconButton(
                    icon: const Icon(Icons.close, color: kMuted),
                    onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),

              // ── TV Direct (DLNA) — the zero-setup path (plan 9.1) ──
              if (_dlna.isAndroid)
                GestureDetector(
                  onTap: () {
                    // Pre-warm discovery before the sheet opens.
                    _dlna.scan();
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: kBg3,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20))),
                      isScrollControlled: true,
                      builder: (_) => DlnaPickerSheet(
                        onUseBrowserConnect: _copyUrl,
                        onDeviceSelected: (_) => _castCurrentToDlna(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: kAccent.withOpacity(0.55), width: 1.5)),
                    child: Row(children: [
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: kAccent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.tv, size: 22, color: kAccent)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('TV Direct',
                                style: TextStyle(
                                    color: kText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            const Text(
                                'Cast to any Smart TV — no app, no URL',
                                style: TextStyle(color: kMuted, fontSize: 10))
                          ])),
                      const Icon(Icons.chevron_right, color: kMuted, size: 20),
                    ]),
                  ),
                ),
              const SizedBox(height: 10),

              // ── Chromecast / AirPlay (Pigeon-native) ──
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  // Open the CastButton's device picker sheet
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: kBg3,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    isScrollControlled: true,
                    builder: (_) =>
                        CastButton(castService: _castService, tvUrl: tvUrl),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade900.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.blue.shade600.withOpacity(0.4))),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade600.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.cast,
                            size: 22, color: Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Chromecast / AirPlay',
                              style: TextStyle(
                                  color: kText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Native cast — discover & connect to devices',
                              style: TextStyle(color: kMuted, fontSize: 10))
                        ])),
                    const Icon(Icons.chevron_right, color: kMuted, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 10),

              // ── Screen Mirror (Miracast) ──
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _toggleFullScreen();
                  _openScreenMirrorSettings();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccent.withOpacity(0.4))),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: kAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.screen_share_outlined,
                            size: 22, color: kAccent)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Screen Mirror',
                              style: TextStyle(
                                  color: kText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Mirror your phone screen to TV (Miracast)',
                              style: TextStyle(color: kMuted, fontSize: 10))
                        ])),
                    const Icon(Icons.chevron_right, color: kMuted, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 10),

              // ── Browser Connect ──
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _copyUrl();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade900.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.shade800.withOpacity(0.4))),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade900.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.cast,
                            size: 22, color: Colors.orange.shade400)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Browser Connect',
                              style: TextStyle(
                                  color: kText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Open the URL in TV browser',
                              style: TextStyle(color: kMuted, fontSize: 10))
                        ])),
                    const Icon(Icons.chevron_right, color: kMuted, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: kBg.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorder.withOpacity(0.5))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('HOW IT WORKS:',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: kGold,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      castStep('1',
                          'Chromecast/AirPlay → Native cast directly to your TV'),
                      const SizedBox(height: 4),
                      castStep('2',
                          'Screen Mirror → App will enter fullscreen + open cast settings'),
                      const SizedBox(height: 4),
                      castStep('3',
                          'Browser Connect → Copy URL and open in TV browser'),
                    ]),
              ),
            ]),
      ),
    );
  }

  /// Warm-up ping of the last-used TV (plan 9.2): if it answers, the whole
  /// reconnect ritual is a single tap on the banner. TVs in deep standby
  /// never answer SSDP (risk R9), so a failed ping simply hides the banner.
  Future<void> _checkReconnectBanner() async {
    final last = await DlnaService.lastTv();
    if (last == null || !mounted) return;
    setState(() {
      _reconnectName = last.name;
      _reconnectUdn = last.udn;
    });
    final alive = await _dlna.pingStored(last.udn);
    if (alive != null && mounted) {
      // TV answered: banner stays; tapping connects and casts.
      setState(() {});
    }
  }

  Future<void> _reconnectFromBanner() async {
    if (_reconnectUdn.isEmpty) return;
    final alive = await _dlna.pingStored(_reconnectUdn);
    if (alive == null) {
      _showSnack('$_reconnectName not reachable — check the TV is on');
      return;
    }
    await _dlna.connect(alive);
    _showSnack('Connected ✓  ${_dlna.connectedName}');
    await _castCurrentToDlna();
  }

  // ══════════════════ DLNA TV DIRECT (Feature 1) ══════════════════
  /// Pre-renders the likely next state (next verse / stanza / slide / PDF
  /// page) while the current one is on screen (plan 4.3 latency lever).
  void _preRenderNext() {
    if (!_dlna.isConnected || _tvState['type'] == 'idle') return;
    try {
      final type = _tvState['type'] as String?;
      final bg = _bgUrl != null ? {'url': _bgUrl} : null;
      switch (type) {
        case 'verse':
          final bs = BibleState.of(context);
          final vList = (bs.selectedBookChapters?[bs.selectedChapter] ?? {})
              .keys
              .toList()
            ..sort();
          final idx = vList.indexOf(bs.selectedVerse);
          if (idx >= 0) {
            // Pre-render N+1
            if (idx < vList.length - 1) {
              final nextVNum = vList[idx + 1];
              final nv = bs.bible[bs.selectedBook]?[bs.selectedChapter]?[nextVNum];
              OutputRouter.instance.preRender({
                'type': 'verse',
                'content': {
                  'book': bs.selectedBook,
                  'chapter': bs.selectedChapter,
                  'verse': nextVNum,
                  'textEn': nv?['secondary'] ?? '',
                  'textHi': nv?['primary'] ?? '',
                  'text': nv?['primary'] ?? nv?['secondary'] ?? '',
                  'fontSize': bs.fontSize,
                },
                'background': bg,
              }, context);
            }
            // Pre-render N-1
            if (idx > 0) {
              final prevVNum = vList[idx - 1];
              final pv = bs.bible[bs.selectedBook]?[bs.selectedChapter]?[prevVNum];
              OutputRouter.instance.preRender({
                'type': 'verse',
                'content': {
                  'book': bs.selectedBook,
                  'chapter': bs.selectedChapter,
                  'verse': prevVNum,
                  'textEn': pv?['secondary'] ?? '',
                  'textHi': pv?['primary'] ?? '',
                  'text': pv?['primary'] ?? pv?['secondary'] ?? '',
                  'fontSize': bs.fontSize,
                },
                'background': bg,
              }, context);
            }
          }
          break;
        case 'slide':
          // Pre-render N+1
          if (_activeSlide + 1 < _slides.length) {
            final sl = _slides[_activeSlide + 1];
            OutputRouter.instance.preRender({
              'type': 'slide',
              'content': {
                'title': sl['title'] ?? '',
                'subtitle': sl['subtitle'] ?? '',
                'text': sl['text'] ?? '',
                'fontSize': BibleState.of(context).fontSize,
              },
              'background': bg,
            }, context);
          }
          // Pre-render N-1
          if (_activeSlide > 0 && _slides.isNotEmpty) {
            final sl = _slides[_activeSlide - 1];
            OutputRouter.instance.preRender({
              'type': 'slide',
              'content': {
                'title': sl['title'] ?? '',
                'subtitle': sl['subtitle'] ?? '',
                'text': sl['text'] ?? '',
                'fontSize': BibleState.of(context).fontSize,
              },
              'background': bg,
            }, context);
          }
          break;
        case 'song':
          final content = Map<String, dynamic>.from(_tvState['content'] as Map? ?? {});
          final stanzas = List<String>.from(content['stanzas'] ?? []);
          final cur = content['currentStanza'] as int? ?? 0;
          // Pre-render N+1
          if (cur + 1 < stanzas.length) {
            final nextC = Map<String, dynamic>.from(content);
            nextC['currentStanza'] = cur + 1;
            OutputRouter.instance.preRender({
              'type': 'song',
              'content': nextC,
              'background': bg,
            }, context);
          }
          // Pre-render N-1
          if (cur > 0 && cur < stanzas.length) {
            final prevC = Map<String, dynamic>.from(content);
            prevC['currentStanza'] = cur - 1;
            OutputRouter.instance.preRender({
              'type': 'song',
              'content': prevC,
              'background': bg,
            }, context);
          }
          break;
        case 'pdf':
          if (_pdfTotalPages > 0) {
            if (_pdfCurrentPage + 1 <= _pdfTotalPages) {
              OutputRouter.instance.preRenderPdfPage(
                  _currentPdfLocalPath, _pdfCurrentPage + 1, context);
            }
            if (_pdfCurrentPage > 1) {
              OutputRouter.instance.preRenderPdfPage(
                  _currentPdfLocalPath, _pdfCurrentPage - 1, context);
            }
          }
          break;
      }
    } catch (_) {}
  }
  /// Renders whatever is currently on the presentation screen as a full-HD
  /// PNG and pushes it to the connected TV (SetAVTransportURI + Play).
  Future<void> _castCurrentToDlna() async {
    if (!_dlna.isConnected) return;
    if (_tvState.isEmpty || _tvState['type'] == 'idle') {
      _showSnack('Nothing on screen yet — pick a verse or slide first');
      return;
    }
    try {
      final url = await SlideRenderer.captureAndPublish(_tvState,
          context: context);
      if (url == null) {
        _showSnack('Could not render the slide', error: true);
        return;
      }
      final ok = await _dlna.castImage(url);
      _showSnack(ok ? 'Casting to ${_dlna.connectedName}' : 'TV cast failed',
          error: !ok);
    } catch (e) {
      _showSnack('TV Direct error: $e', error: true);
    }
  }

  // ══════════════════ WEBSOCKET ══════════════════
  void _connectWS() {
    _reconnectTimer?.cancel();
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:3000/ws'));
      _channel!.stream.listen(
        (msg) {
          try {
            final data = jsonDecode(msg as String);
            // TV → phone media reports arrive as {event, data}.
            if (data is Map && data['event'] != null) {
              _handleTvEvent(
                data['event'] as String,
                Map<String, dynamic>.from(data['data'] as Map? ?? {}),
              );
              return;
            }
            if (data is Map && data['type'] != null) {
              if (mounted) {
                setState(() {
                  _setTvState(Map<String, dynamic>.from(data));
                  _connected = true;
                  if (data['type'] == 'pdf' && data['content'] != null) {
                    final content = data['content'] as Map<String, dynamic>;
                    _pdfCurrentPage = content['currentPage'] ?? _pdfCurrentPage;
                    if (content['totalPages'] != null &&
                        (content['totalPages'] as int) > 0)
                      _pdfTotalPages = content['totalPages'];
                  }
                });
              }
              _reconnectDelay = 2;
            }
          } catch (_) {}
        },
        onDone: () {
          if (mounted) setState(() => _connected = false);
          _scheduleReconnect();
        },
        onError: (error) {
          if (mounted) setState(() => _connected = false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      if (mounted) setState(() => _connected = false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      if (mounted) _connectWS();
      _reconnectDelay = (_reconnectDelay * 2).clamp(2, _maxReconnectDelay);
    });
  }

  void _emit(String event, Map<String, dynamic> data) {
    // OutputRouter fan-out (plan 4.2): with a DLNA TV attached, every cast
    // action ALSO renders the state and pushes it to the renderer — even
    // when no browser TV is attached. YouTube never travels over DLNA.
    OutputRouter.instance.route(
        event: event, data: data, context: context, currentState: _tvState);
    _applyOptimisticState(event, data);
    if (_channel == null || !_connected) {
      if (!_dlna.isConnected) {
        _showSnack('Not connected to server! Reconnecting...', error: true);
      }
      _connectWS();
      return;
    }
    _channel!.sink.add(jsonEncode({'event': event, 'data': data}));
  }

  /// Mirrors the server's state logic locally so TV Direct-only sessions
  /// (no browser TV, no WS echo) still know what is on screen — required by
  /// _castCurrentToDlna and the pre-renderer. The server echo overwrites
  /// this with identical data when a browser TV is attached.
  void _applyOptimisticState(String event, Map<String, dynamic> data) {
    setState(() {
      switch (event) {
        case 'cast-verse':
        case 'cast-slide':
        case 'cast-song':
        case 'cast-logo':
        case 'cast-pdf':
        case 'cast-pptx':
          _setTvState({
            'type': event.substring(5),
            'content': data,
            'fontSize': data['fontSize'] ?? _tvState['fontSize'] ?? 44,
            'background': data['background'] ?? _tvState['background'],
          });
          break;
        case 'cast-welcome':
          _setTvState({
            'type': 'welcome',
            'content': data,
            'fontSize': _tvState['fontSize'] ?? 44,
            'background': null,
          });
          break;
        case 'pdf-page':
          if (_tvState['type'] == 'pdf' || _tvState['type'] == 'pptx') {
            final c =
                Map<String, dynamic>.from(_tvState['content'] as Map? ?? {});
            c['currentPage'] = data['page'] ?? c['currentPage'];
            if ((data['totalPages'] ?? 0) > 0) {
              c['totalPages'] = data['totalPages'];
            }
            _setTvState({..._tvState, 'content': c});
          }
          break;
        case 'cast-video':
          _setTvState({
            'type': 'video',
            'content': data,
            'fontSize': _tvState['fontSize'] ?? 44,
            'background': _tvState['background'],
          });
          break;
        case 'update-background':
          _setTvState({..._tvState, 'background': data.isEmpty ? null : data});
          break;
        case 'cast-blackout':
          _setTvState({
            'type': 'blackout',
            'content': null,
            'fontSize': _tvState['fontSize'] ?? 44,
            'background': null,
          });
          break;
        case 'clear-screen':
        case 'video-stop':
          _setTvState({'type': 'idle'});
          break;
      }
    });
  }

  // ── Cast actions ──
  void _castVerse() {
    _currentlyCastUrl = '';
    setState(() => _activeFileIndex = -1);
    final bibleState = BibleState.of(context);
    final v = bibleState.selectedVerseData;
    _emit('cast-verse', {
      'book': bibleState.selectedBook,
      'chapter': bibleState.selectedChapter,
      'verse': bibleState.selectedVerse,
      'textEn': v?['secondary'] ?? '',
      'textHi': v?['primary'] ?? '',
      'text': v?['primary'] ?? v?['secondary'] ?? '',
      'fontSize': bibleState.fontSize,
      if (_bgUrl != null) 'background': {'url': _bgUrl}
    });
    _preRenderNext();
  }

  void _castSlide(int idx) {
    _currentlyCastUrl = '';
    setState(() {
      _activeSlide = idx;
      _activeFileIndex = -1;
    });
    final s = _slides[idx];
    _emit('cast-slide', {
      'title': s['title'] ?? '',
      'subtitle': s['subtitle'] ?? '',
      'text': s['text'] ?? '',
      'slideIndex': idx,
      'totalSlides': _slides.length,
      'fontSize': BibleState.of(context).fontSize,
      if (_bgUrl != null) 'background': {'url': _bgUrl}
    });
    _preRenderNext();
  }

  void _clearScreen() {
    _currentlyCastUrl = '';
    setState(() => _activeFileIndex = -1);
    _emit('clear-screen', {});
  }

  void _castBlackout() {
    _emit('cast-blackout', {});
  }

  void _addSlide() {
    if (_addTitleCtrl.text.trim().isEmpty) return;
    setState(() {
      _slides.insert(0, {
        'title': _addTitleCtrl.text.trim().toUpperCase(),
        'subtitle': '',
        'text': _addContentCtrl.text.trim()
      });
      _activeSlide = 0;
    });
    _addTitleCtrl.clear();
    _addContentCtrl.clear();
    Navigator.pop(context);
    _castSlide(0);
  }

  void _deleteSlide(int i) {
    if (_slides.length <= 1) return;
    _confirmDelete(_slides[i]['title'] ?? 'this slide').then((confirmed) {
      if (!confirmed) return;
      setState(() {
        _slides.removeAt(i);
        if (_activeSlide >= _slides.length) _activeSlide = _slides.length - 1;
        if (_activeSlide < 0) _activeSlide = 0;
      });
    });
  }

  void _prevVerse() {
    final bibleState = BibleState.of(context);
    final chList = (bibleState.selectedBookChapters ?? {}).keys.toList()..sort();
    final vList =
        (bibleState.selectedBookChapters?[bibleState.selectedChapter] ?? {})
            .keys
            .toList()
          ..sort();
    final idx = vList.indexOf(bibleState.selectedVerse);
    if (idx > 0) {
      bibleState.selectedVerse = vList[idx - 1];
      _castVerse();
    } else {
      // Verse boundary: go to previous chapter's last verse
      final chIdx = chList.indexOf(bibleState.selectedChapter);
      if (chIdx > 0) {
        final prevCh = chList[chIdx - 1];
        bibleState.selectedChapter = prevCh;
        final prevVList =
            (bibleState.selectedBookChapters?[prevCh] ?? {}).keys.toList()
              ..sort();
        if (prevVList.isNotEmpty) {
          bibleState.selectedVerse = prevVList.last;
          _castVerse();
        }
      }
    }
  }

  void _nextVerse() {
    final bibleState = BibleState.of(context);
    final chList = (bibleState.selectedBookChapters ?? {}).keys.toList()..sort();
    final vList =
        (bibleState.selectedBookChapters?[bibleState.selectedChapter] ?? {})
            .keys
            .toList()
          ..sort();
    final idx = vList.indexOf(bibleState.selectedVerse);
    if (idx < vList.length - 1 && idx >= 0) {
      bibleState.selectedVerse = vList[idx + 1];
      _castVerse();
    } else {
      // Verse boundary: advance to next chapter's first verse
      final chIdx = chList.indexOf(bibleState.selectedChapter);
      if (chIdx < chList.length - 1 && chIdx >= 0) {
        final nextCh = chList[chIdx + 1];
        bibleState.selectedChapter = nextCh;
        final nextVList =
            (bibleState.selectedBookChapters?[nextCh] ?? {}).keys.toList()
              ..sort();
        if (nextVList.isNotEmpty) {
          bibleState.selectedVerse = nextVList.first;
          _castVerse();
        }
      }
    }
  }

  // ══════════════════ FILE UPLOAD & CAST ══════════════════
  static const _videoExts = ['mp4', 'm4v', 'webm', 'mov', 'mkv', 'avi'];

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'ppt', 'pptx', ..._videoExts],
          allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) {
        _showSnack('File path not available', error: true);
        return;
      }
      final fileName = result.files.first.name;
      final fileExt = fileName.split('.').last.toLowerCase();
      final isVideo = _videoExts.contains(fileExt);
      if (!['pdf', 'ppt', 'pptx', ..._videoExts].contains(fileExt)) {
        _showSnack('Only PDF, PPT/PPTX and video files are allowed!', error: true);
        return;
      }
      setState(() => _isUploading = true);
      final file = File(filePath);
      final uri = Uri.parse(
          'http://127.0.0.1:3000/api/upload?name=${Uri.encodeComponent(fileName)}');

      // Stream the file from disk to the server (videos reach 1–2 GB; risk
      // R4 keeps phone memory flat on both ends of the upload).
      int size = 0;
      try {
        size = await file.length();
        final streamedReq = http.StreamedRequest('POST', uri)
          ..contentLength = size;
        file.openRead().listen(
              streamedReq.sink.add,
              onDone: () => streamedReq.sink.close(),
              onError: (_) => streamedReq.sink.close(),
            );
        final response =
            await http.Response.fromStream(await http.Client().send(streamedReq));
        _handleUploadResponse(response, fileName, filePath, isVideo);
      } catch (e) {
        // Small files (<50 MB) may retry with a plain buffered POST; large
        // files never fall back to readAsBytes (memory, risk R4).
        if (size > 0 && size <= 50 * 1024 * 1024) {
          final bytes = await file.readAsBytes();
          final response = await http.post(uri, body: bytes);
          _handleUploadResponse(response, fileName, filePath, isVideo);
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnack('Upload error: $e', error: true);
      }
    }
  }

  // ── Bible language import (VerseVIEW bible-database) ──
  Future<void> _importBibleLanguage() async {
    if (_importingBible) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml', 'json'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        _showSnack('File path not available', error: true);
        return;
      }
      setState(() => _importingBible = true);
      final imported = await BibleImport.parseFile(path);
      await BibleState.of(context).addImportedLanguage(imported);
      if (mounted) {
        setState(() => _importingBible = false);
        _showSnack(
            '${imported.name} added — ${imported.verseCount} verses! '
            'Pick it as Primary or Secondary in Languages.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importingBible = false);
        _showSnack('Import failed: $e', error: true);
      }
    }
  }

  void _handleUploadResponse(http.Response response, String fileName,
      String filePath, bool isVideo) {
    setState(() => _isUploading = false);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _uploadedFiles.insert(0, {
          'name': data['name'] ?? fileName,
          'url': data['url'] ?? '',
          'type': data['type'] ?? (isVideo ? 'video' : 'other'),
          'size': data['size'] ?? 0,
          'localPath': filePath
        });
      });
      _showSnack('$fileName uploaded!');
      _castFile(0);
    } else {
      _showSnack('Upload fail: ${response.statusCode}', error: true);
    }
  }

  Future<void> _castFile(int idx) async {
    if (idx < 0 || idx >= _uploadedFiles.length) return;
    final f = _uploadedFiles[idx];
    final fileType = f['type'] as String? ?? 'other';
    final fileUrl = f['url'] as String? ?? '';
    final fileName = f['name'] as String? ?? 'Document';
    if (fileUrl.isEmpty) {
      _showSnack('File URL not found!', error: true);
      return;
    }
    setState(() {
      _activeFileIndex = idx;
      _pdfCurrentPage = 1;
      _pdfTotalPages = 0;
    });
    if (fileType == 'pdf') {
      _currentlyCastUrl = fileUrl;
      var localP = f['localPath'] as String? ?? '';
      if (localP.isEmpty) {
        final uploadDir = SlideRenderer.uploadDirPath;
        if (uploadDir.isNotEmpty) {
          final diskFile = File('$uploadDir/$fileName');
          if (diskFile.existsSync()) {
            localP = diskFile.path;
            f['localPath'] = localP;
          }
        }
      }
      if (localP.isEmpty) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final diskFile = File('${appDir.path}/biblepresenter_uploads/$fileName');
          if (diskFile.existsSync()) {
            localP = diskFile.path;
            f['localPath'] = localP;
          }
        } catch (_) {}
      }
      _currentPdfLocalPath = localP;
      // Sequencing note: the page-count probe below opens + closes the PDF
      // BEFORE _emit('cast-pdf'), so the router's Page-1 render and the
      // presenter screen's own open never overlap with this probe. The
      // router serializes its own renders through _pdfGate and retries the
      // entry page once — Kodi receives Page 1 immediately on entry.
      if (localP.isNotEmpty) {
        try {
          final doc = await pdfx.PdfDocument.openFile(localP);
          if (mounted && doc.pagesCount > 0) {
            setState(() => _pdfTotalPages = doc.pagesCount);
          }
          await doc.close();
        } catch (_) {}
      }
      _emit('cast-pdf', {
        'url': fileUrl,
        'name': fileName,
        'currentPage': 1,
        'totalPages': _pdfTotalPages,
        '_localPdfPath': _currentPdfLocalPath
      });
      _showSnack('Casting PDF to TV!');
    } else if (fileType == 'pptx') {
      _currentlyCastUrl = fileUrl;
      _emit('cast-pptx', {'url': fileUrl, 'name': fileName});
      if (_dlna.isConnected) {
        _showSnack('PPT requires Browser Connect mode — open TV Browser to view');
      } else {
        _showSnack('Casting PPT to TV!');
      }
    } else if (fileType == 'video') {
      _castVideo(idx);
    } else {
      _showSnack('This file type is not supported!', error: true);
    }
  }

  // ══════════════════ VIDEO CAST & REMOTE (Feature 2) ══════════════════
  void _castVideo(int idx) {
    final f = _uploadedFiles[idx];
    final fileUrl = f['url'] as String? ?? '';
    final fileName = f['name'] as String? ?? 'Video';
    if (fileUrl.isEmpty) {
      _showSnack('File URL not found!', error: true);
      return;
    }
    final ext = fileName.split('.').last.toLowerCase();
    if (['mkv', 'avi'].contains(ext)) {
      _showSnack(
          'MKV/AVI often fails on TV players — MP4 (H.264) is recommended',
          error: true);
    }
    setState(() {
      _activeFileIndex = idx;
      _currentlyCastUrl = fileUrl;
      _videoPosition = 0;
      _videoDuration = 0;
      _videoPlaying = true;
      _videoMutedByBrowser = false;
      _videoFinished = false;
    });
    _emit('cast-video', {'url': fileUrl, 'title': fileName});
    _showSnack('Casting video to TV!');
  }

  void _videoPlayPause() {
    if (_videoPlaying) {
      _emit('video-control', {'action': 'pause'});
      setState(() => _videoPlaying = false);
    } else {
      _emit('video-control', {'action': 'play'});
      setState(() {
        _videoPlaying = true;
        _videoFinished = false;
      });
    }
  }

  void _videoSeekTo(double seconds) {
    _emit('video-seek', {'seconds': seconds.round()});
    setState(() => _videoPosition = seconds);
  }

  void _videoStop() {
    _emit('video-stop', {});
    setState(() {
      _currentlyCastUrl = '';
      _videoPosition = 0;
      _videoDuration = 0;
      _videoPlaying = false;
      _videoMutedByBrowser = false;
      _videoFinished = false;
    });
  }

  void _videoUnmute() {
    _emit('yt-unmute', {});
    _emit('video-control', {'action': 'play'});
    setState(() => _videoMutedByBrowser = false);
    _showSnack('Audio on');
  }

  // Handles TV → phone reports forwarded by the server ({event, data}).
  void _handleTvEvent(String event, Map<String, dynamic> data) {
    switch (event) {
      case 'video-progress':
        if (mounted) {
          setState(() {
            _videoPosition = (data['position'] as num? ?? 0).toDouble();
            if ((data['duration'] as num? ?? 0) > 0) {
              _videoDuration = (data['duration'] as num).toDouble();
            }
            _videoPlaying = data['playing'] as bool? ?? _videoPlaying;
            _videoFinished = false;
          });
        }
        break;
      case 'video-ended':
        if (mounted) {
          setState(() {
            _videoPlaying = false;
            _videoFinished = true;
            _videoPosition = _videoDuration;
          });
          _showSnack('Video finished');
        }
        break;
      case 'video-muted':
        if (mounted) setState(() => _videoMutedByBrowser = true);
        break;
      case 'video-error':
        if (mounted) {
          setState(() => _videoPlaying = false);
          _showSnack(
              'TV could not play this file — MP4 (H.264/AAC) works best',
              error: true);
        }
        break;
      case 'yt-state':
        if (mounted) {
          final st = data['state'] as String?;
          setState(() {
            _ytPlaying = st == 'playing';
            if (st == 'ended') _ytAdvanceQueue();
            if ((data['position'] as num? ?? 0) > 0) {
              _ytPosition = (data['position'] as num).toDouble();
            }
            if ((data['duration'] as num? ?? 0) > 0) {
              _ytDuration = (data['duration'] as num).toDouble();
            }
          });
        }
        break;
      case 'yt-error':
        if (mounted) {
          setState(() => _ytPlaying = false);
          _showSnack("This video can't be cast (owner restriction)", error: true);
        }
        break;
    }
  }

  /// Playlist advance: on the YouTube player's `ended` state, move to the
  /// next queued video, if any.
  void _ytAdvanceQueue() {
    if (_ytQueueIndex < 0 || _ytQueueIndex >= _ytQueue.length - 1) return;
    _ytQueueIndex++;
    final videoId = _ytQueue[_ytQueueIndex];
    setState(() => _ytPlaying = true);
    _emit('cast-youtube', {'videoId': videoId, 'title': ''});
    _showSnack('Playing next video (${_ytQueueIndex + 1}/${_ytQueue.length})');
  }

  // ══════════════════ YOUTUBE CAST (Feature 3) ══════════════════
  /// Extracts the eleven-character video ID from the three common YouTube
  /// link forms: watch?v=, youtu.be/ and shorts/.
  static String? extractYouTubeId(String url) {
    final patterns = [
      RegExp(r'v=([\w-]{11})'), // youtube.com/watch?v=ID
      RegExp(r'youtu\.be/([\w-]{11})'), // https://youtu.be/ID
      RegExp(r'shorts/([\w-]{11})'), // youtube.com/shorts/ID
    ];
    for (final re in patterns) {
      final m = re.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  void _castYouTubeUrl() {
    final raw = _ytUrlCtrl.text.trim();
    if (raw.isEmpty) return;
    final videoId = extractYouTubeId(raw);
    if (videoId == null) {
      _showSnack('Paste a youtube.com/watch, youtu.be or shorts link',
          error: true);
      return;
    }
    setState(() {
      _ytQueue.add(videoId);
      _ytQueueIndex = _ytQueue.length - 1;
      _ytPlaying = true;
      _ytPosition = 0;
      _ytDuration = 0;
      _ytUrlCtrl.clear();
    });
    _emit('cast-youtube', {'videoId': videoId});
    _showSnack('Casting YouTube to TV!');
  }

  void _ytPlayPause() {
    if (_ytPlaying) {
      _emit('yt-pause', {});
      setState(() => _ytPlaying = false);
    } else {
      _emit('yt-play', {});
      setState(() => _ytPlaying = true);
    }
  }

  void _ytSeekTo(double seconds) {
    _emit('yt-seek', {'seconds': seconds.round()});
    setState(() => _ytPosition = seconds);
  }

  void _ytVolume(double value) {
    _emit('yt-volume', {'value': value.round()});
    setState(() => _ytVolumeVal = value);
  }

  void _ytStop() {
    _emit('clear-screen', {});
    setState(() {
      _ytPlaying = false;
      _ytPosition = 0;
      _ytDuration = 0;
      _ytQueue.clear();
      _ytQueueIndex = -1;
    });
  }

  void _ytRemoveFromQueue(int idx) {
    setState(() {
      _ytQueue.removeAt(idx);
      if (_ytQueueIndex >= _ytQueue.length) {
        _ytQueueIndex = _ytQueue.length - 1;
      }
    });
  }

  void _pdfPrevPage() {
    if (_pdfCurrentPage > 1) {
      _pdfCurrentPage--;
      _emit('pdf-page', {
        'page': _pdfCurrentPage,
        '_localPdfPath': _currentPdfLocalPath
      });
      setState(() {});
      _preRenderNext();
    }
  }

  void _pdfNextPage() {
    if (_pdfTotalPages > 0 && _pdfCurrentPage >= _pdfTotalPages) return;
    _pdfCurrentPage++;
    _emit('pdf-page', {
      'page': _pdfCurrentPage,
      '_localPdfPath': _currentPdfLocalPath
    });
    setState(() {});
    _preRenderNext();
  }

  /// Direct jump used by the PDF presenter's thumbnail grid.
  void _pdfGoToPage(int page) {
    if (page < 1) return;
    if (_pdfTotalPages > 0 && page > _pdfTotalPages) return;
    _pdfCurrentPage = page;
    _emit('pdf-page', {
      'page': _pdfCurrentPage,
      '_localPdfPath': _currentPdfLocalPath
    });
    setState(() {});
    _preRenderNext();
  }

  Future<void> _deleteUploadedFile(int idx) async {
    final fileName = _uploadedFiles[idx]['name'] as String? ?? '';
    final confirmed = await _confirmDelete(fileName);
    if (!confirmed) return;
    final deletedUrl = _uploadedFiles[idx]['url'] as String? ?? '';
    if (fileName.isNotEmpty) {
      try {
        final uri = Uri.parse(
            'http://127.0.0.1:3000/api/upload/${Uri.encodeComponent(fileName)}');
        await http.delete(uri);
      } catch (e) {}
    }
    if (deletedUrl == _currentlyCastUrl) {
      _currentlyCastUrl = '';
      _emit('clear-screen', {});
    }
    setState(() {
      _uploadedFiles.removeAt(idx);
      if (_activeFileIndex >= _uploadedFiles.length)
        _activeFileIndex = _uploadedFiles.length - 1;
      if (_activeFileIndex < 0) _activeFileIndex = -1;
    });
    _showSnack('File deleted');
  }

  // ══════════════════ UPLOAD BACKGROUND ══════════════════
  Future<void> _uploadBgImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
          allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) return;
      final fileName = result.files.first.name;
      setState(() => _isUploadingBg = true);
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final uri = Uri.parse(
          'http://127.0.0.1:${SlideRenderer.serverPort}/api/upload?name=${Uri.encodeComponent(fileName)}');
      final response = await http.post(uri, body: bytes);
      setState(() => _isUploadingBg = false);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final uploadedUrl = data['url'] as String? ?? '';
        final ip = _deviceIp == '...' ? '127.0.0.1' : _deviceIp;
        final fullUrl = 'http://$ip:${SlideRenderer.serverPort}$uploadedUrl';
        setState(() {
          _uploadedBgs.insert(0, {'name': fileName, 'url': fullUrl});
          _bgUrl = fullUrl;
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_bg_url', fullUrl);
        } catch (_) {}
        _emit('update-background', {'url': fullUrl});
        _showSnack('Background set!');
      } else {
        _showSnack('Upload fail: ${response.statusCode}', error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingBg = false);
        _showSnack('Upload error: $e', error: true);
      }
    }
  }

  void _deleteUploadedBg(int bgIdx) async {
    final bg = _uploadedBgs[bgIdx];
    final confirmed = await _confirmDelete(bg['name'] ?? 'background');
    if (!confirmed) return;
    final bgName = bg['name'] ?? '';
    if (bgName.isNotEmpty) {
      try {
        final uri = Uri.parse(
            'http://127.0.0.1:3000/api/upload/${Uri.encodeComponent(bgName)}');
        await http.delete(uri);
      } catch (e) {}
    }
    setState(() {
      if (_bgUrl == bg['url']) {
        _bgUrl = null;
        _emit('update-background', {});
      }
      _uploadedBgs.removeAt(bgIdx);
    });
    _showSnack('Background deleted');
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(
        text:
            'http://${_deviceIp == '...' ? '<DEVICE_IP>' : _deviceIp}:3000/tv.html'));
    _showSnack('URL copied!');
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade800 : kBg3,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ══════════════════ SECTION FULLSCREEN OPENERS ══════════════════
  void _openSlidesFullscreen() {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => SectionFullscreen(
        sectionTitle: 'SLIDES',
        sectionIcon: Icons.slideshow,
        sectionColor: kAccent,
        bgImageUrl: _bgUrl,
        tvState: _tvState,
        onBlackout: _clearScreen,
        onWelcome: _castWelcome,
        onLogo: _castLogo,
        onExit: () => Navigator.pop(context),
        contentBuilder: () => Text(
          _slides[_activeSlide]['title'] ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: (BibleState.of(context).fontSize * 0.9)
                  .clamp(20, 60)
                  .toDouble(),
              fontWeight: FontWeight.w600,
              height: 1.8,
              shadows: [
                Shadow(
                    color: Colors.black.withValues(alpha: 0.9), blurRadius: 20)
              ]),
        ),
        controlsBuilder: (refresh) => [
          Text('${_activeSlide + 1} / ${_slides.length}',
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontFamily: 'monospace')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: fsNavBtn(
                    icon: Icons.skip_previous,
                    label: 'Prev',
                    iconFirst: true,
                    onTap: _activeSlide > 0
                        ? () {
                            _castSlide(_activeSlide - 1);
                            refresh();
                          }
                        : null)),
            const SizedBox(width: 10),
            Expanded(
                flex: 2,
                child: fsCastBtn(
                    label: 'Cast',
                    gradient: const [kAccent, Color(0xFF6366F1)],
                    onTap: () {
                      _castSlide(_activeSlide);
                      refresh();
                    })),
            const SizedBox(width: 10),
            Expanded(
                child: fsNavBtn(
                    icon: Icons.skip_next,
                    label: 'Next',
                    iconFirst: false,
                    onTap: _activeSlide < _slides.length - 1
                        ? () {
                            _castSlide(_activeSlide + 1);
                            refresh();
                          }
                        : null)),
          ]),
        ],
      ),
    ));
  }

  // ══════════════════ PRESENTER SCREENS (live stage) ══════════════════
  // Dedicated, distraction-free live screens. The dock is pinned at a fixed
  // height so Prev/Next never shift (see widgets/presenter_shell.dart).

  void _openBiblePresenter() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BiblePresenterScreen(
        bibleState: BibleState.of(context),
        tvState: tvStateN,
        onCastVerse: _castVerse,
        onPrevVerse: _prevVerse,
        onNextVerse: _nextVerse,
        onLogo: _castLogo,
        onBlackout: _castBlackout,
      ),
    ));
  }

  void _openSongPresenter({int? index}) {
    final songState = SongState.of(context);
    if (index != null) {
      songState.selectedSongIndex = index;
    }
    if (songState.selectedSongIndex < 0 ||
        songState.selectedSongIndex >= songState.filteredSongs.length) {
      _showSnack('Select a song first!', error: true);
      return;
    }
    _castSong();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SongPresenterScreen(
        songState: songState,
        tvState: tvStateN,
        onSelectStanza: (i) {
          songState.selectedStanzaIndex = i;
          _castSong();
        },
        onPrevStanza: _prevStanza,
        onNextStanza: _nextStanza,
        onLogo: _castLogo,
        onBlackout: _castBlackout,
        onClear: _clearScreen,
      ),
    ));
  }

  void _openPdfPresenter() {
    String? localP = _currentPdfLocalPath.isNotEmpty ? _currentPdfLocalPath : null;
    String name = 'Document';
    if (_tvState['type'] == 'pdf' && _tvState['content'] is Map) {
      name = (_tvState['content'] as Map)['name'] as String? ?? name;
      localP ??= (_tvState['content'] as Map)['_localPdfPath'] as String?;
    }
    if (localP == null && _activeFileIndex >= 0 && _activeFileIndex < _uploadedFiles.length) {
      final f = _uploadedFiles[_activeFileIndex];
      name = f['name'] as String? ?? name;
      localP = f['localPath'] as String?;
    }
    if (_tvState['type'] != 'pdf' && localP == null) {
      _showSnack('Cast a PDF first — then control it live here!', error: true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PdfPresenterScreen(
        fileName: name,
        localPath: localP,
        initialPage: _pdfCurrentPage,
        reportedTotalPages: _pdfTotalPages,
        tvState: tvStateN,
        onGoToPage: _pdfGoToPage,
        onLogo: _castLogo,
        onBlackout: _castBlackout,
      ),
    ));
  }

  /// Casts a picked file; PDFs additionally open the live presenter screen.
  Future<void> _castFileAndPresent(int idx) async {
    final isPdf = (_uploadedFiles[idx]['type'] as String? ?? '') == 'pdf';
    await _castFile(idx);
    if (isPdf && mounted) _openPdfPresenter();
  }

  // ══════════════════ SCHEDULE DETAIL OPENER ══════════════════
  void _openScheduleDetail(int idx) {
    final scheduleState = ScheduleState.of(context);
    final songState = SongState.of(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScheduleDetailPage(
        schedule: scheduleState.schedules[idx],
        scheduleIndex: idx,
        allSongs: songState.allSongs,
        onAddSong: (songIdx) => _addSongToSchedule(idx, songIdx),
        onRemoveSong: (pos) => _removeSongFromSchedule(idx, pos),
        onPlay: () => _startSchedulePresentation(idx),
        onDelete: () {
          Navigator.pop(context);
          _deleteSchedule(idx);
        },
        onSongReorder: (oldPos, newPos) {
          setState(() {
            final songs = List<Map<String, dynamic>>.from(
                scheduleState.schedules[idx]['songs'] ?? []);
            if (oldPos < songs.length && newPos <= songs.length) {
              final item = songs.removeAt(oldPos);
              songs.insert(newPos, item);
              scheduleState.schedules[idx]['songs'] = songs;
            }
          });
          ScheduleState.of(context).saveSchedules();
        },
      ),
    ));
  }

  // ══════════════════ MODALS ══════════════════
  void _showAddSlideModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Add New Slide',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kText)),
                IconButton(
                    icon: const Icon(Icons.close, color: kMuted),
                    onPressed: () => Navigator.pop(context))
              ]),
              const SizedBox(height: 14),
              inputField(
                  _addTitleCtrl, 'Slide Title', 'e.g. Welcome to Church'),
              const SizedBox(height: 10),
              inputField(_addContentCtrl, 'Content', 'Enter slide text here...',
                  maxLines: 3),
              const SizedBox(height: 16),
              primaryBtn('Save & Cast', _addSlide),
            ]),
      ),
    );
  }

  void _showAddSongModal() {
    for (final c in _songStanzaCtrls) {
      c.dispose();
    }
    _songStanzaCtrls = [TextEditingController(), TextEditingController()];
    _songTitleCtrl.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Add New Song',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: kText)),
                          IconButton(
                              icon: const Icon(Icons.close, color: kMuted),
                              onPressed: () => Navigator.pop(context))
                        ]),
                    const SizedBox(height: 12),
                    inputField(
                        _songTitleCtrl, 'Song Title', 'e.g. Amazing Grace'),
                    const SizedBox(height: 12),
                    ...List.generate(_songStanzaCtrls.length, (i) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: kBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kBorder)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                              color: kGold.withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(5)),
                                          child: Center(
                                              child: Text('${i + 1}',
                                                  style: const TextStyle(
                                                      color: kGold,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold)))),
                                      const SizedBox(width: 8),
                                      Text('Stanza ${i + 1}',
                                          style: const TextStyle(
                                              color: kGold,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600))
                                    ]),
                                    if (_songStanzaCtrls.length > 1)
                                      GestureDetector(
                                        onTap: () {
                                          _songStanzaCtrls[i].dispose();
                                          _songStanzaCtrls.removeAt(i);
                                          setModalState(() {});
                                        },
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: Colors.red.shade900
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6)),
                                            child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.close,
                                                      size: 10,
                                                      color:
                                                          Colors.red.shade400),
                                                  SizedBox(width: 3),
                                                  Text('Remove',
                                                      style: TextStyle(
                                                          fontSize: 8,
                                                          color: Colors
                                                              .red.shade400,
                                                          fontWeight:
                                                              FontWeight.w600))
                                                ])),
                                      ),
                                  ]),
                              const SizedBox(height: 6),
                              TextField(
                                  controller: _songStanzaCtrls[i],
                                  style: const TextStyle(
                                      color: kText, fontSize: 12, height: 1.5),
                                  maxLines: 5,
                                  minLines: 3,
                                  decoration: InputDecoration(
                                      hintText:
                                          'Enter stanza ${i + 1} lyrics here...',
                                      hintStyle: const TextStyle(
                                          color: kMuted, fontSize: 11),
                                      filled: true,
                                      fillColor: kBg3,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: kGold, width: 1.5)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10))),
                            ]),
                      );
                    }),
                    GestureDetector(
                      onTap: () {
                        _songStanzaCtrls.add(TextEditingController());
                        setModalState(() {});
                      },
                      child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                              color: Colors.green.shade900.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      Colors.green.shade800.withOpacity(0.3))),
                          child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 16, color: Colors.green),
                                SizedBox(width: 6),
                                Text('Add More Stanza',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))
                              ])),
                    ),
                    const SizedBox(height: 16),
                    primaryBtn('Save Song', _addManualSong),
                  ]),
            ),
          );
        },
      ),
    );
  }

  void _showCreateScheduleModal() {
    _scheduleNameCtrl.clear();
    _scheduleDate = DateTime.now();
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Create Schedule',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: kText)),
                        IconButton(
                            icon: const Icon(Icons.close, color: kMuted),
                            onPressed: () => Navigator.pop(context))
                      ]),
                  const SizedBox(height: 12),
                  inputField(_scheduleNameCtrl, 'Schedule Name',
                      'e.g. Sunday Worship'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: _scheduleDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                          builder: (ctx, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                      primary: Colors.purple, surface: kBg2)),
                              child: child!));
                      if (picked != null)
                        setModalState(() => _scheduleDate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kBorder)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.purple),
                        const SizedBox(width: 10),
                        Text(
                            '${_scheduleDate.day}/${_scheduleDate.month}/${_scheduleDate.year}',
                            style: const TextStyle(color: kText, fontSize: 13))
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  primaryBtn(
                      'Create Schedule',
                      () => _createSchedule(_scheduleNameCtrl.text,
                          '${_scheduleDate.day}/${_scheduleDate.month}/${_scheduleDate.year}')),
                ]),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _tabController.dispose();
    _addTitleCtrl.dispose();
    _addContentCtrl.dispose();
    _songSearchCtrl.dispose();
    _songTitleCtrl.dispose();
    _scheduleNameCtrl.dispose();
    _welcomeMsgCtrl.dispose();
    _ytUrlCtrl.dispose();
    for (final c in _songStanzaCtrls) {
      c.dispose();
    }
    _dlna.removeListener(_onDlnaChanged);
    // Mark cast service as disposed FIRST so any pending native callbacks
    // (e.g. onDisconnected arriving on app close) become no-ops. Then
    // tear down the native side without awaiting — we're shutting down.
    _castService.markDisposed();
    _castService.disposeAll();
    super.dispose();
  }

  // ═══════════════════════════ BUILD ═══════════════════════════
  @override
  Widget build(BuildContext context) {
    // Full-screen presentation mode (screen mirror)
    if (_isFullScreen) {
      final content = _getFullScreenContent();
      final bgImage = _bgUrl;
      final type = _tvState['type'] as String? ?? 'idle';
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          if (bgImage != null)
            Positioned.fill(
                child: Image.network(bgImage,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.55),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          Positioned.fill(
              child: Container(
                  decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7)
          ], radius: 1.2)))),
          Center(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            // Auto-fit: text renders at the configured size when it fits and
            // scales down uniformly when a long verse would overflow, so the
            // largest readable size is always used without clipping.
            child: LayoutBuilder(builder: (ctx, box) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth),
                  child: Text(
                    content.isNotEmpty ? content : 'BiblePresenter',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: content.isEmpty ? Colors.white24 : Colors.white,
                        fontSize: content.isEmpty
                            ? 20
                            : (BibleState.of(context).fontSize.toDouble() * 0.9),
                        fontWeight: FontWeight.w600,
                        height: 1.8,
                        shadows: [
                          Shadow(
                              color: Colors.black.withOpacity(0.9),
                              blurRadius: 20)
                        ]),
                  ),
                ),
              );
            }),
          )),
          if (!_showFullScreenControls)
            Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                    child: GestureDetector(
                  onTap: () => setState(() => _showFullScreenControls = true),
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white24, width: 1)),
                      child: const Icon(Icons.keyboard_arrow_up,
                          color: Colors.white54, size: 22)),
                ))),
          if (_showFullScreenControls)
            Positioned(
              bottom: 20,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF0a0f1e).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFF1a2d45), width: 1.5)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: kAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8)),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                  type == 'verse'
                                      ? Icons.menu_book
                                      : type == 'slide'
                                          ? Icons.slideshow
                                          : type == 'song'
                                              ? Icons.music_note
                                              : type == 'logo'
                                                  ? Icons.image
                                                  : type == 'pdf'
                                                      ? Icons.picture_as_pdf
                                                      : type == 'welcome'
                                                          ? Icons.waving_hand
                                                          : Icons.tv,
                                  size: 14,
                                  color: kAccent),
                              const SizedBox(width: 6),
                              Text(type.toUpperCase(),
                                  style: const TextStyle(
                                      color: kAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1))
                            ])),
                        GestureDetector(
                            onTap: () =>
                                setState(() => _showFullScreenControls = false),
                            child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.keyboard_arrow_down,
                                    color: Colors.white54, size: 18))),
                        GestureDetector(
                            onTap: _toggleFullScreen,
                            child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: Colors.red.shade900.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.close,
                                    color: Colors.red, size: 16))),
                      ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: GestureDetector(
                            onTap: _clearScreen,
                            child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.red.shade900.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.red.shade800
                                            .withOpacity(0.4))),
                                child: const Center(
                                    child: Text('Blackout',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)))))),
                    const SizedBox(width: 6),
                    Expanded(
                        child: GestureDetector(
                            onTap: _castWelcome,
                            child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                    color:
                                        Colors.green.shade900.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.green.shade800
                                            .withOpacity(0.4))),
                                child: const Center(
                                    child: Text('Welcome',
                                        style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)))))),
                    const SizedBox(width: 6),
                    Expanded(
                        child: GestureDetector(
                            onTap: _castLogo,
                            child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                    color: kGold.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: kGold.withOpacity(0.3))),
                                child: const Center(
                                    child: Text('Logo',
                                        style: TextStyle(
                                            color: kGold,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)))))),
                  ]),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: GestureDetector(
                              onTap: () {
                                if (type == 'verse')
                                  _prevVerse();
                                else if (type == 'slide' && _activeSlide > 0)
                                  _castSlide(_activeSlide - 1);
                                else if (type == 'song')
                                  _prevStanza();
                                else if (type == 'pdf') _pdfPrevPage();
                              },
                              child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                      color: kBorder,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Center(
                                      child: Text('Prev',
                                          style: TextStyle(
                                              color: kText,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)))))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: GestureDetector(
                              onTap: () {
                                if (type == 'verse')
                                  _castVerse();
                                else if (type == 'slide')
                                  _castSlide(_activeSlide);
                                else if (type == 'song') _castSong();
                              },
                              child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                      color: kAccent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                            color: kAccent.withOpacity(0.3),
                                            blurRadius: 8)
                                      ]),
                                  child: const Center(
                                      child: Text('Cast',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)))))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: GestureDetector(
                              onTap: () {
                                if (type == 'verse')
                                  _nextVerse();
                                else if (type == 'slide' &&
                                    _activeSlide < _slides.length - 1)
                                  _castSlide(_activeSlide + 1);
                                else if (type == 'song')
                                  _nextStanza();
                                else if (type == 'pdf') _pdfNextPage();
                              },
                              child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                      color: kBorder,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Center(
                                      child: Text('Next',
                                          style: TextStyle(
                                              color: kText,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)))))),
                    ],
                  ),
                ]),
              ),
            ),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // Header (AppBar + TabBar) — always visible so tabs are always accessible.
          _buildAppBar(),
          _buildTabBar(),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: TabBarView(
            controller: _tabController,
            children: [
              SlidesTab(
                  slides: _slides,
                  activeSlide: _activeSlide,
                  onCastSlide: _castSlide,
                  onDeleteSlide: _deleteSlide,
                  onShowAddSlideModal: _showAddSlideModal,
                  onOpenFullscreen: _openSlidesFullscreen),
              Consumer<BibleState>(
                builder: (context, bible, _) => BibleTab(
                    bible: bible.bible,
                    bibleLoaded: bible.bibleLoaded,
                    selBook: bible.selectedBook,
                    selChapter: bible.selectedChapter,
                    selVerse: bible.selectedVerse,
                    fontSize: bible.fontSize,
                    languages: bible.languages,
                    primaryLang: bible.primaryLang,
                    secondaryLang: bible.secondaryLang,
                    importingLanguage: _importingBible,
                    onBookChanged: (val) => bible.selectedBook = val,
                    onChapterChanged: (val) => bible.selectedChapter = val,
                    onVerseChanged: (val) => bible.selectedVerse = val,
                    onPrimaryLangChanged: (val) => bible.primaryLang = val,
                    onSecondaryLangChanged: (val) => bible.secondaryLang = val,
                    onImportLanguage: _importBibleLanguage,
                    onCastVerse: _openBiblePresenter,
                    onPrevVerse: _prevVerse,
                    onNextVerse: _nextVerse,
                    onFontSizeChanged: (v) => bible.fontSize = v,
                    onOpenFullscreen: _openBiblePresenter),
              ),
              Consumer2<SongState, ScheduleState>(
                builder: (context, songs, schedules, _) => SongsTab(
                    allSongs: songs.allSongs,
                    filteredSongs: songs.filteredSongs,
                    songsLoaded: songs.songsLoaded,
                    songSearchQuery: songs.songSearchQuery,
                    selectedSongIndex: songs.selectedSongIndex,
                    selectedStanzaIndex: songs.selectedStanzaIndex,
                    songSearchCtrl: songs.songSearchController,
                    importingWord: _importingSongWord,
                    onFilterSongs: (query) => songs.songSearchQuery = query,
                    onShowAddSongModal: _showAddSongModal,
                    onShowCreateScheduleModal: _showCreateScheduleModal,
                    onImportWord: _importSongWord,
                    onExportWord: _exportSongWord,
                    onEditSlides: _openSongSlideEditor,
                    onDeleteSong: _deleteSong,
                    onSelectSong: (i) => _openSongPresenter(index: i),
                    onSelectStanza: (i) {
                      songs.selectedStanzaIndex = i;
                      _castSong();
                    },
                    onCastSong: _openSongPresenter,
                    onPrevStanza: _prevStanza,
                    onNextStanza: _nextStanza,
                    onOpenFullscreen: _openSongPresenter,
                    schedules: schedules.schedules,
                    scheduleMode: schedules.scheduleMode,
                    activeScheduleIndex: schedules.activeScheduleIndex,
                    onOpenScheduleDetail: _openScheduleDetail,
                    onDeleteSchedule: _deleteSchedule,
                    onStartSchedulePresentation: _startSchedulePresentation),
              ),
              FilesTab(
                  uploadedFiles: _uploadedFiles,
                  isUploading: _isUploading,
                  activeFileIndex: _activeFileIndex,
                  tvState: _tvState,
                  pdfCurrentPage: _pdfCurrentPage,
                  pdfTotalPages: _pdfTotalPages,
                  onPickAndUploadFile: _pickAndUploadFile,
                  onCastFile: _castFileAndPresent,
                  onDeleteFile: _deleteUploadedFile,
                  onPdfPrevPage: _pdfPrevPage,
                  onPdfNextPage: _pdfNextPage,
                  onOpenFullscreen: _openPdfPresenter,
                  onPdfTotalPagesKnown: (t) {
                    if (mounted && _pdfTotalPages != t) {
                      setState(() => _pdfTotalPages = t);
                    }
                  },
                  videoPosition: _videoPosition,
                  videoDuration: _videoDuration,
                  videoPlaying: _videoPlaying,
                  videoMuted: _videoMutedByBrowser,
                  videoFinished: _videoFinished,
                  onVideoPlayPause: _videoPlayPause,
                  onVideoSeek: _videoSeekTo,
                  onVideoStop: _videoStop,
                  onVideoUnmute: _videoUnmute,
                  ytUrlCtrl: _ytUrlCtrl,
                  ytQueue: _ytQueue,
                  ytQueueIndex: _ytQueueIndex,
                  ytPosition: _ytPosition,
                  ytDuration: _ytDuration,
                  ytVolume: _ytVolumeVal,
                  ytPlaying: _ytPlaying,
                  onCastYouTubeUrl: _castYouTubeUrl,
                  onYtPlayPause: _ytPlayPause,
                  onYtSeek: _ytSeekTo,
                  onYtVolume: _ytVolume,
                  onYtStop: _ytStop,
                  onYtRemoveFromQueue: _ytRemoveFromQueue),
              Consumer<BibleState>(
                builder: (context, bible, _) => SettingsTab(
                    fontSize: bible.fontSize,
                    onFontSizeChanged: (v) => bible.fontSize = v,
                    welcomeMessage: _welcomeMessage,
                    welcomeMsgCtrl: _welcomeMsgCtrl,
                    onWelcomeMessageChanged: (val) async {
                      setState(() => _welcomeMessage = val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('welcome_message', val);
                    },
                    onCastWelcome: _castWelcome,
                    onClearScreen: _clearScreen,
                    customLogoPath: _customLogoPath,
                    onUploadCustomLogo: _uploadCustomLogo,
                    onRemoveCustomLogo: () async {
                      final confirmed = await _confirmDelete('custom logo');
                      if (!confirmed) return;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('custom_logo_base64');
                      setState(() => _customLogoPath = '');
                      _showSnack('Custom logo removed');
                    },
                    onCastLogo: _castLogo,
                    bgUrl: _bgUrl,
                    onBgUrlChanged: (url) async {
                      setState(() => _bgUrl = url);
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        if (url != null) {
                          await prefs.setString('current_bg_url', url);
                        } else {
                          await prefs.remove('current_bg_url');
                        }
                      } catch (_) {}
                      if (url != null)
                        _emit('update-background', {'url': url});
                      else
                        _emit('update-background', {});
                    },
                    isUploadingBg: _isUploadingBg,
                    onUploadBgImage: _uploadBgImage,
                    uploadedBgs: _uploadedBgs,
                    onDeleteUploadedBg: _deleteUploadedBg,
                    serverStarted: _serverStarted,
                    connected: _connected,
                    deviceIp: _deviceIp,
                    onRefreshIp: _refreshIp,
                    onConnectWS: _connectWS,
                    onCopyUrl: _copyUrl),
              ),
            ],
          ),
              ),
            ),
            // Bottom chrome (DLNA banner + URL bar) — collapses on scroll-down
            // or Focus Mode to maximize the content stage.
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _chromeVisible
                    ? Column(children: [_dlnaBanner(), _bottomUrlBar()])
                    : _chromeStrip(showBottomHandle: true),
              ),
            ),
          ]),
        ),
      );
    }

  // ══════════════════ COLLAPSIBLE CHROME / FOCUS MODE ══════════════════

  void _showChrome() {
    if (mounted) {
      setState(() {
        _chromeVisible = true;
        _focusMode = false;
        _scrollHideAccum = 0;
      });
    }
  }

  void _hideChrome({bool focus = false}) {
    if (mounted) {
      setState(() {
        _chromeVisible = false;
        _focusMode = focus;
        _scrollHideAccum = 0;
      });
    }
  }

  /// One-tap manual toggle from the bottom bar: locks the UI into a
  /// distraction-free full-height workspace. Scroll-up restore is ignored
  /// while locked; the floating CONTROLS pill exits.
  void _toggleFocusMode() {
    if (_chromeVisible) {
      _hideChrome(focus: true);
      _showSnack('Bottom bar hidden — tap bottom strip to restore');
    } else {
      _showChrome();
    }
  }

  /// Scroll-driven auto-hide: any vertical list (songs, Bible chapters,
  /// slides, files) collapsing both bars when scrolling down and restoring
  /// them when scrolling up. Threshold 48px avoids jitter on slow drags.
  bool _onScrollNotification(ScrollNotification n) {
    if (_focusMode) return false;
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is UserScrollNotification) {
      _scrollHideAccum = 0;
      if (n.direction == ScrollDirection.reverse && _chromeVisible) {
        _hideChrome();
      } else if (n.direction == ScrollDirection.forward && !_chromeVisible) {
        _showChrome();
      }
    } else if (n is ScrollUpdateNotification) {
      _scrollHideAccum += n.scrollDelta ?? 0;
      if (_scrollHideAccum > 48 && _chromeVisible) {
        _hideChrome();
      } else if (_scrollHideAccum < -48 && !_chromeVisible) {
        _showChrome();
      }
    }
    return false;
  }

  /// Thin tap strip shown in place of a hidden chrome group.
  Widget _chromeStrip({required bool showBottomHandle}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showChrome,
        child: Container(
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kBg2,
            border: Border(
                top: BorderSide(color: kBorder),
                bottom: BorderSide(color: kBorder)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(showBottomHandle ? Icons.expand_less : Icons.expand_more,
                size: 13, color: kMuted),
            const SizedBox(width: 6),
            const Text('TAP TO SHOW CONTROLS',
                style: TextStyle(
                    color: kMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ]),
        ),
      );

  /// Floating pill (top-right) that restores the bars when hidden.
  Widget _focusExitPill() => Material(
        color: kBg2.withOpacity(0.94),
        shape: StadiumBorder(
            side: BorderSide(color: kAccent.withOpacity(0.5))),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _showChrome,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.center_focus_weak, size: 14, color: kAccent),
              SizedBox(width: 6),
              Text('CONTROLS',
                  style: TextStyle(
                      color: kText,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
            ]),
          ),
        ),
      );

  /// Persistent connection surface above the URL bar (plan 9.1/9.3):
  /// connected chip, disconnect banner with one-tap reconnect, or the
  /// last-TV reconnect offer.
  Widget _dlnaBanner() {
    if (_dlna.isConnected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        color: Colors.green.withOpacity(0.18),
        child: Row(children: [
          // Glowing greenAccent indicator — readable on any dark surface.
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.8),
                    blurRadius: 6,
                    spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TV Direct · ${_dlna.connectedName}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
              Text(
                  'Slide changes take about a second on TV Direct — Browser Connect is instant',
                  style: TextStyle(
                      color: Colors.greenAccent.shade100, fontSize: 9),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          GestureDetector(
            onTap: () async {
              await _dlna.disconnect();
              if (mounted) _showSnack('TV Direct disconnected');
            },
            child: const Icon(Icons.close,
                size: 15, color: Colors.white70),
          ),
        ]),
      );
    }
    if (_dlna.rendererOffline) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        color: Colors.red.shade900.withOpacity(0.35),
        child: Row(children: [
          const Icon(Icons.wifi_off, size: 13, color: Colors.white),
          const SizedBox(width: 7),
          const Expanded(
            child: Text('TV disconnected — check Wi-Fi or Reconnect',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          GestureDetector(
            onTap: _reconnectFromBanner,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.9), width: 1)),
              child: const Text('Reconnect',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      );
    }
    if (_reconnectUdn.isNotEmpty && !_dlna.isConnected) {
      return GestureDetector(
        onTap: _reconnectFromBanner,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.green.withOpacity(0.15),
          child: Row(children: [
            const Icon(Icons.history, size: 13, color: Colors.greenAccent),
            const SizedBox(width: 7),
            Expanded(
              child: Text('Cast to $_reconnectName — tap to connect',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.chevron_right,
                size: 15, color: Colors.greenAccent),
          ]),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: kBg2,
        elevation: 0,
        titleSpacing: 12,
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kAccent, Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.cast, size: 16, color: Colors.white)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('BiblePresenter',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: kText)),
            Row(children: [
              Icon(Icons.circle,
                  size: 6, color: _connected ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(
                  _serverStarted
                      ? (_connected ? 'Server live' : 'Connecting...')
                      : 'Starting server...',
                  style: TextStyle(
                      fontSize: 9, color: _connected ? Colors.green : kMuted)),
              if (_tvState['type'] != null && _tvState['type'] != 'idle') ...[
                const SizedBox(width: 8),
                Icon(
                    _tvState['type'] == 'verse'
                        ? Icons.menu_book
                        : _tvState['type'] == 'slide'
                            ? Icons.slideshow
                            : _tvState['type'] == 'song'
                                ? Icons.music_note
                                : _tvState['type'] == 'pdf'
                                    ? Icons.picture_as_pdf
                                    : _tvState['type'] == 'pptx'
                                        ? Icons.slideshow
                                        : _tvState['type'] == 'logo'
                                            ? Icons.image
                                            : _tvState['type'] == 'welcome'
                                                ? Icons.waving_hand
                                                : Icons.cast,
                    size: 10,
                    color: kAccent),
                const SizedBox(width: 2),
                Text(
                    _tvState['type'] == 'verse'
                        ? 'Verse'
                        : _tvState['type'] == 'slide'
                            ? 'Slide'
                            : _tvState['type'] == 'song'
                                ? 'Song'
                                : _tvState['type'] == 'pdf'
                                    ? 'PDF'
                                    : _tvState['type'] == 'pptx'
                                        ? 'PPT'
                                        : _tvState['type'] == 'logo'
                                            ? 'Logo'
                                            : _tvState['type'] == 'welcome'
                                                ? 'Welcome'
                                                : '',
                    style: const TextStyle(
                        color: kAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ],
            ]),
          ]),
        ]),
        actions: [
          IconButton(
              onPressed: _castWelcome,
              icon: Icon(Icons.waving_hand,
                  size: 18, color: Colors.green.shade400),
              tooltip: 'Welcome',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
          IconButton(
              onPressed: _castLogo,
              icon:
                  Image.asset('assets/church_logo.png', width: 18, height: 18),
              tooltip: 'Church Logo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
          IconButton(
              onPressed: _clearScreen,
              icon: Icon(Icons.dark_mode, size: 18, color: Colors.red.shade300),
              tooltip: 'Blackout',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
          const SizedBox(width: 4),
        ],
      );

  Widget _buildTabBar() => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF080f1e),
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: kAccent,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: kAccent,
          unselectedLabelColor: kMuted,
          splashFactory: InkRipple.splashFactory,
          labelStyle: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(icon: Icon(Icons.slideshow, size: 16), text: 'SLIDES'),
            Tab(icon: Icon(Icons.menu_book, size: 16), text: 'BIBLE'),
            Tab(icon: Icon(Icons.music_note, size: 16), text: 'SONGS'),
            Tab(icon: Icon(Icons.upload_file, size: 16), text: 'FILES'),
            Tab(icon: Icon(Icons.tune, size: 16), text: 'SETTINGS'),
          ],
        ),
      );

  Widget _bottomUrlBar() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
            color: kBg2, border: Border(top: BorderSide(color: kBorder))),
        child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.wifi, size: 13, color: kAccent),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('http://$_deviceIp:${SlideRenderer.serverPort}/tv.html',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: kAccent,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.visible,
                        maxLines: 1,
                        softWrap: false)),
                const SizedBox(width: 6),
                Material(
                    color: Colors.transparent,
                    child: InkWell(
                        onTap: _refreshIp,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                                color: kAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.refresh,
                                size: 14, color: kAccent)))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _barBtn(Icons.tv, 'Cast to TV', _showCastDialog)),
                const SizedBox(width: 8),
                // Quick-cast indicator for Chromecast/AirPlay connection status
                CastButton(
                    castService: _castService,
                    tvUrl:
                        'http://${_deviceIp == '...' ? '' : _deviceIp}:${SlideRenderer.serverPort}/tv.html'),
                const SizedBox(width: 8),
                Expanded(child: _barBtn(Icons.copy, 'Copy URL', _copyUrl)),
                const SizedBox(width: 8),
                // Manual Focus Mode: full-height distraction-free stage.
                Tooltip(
                    message: 'Focus Mode — hide top & bottom bars',
                    child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                            onTap: _toggleFocusMode,
                            borderRadius: BorderRadius.circular(10),
                            child: Ink(
                                height: 42,
                                width: 44,
                                decoration: BoxDecoration(
                                    color: kAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: kAccent.withValues(alpha: 0.4))),
                                child: const Icon(Icons.center_focus_strong,
                                    size: 18, color: kAccent))))),
              ]),
            ])),
      );

  Widget _barBtn(IconData icon, String text, VoidCallback onTap) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            height: 42,
            decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAccent.withValues(alpha: 0.4))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 14, color: kAccent),
              const SizedBox(width: 6),
              Text(text,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: kAccent)),
            ]),
          ),
        ),
      );
}
