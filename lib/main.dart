import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'server.dart';
import 'theme.dart';
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
import 'services/cast_api.g.dart';
import 'widgets/cast_button.dart';

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
  Widget build(BuildContext context) => MaterialApp(
    title: 'BiblePresenter',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(primary: kAccent, surface: kBg2),
    ),
    home: const ControllerPage(),
  );
}

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});
  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> with TickerProviderStateMixin {
  // ── Server / WS state ──
  WebSocketChannel? _channel;
  bool _connected = false;
  bool _serverStarted = false;
  String _deviceIp = '...';
  Map<String, dynamic> _tvState = {'type': 'idle'};

  // ── WS reconnection ──
  Timer? _reconnectTimer;
  int _reconnectDelay = 2;
  static const int _maxReconnectDelay = 15;

  // ── Tab ──
  late TabController _tabController;
  int _activeTab = 0;

  // ── Bible state ──
  Map<String, Map<int, Map<int, Map<String, String>>>> _bible = {};
  bool _bibleLoaded = false;
  String _selBook = 'Psalms';
  int _selChapter = 23;
  int _selVerse = 1;

  // ── Slides state ──
  List<Map<String, String>> _slides = List.from(defaultSlides);
  int _activeSlide = 0;

  // ── Settings ──
  int _fontSize = 44;
  String? _bgUrl;
  final _addTitleCtrl   = TextEditingController();
  final _addContentCtrl = TextEditingController();

  // ── Files state ──
  List<Map<String, dynamic>> _uploadedFiles = [];
  bool _isUploading = false;
  int _pdfCurrentPage = 1;
  int _pdfTotalPages = 0;
  int _activeFileIndex = -1;
  String _currentlyCastUrl = '';

  // ── Uploaded backgrounds ──
  List<Map<String, String>> _uploadedBgs = [];
  bool _isUploadingBg = false;

  // ── Songs state ──
  List<Map<String, dynamic>> _allSongs = [];
  List<Map<String, dynamic>> _filteredSongs = [];
  bool _songsLoaded = false;
  String _songSearchQuery = '';
  int _selectedSongIndex = -1;
  int _selectedStanzaIndex = 0;
  final _songSearchCtrl = TextEditingController();
  final _songTitleCtrl = TextEditingController();
  List<TextEditingController> _songStanzaCtrls = [TextEditingController(), TextEditingController()];

  // ── Song Schedule state ──
  List<Map<String, dynamic>> _schedules = [];
  int _activeScheduleIndex = -1;
  int _scheduleSongIndex = 0;
  int _scheduleStanzaIndex = 0;
  bool _scheduleMode = false;
  final _scheduleNameCtrl = TextEditingController();
  DateTime _scheduleDate = DateTime.now();

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this)
      ..addListener(() => setState(() => _activeTab = _tabController.index));
    // Register the Pigeon Flutter API handler so native → Flutter callbacks work
    CastFlutterApi.setUp(_castService);
    _boot();
  }

  // ══════════════════ BOOT SEQUENCE ══════════════════
  Future<void> _boot() async {
    await _loadBibleFromAssets();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final uploadPath = '${appDir.path}/biblepresenter_uploads';
      await Isolate.spawn(startServer, uploadPath);
    } catch (e) {
      print('[BiblePresenter] Isolate.spawn failed: $e');
    }
    setState(() => _serverStarted = true);

    bool serverReady = false;
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final socket = await WebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:3000/ws'),
        ).ready.timeout(const Duration(seconds: 2));
        serverReady = true;
        break;
      } catch (_) {
        print('[BiblePresenter] Waiting for server... attempt ${i + 1}');
      }
    }

    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null && mounted) setState(() => _deviceIp = ip);
    } catch (_) {}

    _connectWS();
    _reloadUploadedFiles();
    _loadSongs();
    _loadSchedules();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLogo = prefs.getString('custom_logo_base64') ?? '';
      if (savedLogo.isNotEmpty && mounted) setState(() => _customLogoPath = savedLogo);
      final savedMsg = prefs.getString('welcome_message') ?? '';
      if (savedMsg.isNotEmpty && mounted) {
        setState(() { _welcomeMessage = savedMsg; _welcomeMsgCtrl.text = savedMsg; });
      }
    } catch (_) {}
  }

  // ══════════════════ CONFIRM DELETE DIALOG ══════════════════
  Future<bool> _confirmDelete(String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400, size: 24),
          const SizedBox(width: 10),
          const Text('Confirm Delete', style: TextStyle(color: kText, fontSize: 16)),
        ]),
        content: Text('Are you sure you want to delete "$itemName"?\nThis action cannot be undone.',
          style: const TextStyle(color: kMuted, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: kMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(backgroundColor: Colors.red.shade900.withOpacity(0.2)),
            child: Text('Delete', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
    return confirmed;
  }

  // ══════════════════ IP REFRESH ══════════════════
  Future<void> _refreshIp() async {
    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null && mounted) { setState(() => _deviceIp = ip); _showSnack('IP refreshed: $ip'); }
      else { _showSnack('Could not get WiFi IP', error: true); }
    } catch (e) { _showSnack('IP refresh error', error: true); }
  }

  // ══════════════════ LOAD BIBLE ══════════════════
  Future<void> _loadBibleFromAssets() async {
    try {
      final enJsonStr = await rootBundle.loadString('assets/bible_en.json');
      final enData = jsonDecode(enJsonStr) as Map<String, dynamic>;
      final hiJsonStr = await rootBundle.loadString('assets/bible_hi.json');
      final hiData = jsonDecode(hiJsonStr) as Map<String, dynamic>;
      final Map<String, Map<int, Map<int, Map<String, String>>>> bible = {};

      for (final bookEntry in enData.entries) {
        final bookName = bookEntry.key;
        final chapters = bookEntry.value as Map<String, dynamic>;
        bible[bookName] = {};
        for (final chapterEntry in chapters.entries) {
          final chapterNum = int.tryParse(chapterEntry.key) ?? 0;
          final verses = chapterEntry.value as Map<String, dynamic>;
          bible[bookName]![chapterNum] = {};
          for (final verseEntry in verses.entries) {
            final verseNum = int.tryParse(verseEntry.key) ?? 0;
            bible[bookName]![chapterNum]![verseNum] = {'en': verseEntry.value.toString(), 'hi': ''};
          }
        }
      }

      for (final bookEntry in hiData.entries) {
        final bookName = bookEntry.key;
        final chapters = bookEntry.value as Map<String, dynamic>;
        if (!bible.containsKey(bookName)) bible[bookName] = {};
        for (final chapterEntry in chapters.entries) {
          final chapterNum = int.tryParse(chapterEntry.key) ?? 0;
          final verses = chapterEntry.value as Map<String, dynamic>;
          if (!bible[bookName]!.containsKey(chapterNum)) bible[bookName]![chapterNum] = {};
          for (final verseEntry in verses.entries) {
            final verseNum = int.tryParse(verseEntry.key) ?? 0;
            if (bible[bookName]![chapterNum]!.containsKey(verseNum)) {
              bible[bookName]![chapterNum]![verseNum]!['hi'] = verseEntry.value.toString();
            } else {
              bible[bookName]![chapterNum]![verseNum] = {'en': '', 'hi': verseEntry.value.toString()};
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _bible = bible;
          _bibleLoaded = true;
          if (_bible.isNotEmpty) { _selBook = _bible.keys.first; _selChapter = _bible[_selBook]!.keys.first; _selVerse = _bible[_selBook]![_selChapter]!.keys.first; }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bible = _fallbackBible();
          _bibleLoaded = true;
          if (_bible.isNotEmpty) { _selBook = _bible.keys.first; _selChapter = _bible[_selBook]!.keys.first; _selVerse = _bible[_selBook]![_selChapter]!.keys.first; }
        });
      }
    }
  }

  Map<String, Map<int, Map<int, Map<String, String>>>> _fallbackBible() {
    return {
      'Psalms': { 23: { 1: {'en': 'The Lord is my shepherd; I shall not want.', 'hi': 'यहोवा मेरा चरवाहा है, मुझे कोई घटी न होगी।'}, 2: {'en': 'He maketh me to lie down in green pastures.', 'hi': 'वह मुझे हरी हरी चराइयों में बैठाता है।'}, 4: {'en': 'Yea, though I walk through the valley of the shadow of death, I will fear no evil.', 'hi': 'चाहे मैं मृत्यु की छाया की तराई में भी चलूं, मैं किसी विपत्ति से न डरूंगा।'}, 6: {'en': 'Surely goodness and mercy shall follow me all the days of my life.', 'hi': 'निश्चय भलाई और करुणा मेरे जीवन भर मेरे साथ रहेंगी।'}, }, 119: {105: {'en': 'Thy word is a lamp unto my feet, and a light unto my path.', 'hi': 'तेरा वचन मेरे पांव के लिये दीपक, और मेरे मार्ग के लिये प्रकाश है।'}}, },
      'John': { 3: {16: {'en': 'For God so loved the world, that he gave his only begotten Son.', 'hi': 'क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उस ने अपना एकलौता पुत्र दे दिया।'}}, 14: {6: {'en': 'I am the way, the truth, and the life.', 'hi': 'मार्ग और सत्य और जीवन मैं ही हूं।'}}, },
      'Romans': { 8: {28: {'en': 'All things work together for good to them that love God.', 'hi': 'जो लोग परमेश्वर से प्रेम रखते हैं उनके लिये सब बातें मिलकर भलाई ही को उत्पन्न करती हैं।'}}, },
      'Philippians': { 4: {13: {'en': 'I can do all things through Christ which strengtheneth me.', 'hi': 'मैं मसीह के द्वारा जो मुझे सामर्थ देता है सब कुछ कर सकता हूं।'}}, },
    };
  }

  // ══════════════════ RELOAD UPLOADED FILES ══════════════════
  Future<void> _reloadUploadedFiles() async {
    try {
      final uri = Uri.parse('http://127.0.0.1:3000/api/uploads');
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
          final fullUrl = 'http://$ip:3000$url';
          if (type == 'image') { reloadedBgs.add({'name': name, 'url': fullUrl}); }
          else { reloadedFiles.add({'name': name, 'url': url, 'type': type, 'size': size, 'localPath': '', 'previewBytes': null}); }
        }
        if (mounted) { setState(() { _uploadedBgs = reloadedBgs; _uploadedFiles = reloadedFiles; }); }
      }
    } catch (_) {}
  }

  // ══════════════════ LOAD SONGS ══════════════════
  Future<void> _loadSongs() async {
    try {
      final songsJsonStr = await rootBundle.loadString('assets/songs.json');
      final List<dynamic> assetSongs = jsonDecode(songsJsonStr) as List<dynamic>;
      final List<Map<String, dynamic>> songs = [];
      for (final s in assetSongs) { songs.add({'title': s['title'] as String? ?? '', 'stanzas': List<String>.from(s['stanzas'] as List? ?? []), 'source': 'asset'}); }
      try {
        final prefs = await SharedPreferences.getInstance();
        final manualSongsStr = prefs.getString('manual_songs') ?? '[]';
        final List<dynamic> manualSongs = jsonDecode(manualSongsStr) as List<dynamic>;
        for (final s in manualSongs) { songs.add({'title': s['title'] as String? ?? '', 'stanzas': List<String>.from(s['stanzas'] as List? ?? []), 'source': 'manual'}); }
      } catch (_) {}
      if (mounted) { setState(() { _allSongs = songs; _filteredSongs = List.from(songs); _songsLoaded = true; }); }
    } catch (_) {
      if (mounted) { setState(() { _allSongs = []; _filteredSongs = []; _songsLoaded = true; }); }
    }
  }

  void _filterSongs(String query) {
    setState(() {
      _songSearchQuery = query.toLowerCase().trim();
      if (_songSearchQuery.isEmpty) { _filteredSongs = List.from(_allSongs); }
      else {
        _filteredSongs = _allSongs.where((song) {
          final title = (song['title'] as String? ?? '').toLowerCase();
          if (title.contains(_songSearchQuery)) return true;
          final stanzas = song['stanzas'] as List<String>? ?? [];
          for (final stanza in stanzas) { if (stanza.toLowerCase().contains(_songSearchQuery)) return true; }
          return false;
        }).toList();
      }
    });
  }

  Future<void> _saveManualSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final manualSongs = _allSongs.where((s) => s['source'] == 'manual').toList();
      await prefs.setString('manual_songs', jsonEncode(manualSongs));
    } catch (_) {}
  }

  void _addManualSong() {
    final title = _songTitleCtrl.text.trim();
    if (title.isEmpty) return;
    final stanzas = _songStanzaCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (stanzas.isEmpty) return;
    setState(() {
      _allSongs.insert(0, {'title': title, 'stanzas': stanzas, 'source': 'manual'});
      _filteredSongs = List.from(_allSongs);
      _selectedSongIndex = 0;
      _selectedStanzaIndex = 0;
    });
    _songTitleCtrl.clear();
    for (final c in _songStanzaCtrls) { c.clear(); }
    _songStanzaCtrls = [TextEditingController(), TextEditingController()];
    Navigator.pop(context);
    _saveManualSongs();
    _showSnack('Song "$title" added!');
  }

  void _deleteSong(int idx) {
    final song = _allSongs[idx];
    if (song['source'] != 'manual') return;
    _confirmDelete(song['title'] as String? ?? 'this song').then((confirmed) {
      if (!confirmed) return;
      setState(() {
        _allSongs.removeAt(idx);
        _filteredSongs = List.from(_allSongs);
        if (_selectedSongIndex >= _allSongs.length) _selectedSongIndex = _allSongs.length - 1;
        if (_selectedSongIndex < 0) _selectedSongIndex = -1;
      });
      _saveManualSongs();
      _showSnack('Song deleted');
    });
  }

  // ══════════════════ SCHEDULE METHODS ══════════════════
  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('song_schedules') ?? '[]';
      final List<dynamic> data = jsonDecode(str) as List<dynamic>;
      if (mounted) setState(() { _schedules = data.cast<Map<String, dynamic>>(); });
    } catch (_) {}
  }

  Future<void> _saveSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('song_schedules', jsonEncode(_schedules));
    } catch (_) {}
  }

  void _createSchedule(String name, String dateStr) {
    if (name.trim().isEmpty) return;
    setState(() {
      _schedules.insert(0, {'name': name.trim(), 'date': dateStr, 'songs': <Map<String, dynamic>>[]});
      _activeScheduleIndex = 0;
    });
    _scheduleNameCtrl.clear();
    Navigator.pop(context);
    _saveSchedules();
    _showSnack('Schedule "$name" created!');
  }

  void _addSongToSchedule(int scheduleIdx, int songIdx) {
    if (scheduleIdx < 0 || scheduleIdx >= _schedules.length) return;
    if (songIdx < 0 || songIdx >= _allSongs.length) return;
    final song = _allSongs[songIdx];
    setState(() {
      final songs = List<Map<String, dynamic>>.from(_schedules[scheduleIdx]['songs'] ?? []);
      songs.add({'title': song['title'] ?? '', 'stanzas': List<String>.from(song['stanzas'] ?? []), 'songIndex': songIdx});
      _schedules[scheduleIdx]['songs'] = songs;
    });
    _saveSchedules();
    _showSnack('Song added to schedule!');
  }

  void _removeSongFromSchedule(int scheduleIdx, int songPosition) {
    if (scheduleIdx < 0 || scheduleIdx >= _schedules.length) return;
    setState(() {
      final songs = List<Map<String, dynamic>>.from(_schedules[scheduleIdx]['songs'] ?? []);
      if (songPosition < songs.length) { songs.removeAt(songPosition); _schedules[scheduleIdx]['songs'] = songs; }
    });
    _saveSchedules();
  }

  void _deleteSchedule(int idx) {
    _confirmDelete(_schedules[idx]['name'] as String? ?? 'this schedule').then((confirmed) {
      if (!confirmed) return;
      setState(() {
        _schedules.removeAt(idx);
        if (_activeScheduleIndex >= _schedules.length) _activeScheduleIndex = _schedules.length - 1;
        if (_activeScheduleIndex < 0) _activeScheduleIndex = -1;
        _scheduleMode = false;
      });
      _saveSchedules();
      _showSnack('Schedule deleted');
    });
  }

  void _startSchedulePresentation(int scheduleIdx) {
    if (scheduleIdx < 0 || scheduleIdx >= _schedules.length) return;
    final songs = _schedules[scheduleIdx]['songs'] as List? ?? [];
    if (songs.isEmpty) { _showSnack('No songs in this schedule!', error: true); return; }
    setState(() { _scheduleMode = true; _activeScheduleIndex = scheduleIdx; _scheduleSongIndex = 0; _scheduleStanzaIndex = 0; });
    _castScheduleSong();
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false, barrierDismissible: false,
      pageBuilder: (_, __, ___) => ScheduleFullscreen(
        scheduleName: _schedules[scheduleIdx]['name'] ?? '',
        scheduleDate: _schedules[scheduleIdx]['date'] ?? '',
        songs: _schedules[scheduleIdx]['songs'] as List? ?? [],
        currentSongIndex: _scheduleSongIndex,
        currentStanzaIndex: _scheduleStanzaIndex,
        fontSize: _fontSize,
        onPrev: _schedulePrev,
        onNext: _scheduleNext,
        onCast: _castScheduleSong,
        onJumpToSong: (songIdx) { setState(() { _scheduleSongIndex = songIdx; _scheduleStanzaIndex = 0; }); _castScheduleSong(); },
        onExit: () { _exitScheduleMode(); },
        getState: () => {'songIndex': _scheduleSongIndex, 'stanzaIndex': _scheduleStanzaIndex},
      ),
    ));
  }

  void _castScheduleSong() {
    if (_activeScheduleIndex < 0 || _activeScheduleIndex >= _schedules.length) return;
    final songs = _schedules[_activeScheduleIndex]['songs'] as List? ?? [];
    if (_scheduleSongIndex < 0 || _scheduleSongIndex >= songs.length) return;
    final song = songs[_scheduleSongIndex];
    final stanzas = List<String>.from(song['stanzas'] ?? []);
    _emit('cast-song', {'title': song['title'] ?? '', 'stanzas': _stripStanzaLabels(stanzas), 'currentStanza': _scheduleStanzaIndex, 'totalStanzas': stanzas.length, 'fontSize': _fontSize, if (_bgUrl != null) 'background': {'url': _bgUrl}});
  }

  void _scheduleNext() {
    if (_activeScheduleIndex < 0 || _activeScheduleIndex >= _schedules.length) return;
    final songs = _schedules[_activeScheduleIndex]['songs'] as List? ?? [];
    if (songs.isEmpty) return;
    final currentStanzas = List<String>.from(songs[_scheduleSongIndex]['stanzas'] ?? []);
    if (_scheduleStanzaIndex < currentStanzas.length - 1) { _scheduleStanzaIndex++; }
    else if (_scheduleSongIndex < songs.length - 1) { _scheduleSongIndex++; _scheduleStanzaIndex = 0; }
    _castScheduleSong();
    setState(() {});
  }

  void _schedulePrev() {
    if (_activeScheduleIndex < 0 || _activeScheduleIndex >= _schedules.length) return;
    final songs = _schedules[_activeScheduleIndex]['songs'] as List? ?? [];
    if (songs.isEmpty) return;
    if (_scheduleStanzaIndex > 0) { _scheduleStanzaIndex--; }
    else if (_scheduleSongIndex > 0) { _scheduleSongIndex--; final prevStanzas = List<String>.from(songs[_scheduleSongIndex]['stanzas'] ?? []); _scheduleStanzaIndex = prevStanzas.length > 0 ? prevStanzas.length - 1 : 0; }
    _castScheduleSong();
    setState(() {});
  }

  void _exitScheduleMode() {
    setState(() { _scheduleMode = false; _scheduleSongIndex = 0; _scheduleStanzaIndex = 0; });
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  // Strips a leading [Label] line (e.g. "[Chorus]") from each stanza so part
  // labels show on the phone controller but never appear on the cast TV screen.
  List<String> _stripStanzaLabels(List<String> stanzas) => stanzas
      .map((s) => s.replaceFirst(RegExp(r'^\s*\[[^\]]*\]\s*\n?'), ''))
      .toList();

  void _castSong() {
    if (_selectedSongIndex < 0 || _selectedSongIndex >= _filteredSongs.length) return;
    final song = _filteredSongs[_selectedSongIndex];
    final stanzas = song['stanzas'] as List<String>? ?? [];
    _emit('cast-song', {'title': song['title'] ?? '', 'stanzas': _stripStanzaLabels(stanzas), 'currentStanza': _selectedStanzaIndex, 'totalStanzas': stanzas.length, 'fontSize': _fontSize, if (_bgUrl != null) 'background': {'url': _bgUrl}});
  }

  void _prevStanza() { if (_selectedStanzaIndex > 0) { _selectedStanzaIndex--; _castSong(); setState(() {}); } }
  void _nextStanza() {
    if (_selectedSongIndex < 0 || _selectedSongIndex >= _filteredSongs.length) return;
    final stanzas = _filteredSongs[_selectedSongIndex]['stanzas'] as List<String>? ?? [];
    if (_selectedStanzaIndex < stanzas.length - 1) { _selectedStanzaIndex++; _castSong(); setState(() {}); }
  }

  // ══════════════════ CAST LOGO ══════════════════
  void _castLogo() {
    if (_customLogoPath.isNotEmpty) {
      _emit('cast-logo', {'image': 'data:image/png;base64,$_customLogoPath', 'fontSize': _fontSize, if (_bgUrl != null) 'background': {'url': _bgUrl}});
    } else {
      rootBundle.load('assets/church_logo.png').then((data) {
        final base64Str = base64Encode(data.buffer.asUint8List());
        _emit('cast-logo', {'image': 'data:image/png;base64,$base64Str', 'fontSize': _fontSize, if (_bgUrl != null) 'background': {'url': _bgUrl}});
      }).catchError((e) => _showSnack('Logo load error: $e', error: true));
    }
  }

  void _castWelcome() {
    if (_customLogoPath.isNotEmpty) {
      _emit('cast-welcome', {'logo': 'data:image/png;base64,$_customLogoPath', 'message': _welcomeMessage});
    } else {
      rootBundle.load('assets/church_logo.png').then((data) {
        final base64Str = base64Encode(data.buffer.asUint8List());
        _emit('cast-welcome', {'logo': 'data:image/png;base64,$base64Str', 'message': _welcomeMessage});
      }).catchError((e) => _emit('cast-welcome', {'logo': '', 'message': _welcomeMessage}));
    }
  }

  Future<void> _uploadCustomLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'], allowMultiple: false);
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
    } catch (e) { _showSnack('Logo upload error: $e', error: true); }
  }

  // ══════════════════ SCREEN MIRRORING / FULL-SCREEN ══════════════════
  Future<void> _openScreenMirrorSettings() async {
    try { await _screenCastChannel.invokeMethod('openScreenMirror'); }
    on PlatformException { _showSnack('Turn on Screencast from phone quick settings', error: false); }
  }

  void _toggleFullScreen() {
    setState(() { _isFullScreen = !_isFullScreen; _showFullScreenControls = true; });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
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
      final hi = content['textHi'] as String? ?? ''; final en = content['textEn'] as String? ?? '';
      final ref = '${content['book'] ?? ''} ${content['chapter'] ?? ''}:${content['verse'] ?? ''}';
      if (hi.isNotEmpty && en.isNotEmpty) return '$hi\n\n"$en"\n\n— $ref';
      if (hi.isNotEmpty) return '$hi\n\n— $ref';
      if (en.isNotEmpty) return '"$en"\n\n— $ref';
      return content['text'] as String? ?? '';
    } else if (type == 'slide') {
      final title = content['title'] as String? ?? ''; final text = content['text'] as String? ?? '';
      if (title.isNotEmpty && text.isNotEmpty) return '$title\n\n$text';
      return title + text;
    } else if (type == 'song') {
      final stanzas = content['stanzas'] as List? ?? []; final idx = content['currentStanza'] as int? ?? 0;
      if (idx < stanzas.length) return stanzas[idx].toString();
      return '';
    } else if (type == 'welcome') { return content['message'] as String? ?? ''; }
    return '';
  }

  void _showCastDialog() {
    final tvUrl = 'http://${_deviceIp == '...' ? '<DEVICE_IP>' : _deviceIp}:3000/tv.html';
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Cast to TV', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)),
            IconButton(icon: const Icon(Icons.close, color: kMuted), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),

          // ── Chromecast / AirPlay (Pigeon-native) ──
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              // Open the CastButton's device picker sheet
              showModalBottomSheet(
                context: context,
                backgroundColor: kBg3,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                isScrollControlled: true,
                builder: (_) => CastButton(castService: _castService, tvUrl: tvUrl),
              );
            },
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.blue.shade900.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade600.withOpacity(0.4))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade600.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.cast, size: 22, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Chromecast / AirPlay', style: TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text('Native cast — discover & connect to devices', style: TextStyle(color: kMuted, fontSize: 10))])),
                const Icon(Icons.chevron_right, color: kMuted, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 10),

          // ── Screen Mirror (Miracast) ──
          GestureDetector(
            onTap: () { Navigator.pop(context); _toggleFullScreen(); _openScreenMirrorSettings(); },
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kAccent.withOpacity(0.4))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.screen_share_outlined, size: 22, color: kAccent)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Screen Mirror', style: TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text('Mirror your phone screen to TV (Miracast)', style: TextStyle(color: kMuted, fontSize: 10))])),
                const Icon(Icons.chevron_right, color: kMuted, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 10),

          // ── Browser Connect ──
          GestureDetector(
            onTap: () { Navigator.pop(context); _copyUrl(); },
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.orange.shade900.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade800.withOpacity(0.4))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.shade900.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.cast, size: 22, color: Colors.orange.shade400)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Browser Connect', style: TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text('Open the URL in TV browser', style: TextStyle(color: kMuted, fontSize: 10))])),
                const Icon(Icons.chevron_right, color: kMuted, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kBg.withOpacity(0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder.withOpacity(0.5))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('HOW IT WORKS:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kGold, letterSpacing: 1.5)),
              const SizedBox(height: 8), castStep('1', 'Chromecast/AirPlay → Native cast directly to your TV'),
              const SizedBox(height: 4), castStep('2', 'Screen Mirror → App will enter fullscreen + open cast settings'),
              const SizedBox(height: 4), castStep('3', 'Browser Connect → Copy URL and open in TV browser'),
            ]),
          ),
        ]),
      ),
    );
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
            if (data is Map && data['type'] != null) {
              if (mounted) {
                setState(() {
                  _tvState = Map<String, dynamic>.from(data);
                  _connected = true;
                  if (data['type'] == 'pdf' && data['content'] != null) {
                    final content = data['content'] as Map<String, dynamic>;
                    _pdfCurrentPage = content['currentPage'] ?? _pdfCurrentPage;
                    if (content['totalPages'] != null && (content['totalPages'] as int) > 0) _pdfTotalPages = content['totalPages'];
                  }
                });
              }
              _reconnectDelay = 2;
            }
          } catch (_) {}
        },
        onDone: () { if (mounted) setState(() => _connected = false); _scheduleReconnect(); },
        onError: (error) { if (mounted) setState(() => _connected = false); _scheduleReconnect(); },
      );
    } catch (e) { if (mounted) setState(() => _connected = false); _scheduleReconnect(); }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () { if (mounted) _connectWS(); _reconnectDelay = (_reconnectDelay * 2).clamp(2, _maxReconnectDelay); });
  }

  void _emit(String event, Map<String, dynamic> data) {
    if (_channel == null || !_connected) { _showSnack('Not connected to server! Reconnecting...', error: true); _connectWS(); return; }
    _channel!.sink.add(jsonEncode({'event': event, 'data': data}));
  }

  // ── Cast actions ──
  void _castVerse() {
    final v = _bible[_selBook]?[_selChapter]?[_selVerse];
    _emit('cast-verse', {'book': _selBook, 'chapter': _selChapter, 'verse': _selVerse, 'textEn': v?['en'] ?? '', 'textHi': v?['hi'] ?? '', 'text': v?['hi'] ?? v?['en'] ?? '', 'fontSize': _fontSize, if (_bgUrl != null) 'background': {'url': _bgUrl}});
  }

  void _castSlide(int idx) {
    setState(() => _activeSlide = idx);
    final s = _slides[idx];
    _emit('cast-slide', {'title': s['title'] ?? '', 'subtitle': s['subtitle'] ?? '', 'text': s['text'] ?? '', 'slideIndex': idx, 'totalSlides': _slides.length, 'fontSize': _fontSize, if (_bgUrl != null) 'background': {'url': _bgUrl}});
  }

  void _clearScreen() { _currentlyCastUrl = ''; _emit('clear-screen', {}); }

  void _addSlide() {
    if (_addTitleCtrl.text.trim().isEmpty) return;
    setState(() { _slides.insert(0, {'title': _addTitleCtrl.text.trim().toUpperCase(), 'subtitle': '', 'text': _addContentCtrl.text.trim()}); _activeSlide = 0; });
    _addTitleCtrl.clear(); _addContentCtrl.clear();
    Navigator.pop(context);
    _castSlide(0);
  }

  void _deleteSlide(int i) {
    if (_slides.length <= 1) return;
    _confirmDelete(_slides[i]['title'] ?? 'this slide').then((confirmed) {
      if (!confirmed) return;
      setState(() { _slides.removeAt(i); if (_activeSlide >= _slides.length) _activeSlide = _slides.length - 1; if (_activeSlide < 0) _activeSlide = 0; });
    });
  }

  void _prevVerse() {
    final vList = (_bible[_selBook]?[_selChapter] ?? {}).keys.toList()..sort();
    final idx = vList.indexOf(_selVerse);
    if (idx > 0) { setState(() => _selVerse = vList[idx - 1]); _castVerse(); }
  }
  void _nextVerse() {
    final vList = (_bible[_selBook]?[_selChapter] ?? {}).keys.toList()..sort();
    final idx = vList.indexOf(_selVerse);
    if (idx < vList.length - 1) { setState(() => _selVerse = vList[idx + 1]); _castVerse(); }
  }

  // ══════════════════ FILE UPLOAD & CAST ══════════════════
  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'ppt', 'pptx'], allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) { _showSnack('File path not available', error: true); return; }
      final fileName = result.files.first.name;
      final fileExt = fileName.split('.').last.toLowerCase();
      if (!['pdf', 'ppt', 'pptx'].contains(fileExt)) { _showSnack('Only PDF and PPT/PPTX files are allowed!', error: true); return; }
      setState(() => _isUploading = true);
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      Uint8List? previewBytes;
      if (fileExt == 'pdf') { try { previewBytes = bytes.sublist(0, bytes.length > 50000 ? 50000 : bytes.length); } catch (_) {} }
      final uri = Uri.parse('http://127.0.0.1:3000/api/upload?name=${Uri.encodeComponent(fileName)}');
      final response = await http.post(uri, body: bytes);
      setState(() => _isUploading = false);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() { _uploadedFiles.insert(0, {'name': data['name'] ?? fileName, 'url': data['url'] ?? '', 'type': data['type'] ?? 'other', 'size': data['size'] ?? bytes.length, 'localPath': filePath, 'previewBytes': previewBytes}); });
        _showSnack('$fileName uploaded!');
        _castFile(0);
      } else { _showSnack('Upload fail: ${response.statusCode}', error: true); }
    } catch (e) { if (mounted) { setState(() => _isUploading = false); _showSnack('Upload error: $e', error: true); } }
  }

  void _castFile(int idx) {
    final f = _uploadedFiles[idx];
    final fileType = f['type'] as String? ?? 'other';
    final fileUrl = f['url'] as String? ?? '';
    final fileName = f['name'] as String? ?? 'Document';
    if (fileUrl.isEmpty) { _showSnack('File URL not found!', error: true); return; }
    setState(() { _activeFileIndex = idx; _pdfCurrentPage = 1; _pdfTotalPages = 0; });
    if (fileType == 'pdf') {
      _currentlyCastUrl = fileUrl;
      _emit('cast-pdf', {'url': fileUrl, 'name': fileName, 'currentPage': 1, 'totalPages': 0});
      _showSnack('Casting PDF to TV!');
    } else if (fileType == 'pptx') {
      _currentlyCastUrl = fileUrl;
      _emit('cast-pptx', {'url': fileUrl, 'name': fileName});
      _showSnack('Casting PPT to TV!');
    } else { _showSnack('This file type is not supported!', error: true); }
  }

  void _pdfPrevPage() { if (_pdfCurrentPage > 1) { _pdfCurrentPage--; _emit('pdf-page', {'page': _pdfCurrentPage}); setState(() {}); } }
  void _pdfNextPage() { if (_pdfTotalPages > 0 && _pdfCurrentPage >= _pdfTotalPages) return; _pdfCurrentPage++; _emit('pdf-page', {'page': _pdfCurrentPage}); setState(() {}); }

  Future<void> _deleteUploadedFile(int idx) async {
    final fileName = _uploadedFiles[idx]['name'] as String? ?? '';
    final confirmed = await _confirmDelete(fileName);
    if (!confirmed) return;
    final deletedUrl = _uploadedFiles[idx]['url'] as String? ?? '';
    if (fileName.isNotEmpty) { try { final uri = Uri.parse('http://127.0.0.1:3000/api/upload/${Uri.encodeComponent(fileName)}'); await http.delete(uri); } catch (e) {} }
    if (deletedUrl == _currentlyCastUrl) { _currentlyCastUrl = ''; _emit('clear-screen', {}); }
    setState(() { _uploadedFiles.removeAt(idx); if (_activeFileIndex >= _uploadedFiles.length) _activeFileIndex = _uploadedFiles.length - 1; if (_activeFileIndex < 0) _activeFileIndex = -1; });
    _showSnack('File deleted');
  }

  // ══════════════════ UPLOAD BACKGROUND ══════════════════
  Future<void> _uploadBgImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'], allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) return;
      final fileName = result.files.first.name;
      setState(() => _isUploadingBg = true);
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final uri = Uri.parse('http://127.0.0.1:3000/api/upload?name=${Uri.encodeComponent(fileName)}');
      final response = await http.post(uri, body: bytes);
      setState(() => _isUploadingBg = false);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final uploadedUrl = data['url'] as String? ?? '';
        final ip = _deviceIp == '...' ? '127.0.0.1' : _deviceIp;
        final fullUrl = 'http://$ip:3000$uploadedUrl';
        setState(() { _uploadedBgs.insert(0, {'name': fileName, 'url': fullUrl}); _bgUrl = fullUrl; });
        _emit('update-background', {'url': fullUrl});
        _showSnack('Background set!');
      } else { _showSnack('Upload fail: ${response.statusCode}', error: true); }
    } catch (e) { if (mounted) { setState(() => _isUploadingBg = false); _showSnack('Upload error: $e', error: true); } }
  }

  void _deleteUploadedBg(int bgIdx) async {
    final bg = _uploadedBgs[bgIdx];
    final confirmed = await _confirmDelete(bg['name'] ?? 'background');
    if (!confirmed) return;
    final bgName = bg['name'] ?? '';
    if (bgName.isNotEmpty) { try { final uri = Uri.parse('http://127.0.0.1:3000/api/upload/${Uri.encodeComponent(bgName)}'); await http.delete(uri); } catch (e) {} }
    setState(() { if (_bgUrl == bg['url']) { _bgUrl = null; _emit('update-background', {}); } _uploadedBgs.removeAt(bgIdx); });
    _showSnack('Background deleted');
  }

  void _copyUrl() { Clipboard.setData(ClipboardData(text: 'http://${_deviceIp == '...' ? '<DEVICE_IP>' : _deviceIp}:3000/tv.html')); _showSnack('URL copied!'); }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: error ? Colors.red.shade800 : kBg3,
      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 2),
    ));
  }

  // ══════════════════ SECTION FULLSCREEN OPENERS ══════════════════
  void _openSlidesFullscreen() {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false, barrierDismissible: false,
      pageBuilder: (_, __, ___) => SectionFullscreen(
        sectionTitle: 'SLIDES', sectionIcon: Icons.slideshow, sectionColor: kAccent,
        bgImageUrl: _bgUrl,
        tvState: _tvState,
        onBlackout: _clearScreen, onWelcome: _castWelcome, onLogo: _castLogo,
        onExit: () => Navigator.pop(context),
        contentBuilder: () => Text(
          _slides[_activeSlide]['title'] ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: (_fontSize * 0.9).clamp(20, 60).toDouble(), fontWeight: FontWeight.w600, height: 1.8, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.9), blurRadius: 20)]),
        ),
        controlsBuilder: (refresh) => [
          Text('${_activeSlide + 1} / ${_slides.length}', style: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: fsNavBtn(icon: Icons.skip_previous, label: 'Prev', iconFirst: true,
              onTap: _activeSlide > 0 ? () { _castSlide(_activeSlide - 1); refresh(); } : null)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: fsCastBtn(label: 'Cast', gradient: const [kAccent, Color(0xFF6366F1)],
              onTap: () { _castSlide(_activeSlide); refresh(); })),
            const SizedBox(width: 10),
            Expanded(child: fsNavBtn(icon: Icons.skip_next, label: 'Next', iconFirst: false,
              onTap: _activeSlide < _slides.length - 1 ? () { _castSlide(_activeSlide + 1); refresh(); } : null)),
          ]),
        ],
      ),
    ));
  }

  void _openBibleFullscreen() {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false, barrierDismissible: false,
      pageBuilder: (_, __, ___) => SectionFullscreen(
        sectionTitle: 'BIBLE', sectionIcon: Icons.menu_book, sectionColor: kGold,
        bgImageUrl: _bgUrl,
        tvState: _tvState,
        onBlackout: _clearScreen, onWelcome: _castWelcome, onLogo: _castLogo,
        onExit: () => Navigator.pop(context),
        contentBuilder: () {
          final v = _bible[_selBook]?[_selChapter]?[_selVerse];
          final hi = v?['hi'] ?? '';
          final en = v?['en'] ?? '';
          final ref = '$_selBook $_selChapter:$_selVerse';
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ref, style: const TextStyle(color: kAccent, fontSize: 16, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (hi.isNotEmpty) Text(hi, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: (_fontSize * 0.85).clamp(18, 50).toDouble(), height: 1.8, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.9), blurRadius: 20)])),
            if (hi.isNotEmpty && en.isNotEmpty) const SizedBox(height: 12),
            if (en.isNotEmpty) Text('"$en"', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: (_fontSize * 0.65).clamp(14, 35).toDouble(), height: 1.8, fontStyle: FontStyle.italic, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.9), blurRadius: 20)])),
          ]);
        },
        controlsBuilder: (refresh) => [
          Text('$_selBook $_selChapter:$_selVerse', style: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: fsNavBtn(icon: Icons.skip_previous, label: 'Prev', iconFirst: true,
              onTap: () { _prevVerse(); refresh(); })),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: fsCastBtn(label: 'Cast', gradient: const [kGold, Color(0xFFD97706)],
              onTap: () { _castVerse(); refresh(); })),
            const SizedBox(width: 10),
            Expanded(child: fsNavBtn(icon: Icons.skip_next, label: 'Next', iconFirst: false,
              onTap: () { _nextVerse(); refresh(); })),
          ]),
        ],
      ),
    ));
  }

  void _openSongsFullscreen() {
    if (_selectedSongIndex < 0 || _selectedSongIndex >= _filteredSongs.length) { _showSnack('Select a song first!', error: true); return; }
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false, barrierDismissible: false,
      pageBuilder: (_, __, ___) => SectionFullscreen(
        sectionTitle: 'SONGS', sectionIcon: Icons.music_note, sectionColor: Colors.purple,
        bgImageUrl: _bgUrl,
        tvState: _tvState,
        onBlackout: _clearScreen, onWelcome: _castWelcome, onLogo: _castLogo,
        onExit: () => Navigator.pop(context),
        contentBuilder: () {
          final song = _filteredSongs[_selectedSongIndex];
          final stanzas = song['stanzas'] as List<String>? ?? [];
          final currentStanza = _selectedStanzaIndex < stanzas.length ? stanzas[_selectedStanzaIndex] : '';
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Text(song['title'] as String? ?? '', style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Stanza ${_selectedStanzaIndex + 1} / ${stanzas.length}', style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
              child: Text(currentStanza.isEmpty ? 'No content' : currentStanza, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: (_fontSize * 0.55).clamp(14, 22).toDouble(), height: 1.8, fontWeight: FontWeight.w400)),
            ),
          ]);
        },
        controlsBuilder: (refresh) {
          final stanzas = _filteredSongs[_selectedSongIndex]['stanzas'] as List<String>? ?? [];
          return [
            Text('${_filteredSongs[_selectedSongIndex]['title'] ?? ''}  •  Stanza ${_selectedStanzaIndex + 1}/${stanzas.length}', style: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: fsNavBtn(icon: Icons.skip_previous, label: 'Prev', iconFirst: true,
                onTap: _selectedStanzaIndex > 0 ? () { _prevStanza(); refresh(); } : null)),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: fsCastBtn(label: 'Cast to TV', gradient: const [Colors.purple, Color(0xFF7C3AED)],
                onTap: () { _castSong(); refresh(); })),
              const SizedBox(width: 10),
              Expanded(child: fsNavBtn(icon: Icons.skip_next, label: 'Next', iconFirst: false,
                onTap: _selectedStanzaIndex < stanzas.length - 1 ? () { _nextStanza(); refresh(); } : null)),
            ]),
          ];
        },
      ),
    ));
  }

  void _openFilesFullscreen() {
    if (_tvState['type'] != 'pdf' && _tvState['type'] != 'pptx') { _showSnack('Cast a file first!', error: true); return; }
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false, barrierDismissible: false,
      pageBuilder: (_, __, ___) => SectionFullscreen(
        sectionTitle: _tvState['type'] == 'pdf' ? 'PDF' : 'PPT',
        sectionIcon: _tvState['type'] == 'pdf' ? Icons.picture_as_pdf : Icons.slideshow,
        sectionColor: _tvState['type'] == 'pdf' ? Colors.red : Colors.orange,
        bgImageUrl: null,
        tvState: _tvState,
        onBlackout: _clearScreen, onWelcome: _castWelcome, onLogo: _castLogo,
        onExit: () => Navigator.pop(context),
        contentBuilder: () => Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_tvState['type'] == 'pdf' ? Icons.picture_as_pdf : Icons.slideshow, size: 64, color: _tvState['type'] == 'pdf' ? Colors.red.shade400 : Colors.orange.shade400),
          const SizedBox(height: 16),
          Text('Page $_pdfCurrentPage ${_pdfTotalPages > 0 ? "/ $_pdfTotalPages" : ""}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          const Text('Control from phone or TV browser', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
        controlsBuilder: (refresh) => _tvState['type'] == 'pdf' ? [
          Row(children: [
            Expanded(child: fsNavBtn(icon: Icons.navigate_before, label: 'Prev Page', iconFirst: true,
              onTap: _pdfCurrentPage > 1 ? () { _pdfPrevPage(); refresh(); } : null)),
            const SizedBox(width: 10),
            Expanded(child: fsNavBtn(icon: Icons.navigate_next, label: 'Next Page', iconFirst: false,
              onTap: (_pdfTotalPages > 0 && _pdfCurrentPage >= _pdfTotalPages) ? null : () { _pdfNextPage(); refresh(); })),
          ]),
        ] : const [],
      ),
    ));
  }

  // ══════════════════ SCHEDULE DETAIL OPENER ══════════════════
  void _openScheduleDetail(int idx) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScheduleDetailPage(
        schedule: _schedules[idx],
        scheduleIndex: idx,
        allSongs: _allSongs,
        onAddSong: (songIdx) => _addSongToSchedule(idx, songIdx),
        onRemoveSong: (pos) => _removeSongFromSchedule(idx, pos),
        onPlay: () => _startSchedulePresentation(idx),
        onDelete: () { Navigator.pop(context); _deleteSchedule(idx); },
        onSongReorder: (oldPos, newPos) {
          setState(() {
            final songs = List<Map<String, dynamic>>.from(_schedules[idx]['songs'] ?? []);
            if (oldPos < songs.length && newPos <= songs.length) { final item = songs.removeAt(oldPos); songs.insert(newPos, item); _schedules[idx]['songs'] = songs; }
          });
          _saveSchedules();
        },
      ),
    ));
  }

  // ══════════════════ MODALS ══════════════════
  void _showAddSlideModal() {
    showModalBottomSheet(
      context: context, backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Add New Slide', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)), IconButton(icon: const Icon(Icons.close, color: kMuted), onPressed: () => Navigator.pop(context))]),
          const SizedBox(height: 14), inputField(_addTitleCtrl, 'Slide Title', 'e.g. Welcome to Church'),
          const SizedBox(height: 10), inputField(_addContentCtrl, 'Content', 'Enter slide text here...', maxLines: 3),
          const SizedBox(height: 16), primaryBtn('Save & Cast', _addSlide),
        ]),
      ),
    );
  }

  void _showAddSongModal() {
    for (final c in _songStanzaCtrls) { c.dispose(); }
    _songStanzaCtrls = [TextEditingController(), TextEditingController()];
    _songTitleCtrl.clear();
    showModalBottomSheet(
      context: context, backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Add New Song', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)), IconButton(icon: const Icon(Icons.close, color: kMuted), onPressed: () => Navigator.pop(context))]),
                const SizedBox(height: 12), inputField(_songTitleCtrl, 'Song Title', 'e.g. Amazing Grace'),
                const SizedBox(height: 12),
                ...List.generate(_songStanzaCtrls.length, (i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [Container(width: 20, height: 20, decoration: BoxDecoration(color: kGold.withOpacity(0.15), borderRadius: BorderRadius.circular(5)), child: Center(child: Text('${i + 1}', style: const TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold)))), const SizedBox(width: 8), Text('Stanza ${i + 1}', style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.w600))]),
                        if (_songStanzaCtrls.length > 1) GestureDetector(
                          onTap: () { _songStanzaCtrls[i].dispose(); _songStanzaCtrls.removeAt(i); setModalState(() {}); },
                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.close, size: 10, color: Colors.red.shade400), SizedBox(width: 3), Text('Remove', style: TextStyle(fontSize: 8, color: Colors.red.shade400, fontWeight: FontWeight.w600))])),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      TextField(controller: _songStanzaCtrls[i], style: const TextStyle(color: kText, fontSize: 12, height: 1.5), maxLines: 5, minLines: 3,
                        decoration: InputDecoration(hintText: 'Enter stanza ${i + 1} lyrics here...', hintStyle: const TextStyle(color: kMuted, fontSize: 11), filled: true, fillColor: kBg3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kGold, width: 1.5)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
                    ]),
                  );
                }),
                GestureDetector(
                  onTap: () { _songStanzaCtrls.add(TextEditingController()); setModalState(() {}); },
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14), decoration: BoxDecoration(color: Colors.green.shade900.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade800.withOpacity(0.3))),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add, size: 16, color: Colors.green), SizedBox(width: 6), Text('Add More Stanza', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600))])),
                ),
                const SizedBox(height: 16), primaryBtn('Save Song', _addManualSong),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showCreateScheduleModal() {
    _scheduleNameCtrl.clear(); _scheduleDate = DateTime.now();
    showModalBottomSheet(
      context: context, backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Create Schedule', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)), IconButton(icon: const Icon(Icons.close, color: kMuted), onPressed: () => Navigator.pop(context))]),
              const SizedBox(height: 12), inputField(_scheduleNameCtrl, 'Schedule Name', 'e.g. Sunday Worship'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _scheduleDate, firstDate: DateTime(2024), lastDate: DateTime(2030), builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.purple, surface: kBg2)), child: child!));
                  if (picked != null) setModalState(() => _scheduleDate = picked);
                },
                child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                  child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.purple), const SizedBox(width: 10), Text('${_scheduleDate.day}/${_scheduleDate.month}/${_scheduleDate.year}', style: const TextStyle(color: kText, fontSize: 13))]),
                ),
              ),
              const SizedBox(height: 16), primaryBtn('Create Schedule', () => _createSchedule(_scheduleNameCtrl.text, '${_scheduleDate.day}/${_scheduleDate.month}/${_scheduleDate.year}')),
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
    for (final c in _songStanzaCtrls) { c.dispose(); }
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
          if (bgImage != null) Positioned.fill(child: Image.network(bgImage, fit: BoxFit.cover, color: Colors.black.withOpacity(0.55), colorBlendMode: BlendMode.darken, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: RadialGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.7)], radius: 1.2)))),
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Text(content.isNotEmpty ? content : 'BiblePresenter', textAlign: TextAlign.center,
              style: TextStyle(color: content.isEmpty ? Colors.white24 : Colors.white, fontSize: content.isEmpty ? 20 : (_fontSize.toDouble() * 0.9), fontWeight: FontWeight.w600, height: 1.8, shadows: [Shadow(color: Colors.black.withOpacity(0.9), blurRadius: 20)])),
          )),
          if (!_showFullScreenControls)
            Positioned(bottom: 20, left: 0, right: 0, child: Center(child: GestureDetector(
              onTap: () => setState(() => _showFullScreenControls = true),
              child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white24, width: 1)), child: const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 22)),
            ))),
          if (_showFullScreenControls) Positioned(
            bottom: 20, left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0a0f1e).withOpacity(0.95), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1a2d45), width: 1.5)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(type == 'verse' ? Icons.menu_book : type == 'slide' ? Icons.slideshow : type == 'song' ? Icons.music_note : type == 'logo' ? Icons.image : type == 'pdf' ? Icons.picture_as_pdf : type == 'welcome' ? Icons.waving_hand : Icons.tv, size: 14, color: kAccent), const SizedBox(width: 6), Text(type.toUpperCase(), style: const TextStyle(color: kAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))])),
                  GestureDetector(onTap: () => setState(() => _showFullScreenControls = false), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18))),
                  GestureDetector(onTap: _toggleFullScreen, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.close, color: Colors.red, size: 16))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: GestureDetector(onTap: _clearScreen, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade800.withOpacity(0.4))), child: const Center(child: Text('Blackout', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)))))),
                  const SizedBox(width: 6),
                  Expanded(child: GestureDetector(onTap: _castWelcome, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.green.shade900.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade800.withOpacity(0.4))), child: const Center(child: Text('Welcome', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)))))),
                  const SizedBox(width: 6),
                  Expanded(child: GestureDetector(onTap: _castLogo, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: kGold.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: kGold.withOpacity(0.3))), child: const Center(child: Text('Logo', style: TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold)))))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: GestureDetector(onTap: () { if (type == 'verse') _prevVerse(); else if (type == 'slide' && _activeSlide > 0) _castSlide(_activeSlide - 1); else if (type == 'song') _prevStanza(); else if (type == 'pdf') _pdfPrevPage(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('Prev', style: TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.bold)))))),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(onTap: () { if (type == 'verse') _castVerse(); else if (type == 'slide') _castSlide(_activeSlide); else if (type == 'song') _castSong(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: kAccent.withOpacity(0.3), blurRadius: 8)]), child: const Center(child: Text('Cast', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))))),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(onTap: () { if (type == 'verse') _nextVerse(); else if (type == 'slide' && _activeSlide < _slides.length - 1) _castSlide(_activeSlide + 1); else if (type == 'song') _nextStanza(); else if (type == 'pdf') _pdfNextPage(); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('Next', style: TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.bold)))))),
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
      appBar: _buildAppBar(),
      body: Column(children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SlidesTab(slides: _slides, activeSlide: _activeSlide, onCastSlide: _castSlide, onDeleteSlide: _deleteSlide, onShowAddSlideModal: _showAddSlideModal, onOpenFullscreen: _openSlidesFullscreen),
              BibleTab(bible: _bible, bibleLoaded: _bibleLoaded, selBook: _selBook, selChapter: _selChapter, selVerse: _selVerse, fontSize: _fontSize, onBookChanged: (val) => setState(() { _selBook = val; _selChapter = _bible[val]!.keys.first; _selVerse = _bible[val]![_selChapter]!.keys.first; }), onChapterChanged: (val) => setState(() { _selChapter = val; _selVerse = (_bible[_selBook]?[val] ?? {}).keys.first; }), onVerseChanged: (val) => setState(() => _selVerse = val), onCastVerse: _castVerse, onPrevVerse: _prevVerse, onNextVerse: _nextVerse, onFontSizeChanged: (v) => setState(() => _fontSize = v), onOpenFullscreen: _openBibleFullscreen),
              SongsTab(allSongs: _allSongs, filteredSongs: _filteredSongs, songsLoaded: _songsLoaded, songSearchQuery: _songSearchQuery, selectedSongIndex: _selectedSongIndex, selectedStanzaIndex: _selectedStanzaIndex, songSearchCtrl: _songSearchCtrl, onFilterSongs: _filterSongs, onShowAddSongModal: _showAddSongModal, onShowCreateScheduleModal: _showCreateScheduleModal, onDeleteSong: _deleteSong, onSelectSong: (i) => setState(() { _selectedSongIndex = i; _selectedStanzaIndex = 0; }), onSelectStanza: (i) { _selectedStanzaIndex = i; _castSong(); setState(() {}); }, onCastSong: _castSong, onPrevStanza: _prevStanza, onNextStanza: _nextStanza, onOpenFullscreen: _openSongsFullscreen, schedules: _schedules, scheduleMode: _scheduleMode, activeScheduleIndex: _activeScheduleIndex, onOpenScheduleDetail: _openScheduleDetail, onDeleteSchedule: _deleteSchedule, onStartSchedulePresentation: _startSchedulePresentation),
              FilesTab(uploadedFiles: _uploadedFiles, isUploading: _isUploading, activeFileIndex: _activeFileIndex, tvState: _tvState, pdfCurrentPage: _pdfCurrentPage, pdfTotalPages: _pdfTotalPages, onPickAndUploadFile: _pickAndUploadFile, onCastFile: _castFile, onDeleteFile: _deleteUploadedFile, onPdfPrevPage: _pdfPrevPage, onPdfNextPage: _pdfNextPage, onOpenFullscreen: _openFilesFullscreen),
              SettingsTab(fontSize: _fontSize, onFontSizeChanged: (v) => setState(() => _fontSize = v), welcomeMessage: _welcomeMessage, welcomeMsgCtrl: _welcomeMsgCtrl, onWelcomeMessageChanged: (val) async { setState(() => _welcomeMessage = val); final prefs = await SharedPreferences.getInstance(); await prefs.setString('welcome_message', val); }, onCastWelcome: _castWelcome, onClearScreen: _clearScreen, customLogoPath: _customLogoPath, onUploadCustomLogo: _uploadCustomLogo, onRemoveCustomLogo: () async { final confirmed = await _confirmDelete('custom logo'); if (!confirmed) return; final prefs = await SharedPreferences.getInstance(); await prefs.remove('custom_logo_base64'); setState(() => _customLogoPath = ''); _showSnack('Custom logo removed'); }, onCastLogo: _castLogo, bgUrl: _bgUrl, onBgUrlChanged: (url) { setState(() => _bgUrl = url); if (url != null) _emit('update-background', {'url': url}); else _emit('update-background', {}); }, isUploadingBg: _isUploadingBg, onUploadBgImage: _uploadBgImage, uploadedBgs: _uploadedBgs, onDeleteUploadedBg: _deleteUploadedBg, serverStarted: _serverStarted, connected: _connected, deviceIp: _deviceIp, onRefreshIp: _refreshIp, onConnectWS: _connectWS, onCopyUrl: _copyUrl),
            ],
          ),
        ),
        _bottomUrlBar(),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: kBg2, elevation: 0, titleSpacing: 12,
    title: Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: const LinearGradient(colors: [kAccent, Color(0xFF6366F1)]), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.cast, size: 16, color: Colors.white)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('BiblePresenter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kText)),
        Row(children: [
          Icon(Icons.circle, size: 6, color: _connected ? Colors.green : Colors.red),
          const SizedBox(width: 4),
          Text(_serverStarted ? (_connected ? 'Server live' : 'Connecting...') : 'Starting server...', style: TextStyle(fontSize: 9, color: _connected ? Colors.green : kMuted)),
          if (_tvState['type'] != null && _tvState['type'] != 'idle') ...[
            const SizedBox(width: 8),
            Icon(_tvState['type'] == 'verse' ? Icons.menu_book : _tvState['type'] == 'slide' ? Icons.slideshow : _tvState['type'] == 'song' ? Icons.music_note : _tvState['type'] == 'pdf' ? Icons.picture_as_pdf : _tvState['type'] == 'pptx' ? Icons.slideshow : _tvState['type'] == 'logo' ? Icons.image : _tvState['type'] == 'welcome' ? Icons.waving_hand : Icons.cast, size: 10, color: kAccent),
            const SizedBox(width: 2),
            Text(_tvState['type'] == 'verse' ? 'Verse' : _tvState['type'] == 'slide' ? 'Slide' : _tvState['type'] == 'song' ? 'Song' : _tvState['type'] == 'pdf' ? 'PDF' : _tvState['type'] == 'pptx' ? 'PPT' : _tvState['type'] == 'logo' ? 'Logo' : _tvState['type'] == 'welcome' ? 'Welcome' : '', style: const TextStyle(color: kAccent, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ]),
      ]),
    ]),
    actions: [
      IconButton(onPressed: _castWelcome, icon: Icon(Icons.waving_hand, size: 18, color: Colors.green.shade400), tooltip: 'Welcome', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
      IconButton(onPressed: _castLogo, icon: Image.asset('assets/church_logo.png', width: 18, height: 18), tooltip: 'Church Logo', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
      IconButton(onPressed: _clearScreen, icon: Icon(Icons.dark_mode, size: 18, color: Colors.red.shade300), tooltip: 'Blackout', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
      const SizedBox(width: 4),
    ],
  );

  Widget _buildTabBar() => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF080f1e),
      border: Border(bottom: BorderSide(color: kBorder)),
    ),
    child: TabBar(
      controller: _tabController, indicatorColor: kAccent, indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.tab, labelColor: kAccent, unselectedLabelColor: kMuted,
      splashFactory: InkRipple.splashFactory,
      labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
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
    decoration: const BoxDecoration(color: kBg2, border: Border(top: BorderSide(color: kBorder))),
    child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(Icons.wifi, size: 13, color: kAccent),
        const SizedBox(width: 6),
        Expanded(child: Text('http://$_deviceIp:3000/tv.html', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: kAccent, fontWeight: FontWeight.w600), overflow: TextOverflow.visible, maxLines: 1, softWrap: false)),
        const SizedBox(width: 6),
        Material(color: Colors.transparent, child: InkWell(onTap: _refreshIp, borderRadius: BorderRadius.circular(8), child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.refresh, size: 14, color: kAccent)))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _barBtn(Icons.cast, 'Cast', _showCastDialog)),
        const SizedBox(width: 8),
        // Quick-cast indicator for Chromecast/AirPlay connection status
        CastButton(castService: _castService, tvUrl: 'http://${_deviceIp == '...' ? '' : _deviceIp}:3000/tv.html'),
        const SizedBox(width: 8),
        Expanded(child: _barBtn(Icons.copy, 'Copy URL', _copyUrl)),
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
        decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: kAccent.withValues(alpha: 0.4))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: kAccent),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kAccent)),
        ]),
      ),
    ),
  );
}
