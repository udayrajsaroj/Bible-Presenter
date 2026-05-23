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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BiblePresenterApp());
}

// ── Theme constants ──
const kBg     = Color(0xFF060c18);
const kBg2    = Color(0xFF0b1526);
const kBg3    = Color(0xFF0d1a2e);
const kBorder = Color(0xFF1a2d45);
const kAccent = Color(0xFF0EA5E9);
const kGold   = Color(0xFFc9a96e);
const kText   = Color(0xFFe2e8f0);
const kMuted  = Color(0xFF64748b);

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

  // ── Bible state (loaded from JSON assets) ──
  Map<String, Map<int, Map<int, Map<String, String>>>> _bible = {};
  bool _bibleLoaded = false;
  String _selBook = 'Psalms';
  int _selChapter = 23;
  int _selVerse = 1;

  // ── Slides state ──
  List<Map<String, String>> _slides = [
    {'title': 'WELCOME', 'subtitle': 'Covenant Fellowship', 'text': 'Welcome to our Sunday worship service. May God bless you today.'},
    {'title': 'OPENING PRAYER', 'subtitle': '', 'text': 'Let us bow our heads and open our hearts in prayer to our Heavenly Father.'},
    {'title': 'ANNOUNCEMENTS', 'subtitle': 'This Week', 'text': 'Sunday school at 9:00 AM · Prayer meeting Wednesday 7 PM · Youth camp registration open.'},
    {'title': 'OFFERING', 'subtitle': '', 'text': '"Each of you should give what you have decided in your heart to give." — 2 Corinthians 9:7'},
  ];
  int _activeSlide = 0;

  // ── Settings ──
  int _fontSize = 44;
  String? _bgUrl;
  final _addTitleCtrl   = TextEditingController();
  final _addContentCtrl = TextEditingController();

  // ── Files state ──
  List<Map<String, dynamic>> _uploadedFiles = []; // {name, url, type, size, localPath, previewBytes}
  bool _isUploading = false;
  int _pdfCurrentPage = 1;
  int _pdfTotalPages = 0;
  int _activeFileIndex = -1;
  String _currentlyCastUrl = ''; // track which file URL is currently on TV

  // ── Uploaded backgrounds ──
  List<Map<String, String>> _uploadedBgs = []; // {name, url}
  bool _isUploadingBg = false;

  // ── Preset backgrounds ──
  final List<Map<String, String>> _presetBgs = [
    {'name': 'Glowing Cross', 'url': 'https://images.unsplash.com/photo-1515787366009-7cbdd2dc587b?auto=format&fit=crop&q=80&w=1200'},
    {'name': 'Sabbath Dawn',  'url': 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?auto=format&fit=crop&q=80&w=1200'},
    {'name': 'Night Sky',     'url': 'https://images.unsplash.com/photo-1506318137071-a8e063b4bec0?auto=format&fit=crop&q=80&w=1200'},
    {'name': 'Golden Hour',   'url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=1200'},
    {'name': 'Dark Abstract', 'url': 'https://images.unsplash.com/photo-1509023464722-18d996393ca8?auto=format&fit=crop&q=80&w=1200'},
  ];

  // ── Songs state ──
  List<Map<String, dynamic>> _allSongs = []; // {title, stanzas: [String], source: 'asset'|'manual'}
  List<Map<String, dynamic>> _filteredSongs = [];
  bool _songsLoaded = false;
  String _songSearchQuery = '';
  int _selectedSongIndex = -1;
  int _selectedStanzaIndex = 0;
  final _songSearchCtrl = TextEditingController();
  final _songTitleCtrl = TextEditingController();
  List<TextEditingController> _songStanzaCtrls = [TextEditingController(), TextEditingController()];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this)
      ..addListener(() => setState(() => _activeTab = _tabController.index));
    _boot();
  }

  // ══════════════════ BOOT SEQUENCE ══════════════════
  Future<void> _boot() async {
    await _loadBibleFromAssets();

    try {
      await Isolate.spawn(startServer, null);
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

    if (!serverReady) {
      print('[BiblePresenter] Server may not be ready, but will try connecting anyway...');
    }

    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null && mounted) setState(() => _deviceIp = ip);
    } catch (_) {}

    _connectWS();

    // Reload previously uploaded files (backgrounds + documents)
    _reloadUploadedFiles();

    // Load songs from asset + persistent storage
    _loadSongs();
  }

  // ══════════════════ LOAD BIBLE FROM ASSETS ══════════════════
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
          if (_bible.isNotEmpty) {
            _selBook = _bible.keys.first;
            _selChapter = _bible[_selBook]!.keys.first;
            _selVerse = _bible[_selBook]![_selChapter]!.keys.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bible = _fallbackBible();
          _bibleLoaded = true;
          if (_bible.isNotEmpty) {
            _selBook = _bible.keys.first;
            _selChapter = _bible[_selBook]!.keys.first;
            _selVerse = _bible[_selBook]![_selChapter]!.keys.first;
          }
        });
      }
    }
  }

  Map<String, Map<int, Map<int, Map<String, String>>>> _fallbackBible() {
    return {
      'Psalms': {
        23: {
          1:  {'en': 'The Lord is my shepherd; I shall not want.', 'hi': 'यहोवा मेरा चरवाहा है, मुझे कोई घटी न होगी।'},
          2:  {'en': 'He maketh me to lie down in green pastures.', 'hi': 'वह मुझे हरी हरी चराइयों में बैठाता है।'},
          4:  {'en': 'Yea, though I walk through the valley of the shadow of death, I will fear no evil.', 'hi': 'चाहे मैं मृत्यु की छाया की तराई में भी चलूं, मैं किसी विपत्ति से न डरूंगा।'},
          6:  {'en': 'Surely goodness and mercy shall follow me all the days of my life.', 'hi': 'निश्चय भलाई और करुणा मेरे जीवन भर मेरे साथ रहेंगी।'},
        },
        119: {105: {'en': 'Thy word is a lamp unto my feet, and a light unto my path.', 'hi': 'तेरा वचन मेरे पांव के लिये दीपक, और मेरे मार्ग के लिये प्रकाश है।'}},
      },
      'John': {
        3:  {16: {'en': 'For God so loved the world, that he gave his only begotten Son.', 'hi': 'क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उस ने अपना एकलौता पुत्र दे दिया।'}},
        14: {6:  {'en': 'I am the way, the truth, and the life.', 'hi': 'मार्ग और सत्य और जीवन मैं ही हूं।'}},
      },
      'Romans': {
        8: {28: {'en': 'All things work together for good to them that love God.', 'hi': 'जो लोग परमेश्वर से प्रेम रखते हैं उनके लिये सब बातें मिलकर भलाई ही को उत्पन्न करती हैं।'}},
      },
      'Philippians': {
        4: {13: {'en': 'I can do all things through Christ which strengtheneth me.', 'hi': 'मैं मसीह के द्वारा जो मुझे सामर्थ देता है सब कुछ कर सकता हूं।'}},
      },
    };
  }

  // ══════════════════ RELOAD UPLOADED FILES ON STARTUP ══════════════════
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
          if (type == 'image') {
            reloadedBgs.add({'name': name, 'url': fullUrl});
          } else {
            reloadedFiles.add({'name': name, 'url': url, 'type': type, 'size': size, 'localPath': '', 'previewBytes': null});
          }
        }
        if (mounted) { setState(() { _uploadedBgs = reloadedBgs; _uploadedFiles = reloadedFiles; }); }
      }
    } catch (_) {}
  }

  // ══════════════════ LOAD SONGS FROM ASSET + PERSISTENT STORAGE ══════════════════
  Future<void> _loadSongs() async {
    try {
      final songsJsonStr = await rootBundle.loadString('assets/songs.json');
      final List<dynamic> assetSongs = jsonDecode(songsJsonStr) as List<dynamic>;
      final List<Map<String, dynamic>> songs = [];
      for (final s in assetSongs) {
        songs.add({'title': s['title'] as String? ?? '', 'stanzas': List<String>.from(s['stanzas'] as List? ?? []), 'source': 'asset'});
      }
      // Load manually added songs from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final manualSongsStr = prefs.getString('manual_songs') ?? '[]';
        final List<dynamic> manualSongs = jsonDecode(manualSongsStr) as List<dynamic>;
        for (final s in manualSongs) {
          songs.add({'title': s['title'] as String? ?? '', 'stanzas': List<String>.from(s['stanzas'] as List? ?? []), 'source': 'manual'});
        }
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
    final stanzas = _songStanzaCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
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
    _showSnack('Song "$title" add ho gaya!');
  }

  void _deleteSong(int idx) {
    final song = _allSongs[idx];
    if (song['source'] != 'manual') return;
    setState(() {
      _allSongs.removeAt(idx);
      _filteredSongs = List.from(_allSongs);
      if (_selectedSongIndex >= _allSongs.length) _selectedSongIndex = _allSongs.length - 1;
      if (_selectedSongIndex < 0) _selectedSongIndex = -1;
    });
    _saveManualSongs();
    _showSnack('Song delete ho gaya');
  }

  void _castSong() {
    if (_selectedSongIndex < 0 || _selectedSongIndex >= _filteredSongs.length) return;
    final song = _filteredSongs[_selectedSongIndex];
    final stanzas = song['stanzas'] as List<String>? ?? [];
    _emit('cast-song', {
      'title': song['title'] ?? '',
      'stanzas': stanzas,
      'currentStanza': _selectedStanzaIndex,
      'totalStanzas': stanzas.length,
      'fontSize': _fontSize,
      if (_bgUrl != null) 'background': {'url': _bgUrl},
    });
  }

  void _prevStanza() {
    if (_selectedStanzaIndex > 0) { _selectedStanzaIndex--; _castSong(); setState(() {}); }
  }
  void _nextStanza() {
    if (_selectedSongIndex < 0 || _selectedSongIndex >= _filteredSongs.length) return;
    final stanzas = _filteredSongs[_selectedSongIndex]['stanzas'] as List<String>? ?? [];
    if (_selectedStanzaIndex < stanzas.length - 1) { _selectedStanzaIndex++; _castSong(); setState(() {}); }
  }

  // ══════════════════ WEBSOCKET CONNECTION ══════════════════
  void _connectWS() {
    _reconnectTimer?.cancel();
    final wsUrl = 'ws://127.0.0.1:3000/ws';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(
        (msg) {
          try {
            final data = jsonDecode(msg as String);
            if (data is Map && data['type'] != null) {
              if (mounted) {
                setState(() {
                  _tvState = Map<String, dynamic>.from(data);
                  _connected = true;
                  // Track PDF page info from TV state
                  if (data['type'] == 'pdf' && data['content'] != null) {
                    final content = data['content'] as Map<String, dynamic>;
                    _pdfCurrentPage = content['currentPage'] ?? 1;
                    _pdfTotalPages = content['totalPages'] ?? 0;
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
    if (_channel == null || !_connected) {
      _showSnack('Server se connected nahi! Reconnecting...', error: true);
      _connectWS();
      return;
    }
    _channel!.sink.add(jsonEncode({'event': event, 'data': data}));
  }

  // ── Cast actions ──
  void _castVerse() {
    final v = _bible[_selBook]?[_selChapter]?[_selVerse];
    _emit('cast-verse', {
      'book': _selBook, 'chapter': _selChapter, 'verse': _selVerse,
      'textEn': v?['en'] ?? '', 'textHi': v?['hi'] ?? '',
      'text': v?['hi'] ?? v?['en'] ?? '',
      'fontSize': _fontSize,
      if (_bgUrl != null) 'background': {'url': _bgUrl},
    });
  }

  void _castSlide(int idx) {
    setState(() => _activeSlide = idx);
    final s = _slides[idx];
    _emit('cast-slide', {
      'title': s['title'] ?? '', 'subtitle': s['subtitle'] ?? '',
      'text': s['text'] ?? '', 'slideIndex': idx,
      'totalSlides': _slides.length, 'fontSize': _fontSize,
      if (_bgUrl != null) 'background': {'url': _bgUrl},
    });
  }

  void _clearScreen() {
    _currentlyCastUrl = '';
    _emit('clear-screen', {});
  }

  void _addSlide() {
    if (_addTitleCtrl.text.trim().isEmpty) return;
    setState(() {
      _slides.insert(0, {
        'title': _addTitleCtrl.text.trim().toUpperCase(),
        'subtitle': '', 'text': _addContentCtrl.text.trim(),
      });
      _activeSlide = 0;
    });
    _addTitleCtrl.clear(); _addContentCtrl.clear();
    Navigator.pop(context);
    _castSlide(0);
  }

  void _deleteSlide(int i) {
    setState(() {
      _slides.removeAt(i);
      if (_activeSlide >= _slides.length) _activeSlide = _slides.length - 1;
      if (_activeSlide < 0) _activeSlide = 0;
    });
  }

  // ══════════════════ FILE UPLOAD & CAST ══════════════════
  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'ppt', 'pptx'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final filePath = pickedFile.path;
      if (filePath == null) {
        _showSnack('File path not available', error: true);
        return;
      }

      final fileName = pickedFile.name;
      final fileExt = fileName.split('.').last.toLowerCase();
      if (!['pdf', 'ppt', 'pptx'].contains(fileExt)) {
        _showSnack('Sirf PDF aur PPT/PPTX files allowed hain!', error: true);
        return;
      }

      setState(() => _isUploading = true);

      final file = File(filePath);
      final bytes = await file.readAsBytes();

      // Read first page preview for PDF files
      Uint8List? previewBytes;
      if (fileExt == 'pdf') {
        try {
          previewBytes = bytes.sublist(0, bytes.length > 50000 ? 50000 : bytes.length);
        } catch (_) {}
      }

      final uri = Uri.parse('http://127.0.0.1:3000/api/upload?name=${Uri.encodeComponent(fileName)}');
      final response = await http.post(uri, body: bytes);

      setState(() => _isUploading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final uploadedFile = {
          'name': data['name'] ?? fileName,
          'url': data['url'] ?? '',
          'type': data['type'] ?? 'other',
          'size': data['size'] ?? bytes.length,
          'localPath': filePath,
          'previewBytes': previewBytes,
        };
        setState(() {
          _uploadedFiles.insert(0, uploadedFile);
        });
        _showSnack('$fileName upload ho gaya!');
        // Auto-cast the file to TV after upload
        _castFile(0);
      } else {
        _showSnack('Upload fail: ${response.statusCode}', error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnack('Upload error: $e', error: true);
      }
    }
  }

  void _castFile(int idx) {
    final f = _uploadedFiles[idx];
    final fileType = f['type'] as String? ?? 'other';
    final fileUrl = f['url'] as String? ?? '';
    final fileName = f['name'] as String? ?? 'Document';

    if (fileUrl.isEmpty) {
      _showSnack('File URL nahi mila!', error: true);
      return;
    }

    setState(() {
      _activeFileIndex = idx;
      _pdfCurrentPage = 1;
      _pdfTotalPages = 0;
    });

    // Directly cast the file — TV-side code handles URL changes:
    // it detects different URL and auto-closes old viewer + loads new PDF
    _doCastFile(fileType, fileUrl, fileName);
  }

  void _doCastFile(String fileType, String fileUrl, String fileName) {
    if (fileType == 'pdf') {
      _currentlyCastUrl = fileUrl;
      _emit('cast-pdf', {
        'url': fileUrl,
        'name': fileName,
        'currentPage': 1,
        'totalPages': 0,
      });
      _showSnack('PDF cast ho raha hai TV pe!');
    } else if (fileType == 'pptx') {
      _currentlyCastUrl = fileUrl;
      _emit('cast-pptx', {
        'url': fileUrl,
        'name': fileName,
      });
      _showSnack('PPT cast ho raha hai TV pe!');
    } else {
      _showSnack('Ye file type supported nahi hai!', error: true);
    }
  }

  void _pdfPrevPage() {
    if (_pdfCurrentPage > 1) {
      _pdfCurrentPage--;
      _emit('pdf-page', {'page': _pdfCurrentPage});
      setState(() {});
    }
  }

  void _pdfNextPage() {
    if (_pdfTotalPages > 0 && _pdfCurrentPage >= _pdfTotalPages) return;
    _pdfCurrentPage++;
    _emit('pdf-page', {'page': _pdfCurrentPage});
    setState(() {});
  }

  void _deleteUploadedFile(int idx) {
    setState(() {
      final deletedUrl = _uploadedFiles[idx]['url'] as String? ?? '';
      _uploadedFiles.removeAt(idx);
      if (_activeFileIndex >= _uploadedFiles.length) {
        _activeFileIndex = _uploadedFiles.length - 1;
      }
      if (_activeFileIndex < 0) _activeFileIndex = -1;
      // If the deleted file was being cast, clear it
      if (deletedUrl == _currentlyCastUrl) {
        _currentlyCastUrl = '';
      }
    });
  }

  // ══════════════════ UPLOAD BACKGROUND IMAGE ══════════════════
  Future<void> _uploadBgImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final filePath = pickedFile.path;
      if (filePath == null) return;

      final fileName = pickedFile.name;
      final fileExt = fileName.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(fileExt)) {
        _showSnack('Sirf image files allowed hain (JPG, PNG, WEBP)!', error: true);
        return;
      }

      setState(() => _isUploadingBg = true);

      final file = File(filePath);
      final bytes = await file.readAsBytes();

      final uri = Uri.parse('http://127.0.0.1:3000/api/upload?name=${Uri.encodeComponent(fileName)}');
      final response = await http.post(uri, body: bytes);

      setState(() => _isUploadingBg = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final uploadedUrl = data['url'] as String? ?? '';

        // Build the full URL for the TV to access
        // Use device IP instead of 127.0.0.1 so TV can access the image
        final ip = _deviceIp == '...' ? '127.0.0.1' : _deviceIp;
        final fullUrl = 'http://$ip:3000$uploadedUrl';

        setState(() {
          _uploadedBgs.insert(0, {
            'name': fileName,
            'url': fullUrl,
          });
          _bgUrl = fullUrl;
        });

        _emit('update-background', {'url': fullUrl});
        _showSnack('Background set ho gaya!');
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  IconData _fileIcon(String type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'pptx': return Icons.slideshow;
      default: return Icons.insert_drive_file;
    }
  }

  Color _fileColor(String type) {
    switch (type) {
      case 'pdf': return Colors.red.shade400;
      case 'pptx': return Colors.orange.shade400;
      default: return kMuted;
    }
  }

  void _copyUrl() {
    final ip = _deviceIp == '...' ? '<DEVICE_IP>' : _deviceIp;
    Clipboard.setData(ClipboardData(text: 'http://$ip:3000/tv.html'));
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

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _tabController.dispose();
    _addTitleCtrl.dispose();
    _addContentCtrl.dispose();
    _songSearchCtrl.dispose();
    _songTitleCtrl.dispose();
    for (final c in _songStanzaCtrls) { c.dispose(); }
    super.dispose();
  }

  // ═══════════════════════════ BUILD ═══════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      body: Column(children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_slidesTab(), _bibleTab(), _songsTab(), _filesTab(), _settingsTab()],
          ),
        ),
        _bottomUrlBar(),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: kBg2,
    elevation: 0,
    titleSpacing: 16,
    title: Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kAccent, Color(0xFF6366F1)]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.cast, size: 18, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('BiblePresenter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)),
        Row(children: [
          Icon(Icons.circle, size: 7, color: _connected ? Colors.green : Colors.red),
          const SizedBox(width: 5),
          Text(
            _serverStarted ? (_connected ? 'Server live' : 'Connecting...') : 'Starting server...',
            style: TextStyle(fontSize: 9, color: _connected ? Colors.green : kMuted),
          ),
        ]),
      ]),
    ]),
    actions: [
      TextButton(
        onPressed: _clearScreen,
        child: const Text('Blackout', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 4),
    ],
  );

  Widget _buildTabBar() => Container(
    color: const Color(0xFF080f1e),
    child: TabBar(
      controller: _tabController,
      indicatorColor: kAccent,
      indicatorWeight: 2,
      labelColor: kAccent,
      unselectedLabelColor: kMuted,
      labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
      tabs: const [
        Tab(icon: Icon(Icons.slideshow, size: 15), text: 'SLIDES'),
        Tab(icon: Icon(Icons.menu_book, size: 15), text: 'BIBLE'),
        Tab(icon: Icon(Icons.music_note, size: 15), text: 'SONGS'),
        Tab(icon: Icon(Icons.upload_file, size: 15), text: 'FILES'),
        Tab(icon: Icon(Icons.tune, size: 15), text: 'SETTINGS'),
      ],
    ),
  );

  // ══════════════════ SLIDES TAB ══════════════════
  Widget _slidesTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(14),
    child: Column(children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _label('ACTIVE SLIDE'),
          _pill('${_activeSlide + 1} / ${_slides.length}'),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_slides[_activeSlide]['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: kText, fontSize: 14, letterSpacing: 0.5)),
            if ((_slides[_activeSlide]['text'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('"${_slides[_activeSlide]['text']}"', style: const TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _secondaryBtn('Prev', _activeSlide > 0 ? () => _castSlide(_activeSlide - 1) : null)),
          const SizedBox(width: 8),
          Expanded(child: _secondaryBtn('Next', _activeSlide < _slides.length - 1 ? () => _castSlide(_activeSlide + 1) : null)),
        ]),
        const SizedBox(height: 8),
        _primaryBtn('Cast to TV', () => _castSlide(_activeSlide)),
      ])),
      const SizedBox(height: 12),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _label('QUEUE'),
          GestureDetector(
            onTap: _showAddSlideModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade800.withOpacity(0.5)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 12, color: Colors.green),
                SizedBox(width: 4),
                Text('Add', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ..._slides.asMap().entries.map((e) {
          final active = e.key == _activeSlide;
          return GestureDetector(
            onTap: () => _castSlide(e.key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF0c1f3a) : kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: active ? kAccent.withOpacity(0.7) : kBorder),
              ),
              child: Row(children: [
                Text('${e.key + 1}', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: active ? kAccent : kMuted)),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value['title'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? kText : kMuted))),
                if (active) const Icon(Icons.cast, size: 13, color: kAccent),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () { if (_slides.length > 1) _deleteSlide(e.key); },
                  child: Icon(Icons.delete_outline, size: 14, color: _slides.length > 1 ? Colors.red.shade400 : Colors.white12),
                ),
              ]),
            ),
          );
        }),
      ])),
    ]),
  );

  void _showAddSlideModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Add New Slide', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)),
            IconButton(icon: const Icon(Icons.close, color: kMuted), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 14),
          _inputField(_addTitleCtrl, 'Slide Title', 'e.g. Welcome to Church'),
          const SizedBox(height: 10),
          _inputField(_addContentCtrl, 'Content', 'Enter slide text here...', maxLines: 3),
          const SizedBox(height: 16),
          _primaryBtn('Save & Cast', _addSlide),
        ]),
      ),
    );
  }

  // ══════════════════ BIBLE TAB ══════════════════
  Widget _bibleTab() {
    if (!_bibleLoaded) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kAccent),
          SizedBox(height: 16),
          Text('Loading Bible data...', style: TextStyle(color: kMuted, fontSize: 13)),
        ],
      ));
    }

    final chapters = _bible[_selBook] ?? {};
    final verses = chapters[_selChapter] ?? {};
    final v = verses[_selVerse];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('SELECT SCRIPTURE'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _dropdownField<String>(
            label: 'Book', value: _selBook,
            items: _bible.keys.toList(),
            display: (v) => v,
            onChanged: (val) => setState(() {
              _selBook = val;
              _selChapter = _bible[val]!.keys.first;
              _selVerse = _bible[val]![_selChapter]!.keys.first;
            }),
          )),
          const SizedBox(width: 8),
          Expanded(child: _dropdownField<int>(
            label: 'Ch', value: _selChapter,
            items: (_bible[_selBook] ?? {}).keys.toList(),
            display: (v) => '$v',
            onChanged: (val) => setState(() {
              _selChapter = val;
              _selVerse = (_bible[_selBook]?[val] ?? {}).keys.first;
            }),
          )),
          const SizedBox(width: 8),
          Expanded(child: _dropdownField<int>(
            label: 'Vs', value: _selVerse,
            items: (_bible[_selBook]?[_selChapter] ?? {}).keys.toList(),
            display: (v) => '$v',
            onChanged: (val) => setState(() => _selVerse = val),
          )),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_selBook $_selChapter:$_selVerse', style: const TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 11)),
            if (v?['hi'] != null && (v!['hi']!.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Text(v['hi']!, style: const TextStyle(color: kGold, fontSize: 13, height: 1.5)),
            ],
            if (v?['en'] != null && (v!['en']!.isNotEmpty)) ...[
              const SizedBox(height: 6),
              Text('"${v['en']}"', style: const TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic, height: 1.5)),
            ],
            if (v == null) const Text('Verse not available', style: TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _secondaryBtn('Prev', _prevVerse)),
          const SizedBox(width: 8),
          Expanded(child: _secondaryBtn('Next', _nextVerse)),
        ]),
        const SizedBox(height: 10),
        // Font size control in Bible tab
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _label('FONT SIZE'),
          Text('$_fontSize px', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kGold, thumbColor: kGold,
            inactiveTrackColor: kBorder, overlayColor: kGold.withOpacity(0.1),
          ),
          child: Slider(min: 24, max: 80, divisions: 56, value: _fontSize.toDouble(), onChanged: (v) => setState(() => _fontSize = v.round())),
        ),
        const SizedBox(height: 6),
        _primaryBtn('Cast Scripture to TV', _castVerse),
      ])),
    );
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

  // ══════════════════ SONGS TAB ══════════════════
  Widget _songsTab() {
    if (!_songsLoaded) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kAccent),
          SizedBox(height: 16),
          Text('Loading songs...', style: TextStyle(color: kMuted, fontSize: 13)),
        ],
      ));
    }

    final selectedSong = _selectedSongIndex >= 0 && _selectedSongIndex < _filteredSongs.length
        ? _filteredSongs[_selectedSongIndex] : null;
    final stanzas = selectedSong?['stanzas'] as List<String>? ?? [];
    final currentStanza = _selectedStanzaIndex < stanzas.length ? stanzas[_selectedStanzaIndex] : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Search bar
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('SEARCH SONGS'),
          const SizedBox(height: 8),
          TextField(
            controller: _songSearchCtrl,
            style: const TextStyle(color: kText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by title or lyrics...',
              hintStyle: const TextStyle(color: kMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 18, color: kAccent),
              filled: true, fillColor: kBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kAccent)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _songSearchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 16, color: kMuted), onPressed: () { _songSearchCtrl.clear(); _filterSongs(''); })
                  : null,
            ),
            onChanged: _filterSongs,
          ),
          if (_songSearchQuery.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('${_filteredSongs.length} songs found', style: const TextStyle(color: kMuted, fontSize: 9))),
        ])),

        const SizedBox(height: 10),

        // Add Song button
        GestureDetector(
          onTap: _showAddSongModal,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.green.shade900.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade800.withOpacity(0.4)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add, size: 16, color: Colors.green),
              SizedBox(width: 6),
              Text('Add Song', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),

        const SizedBox(height: 10),

        // Song list (show limited results)
        if (_filteredSongs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              const Icon(Icons.music_off, size: 28, color: Color(0xFF1a2d45)),
              const SizedBox(height: 8),
              Text(_songSearchQuery.isEmpty ? 'No songs loaded' : 'Koi song nahi mila', style: const TextStyle(color: kMuted, fontSize: 11)),
            ]),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _filteredSongs.length > 30 ? 30 : _filteredSongs.length,
              itemBuilder: (ctx, i) {
                final song = _filteredSongs[i];
                final isSelected = i == _selectedSongIndex;
                final isManual = song['source'] == 'manual';
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSongIndex = i;
                      _selectedStanzaIndex = 0;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0c1f3a) : kBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? kAccent.withOpacity(0.7) : kBorder),
                    ),
                    child: Row(children: [
                      Icon(isManual ? Icons.edit_note : Icons.library_music, size: 14, color: isSelected ? kAccent : kMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(song['title'] as String? ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? kText : kMuted), overflow: TextOverflow.ellipsis, maxLines: 1)),
                      if (isSelected) const Icon(Icons.check_circle, size: 12, color: kAccent),
                      if (isManual) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _deleteSong(i),
                          child: Icon(Icons.delete_outline, size: 12, color: Colors.red.shade400),
                        ),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 10),

        // Selected song preview + stanza control
        if (selectedSong != null) _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(selectedSong['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: kGold, fontSize: 13), overflow: TextOverflow.ellipsis)),
            Text('${_selectedStanzaIndex + 1} / ${stanzas.length}', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 10)),
          ]),
          const SizedBox(height: 8),
          // Stanza preview box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kGold.withOpacity(0.2))),
            child: Text(currentStanza, style: const TextStyle(color: kText, fontSize: 12, height: 1.6)),
          ),
          const SizedBox(height: 10),
          // Stanza navigation — dot indicators + prev/next
          if (stanzas.length > 1) Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(stanzas.length, (i) {
              final isActive = i == _selectedStanzaIndex;
              return GestureDetector(
                onTap: () { _selectedStanzaIndex = i; _castSong(); setState(() {}); },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? kGold : kBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          if (stanzas.length > 1) const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _secondaryBtn('Prev', _selectedStanzaIndex > 0 ? _prevStanza : null)),
            const SizedBox(width: 8),
            Expanded(child: _primaryBtn('Cast', _castSong)),
            const SizedBox(width: 8),
            Expanded(child: _secondaryBtn('Next', _selectedStanzaIndex < stanzas.length - 1 ? _nextStanza : null)),
          ]),
        ])),
      ]),
    );
  }

  void _showAddSongModal() {
    // Reset stanza controllers for fresh entry — start with 2 stanza boxes
    for (final c in _songStanzaCtrls) { c.dispose(); }
    _songStanzaCtrls = [TextEditingController(), TextEditingController()];
    _songTitleCtrl.clear();

    showModalBottomSheet(
      context: context,
      backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Add New Song', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)),
                  IconButton(icon: const Icon(Icons.close, color: kMuted), onPressed: () => Navigator.pop(context)),
                ]),
                const SizedBox(height: 12),
                _inputField(_songTitleCtrl, 'Song Title', 'e.g. Yeshu Tera Naam'),
                const SizedBox(height: 12),
                // Stanza boxes — each has its own labeled box
                ...List.generate(_songStanzaCtrls.length, (i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: kGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Center(child: Text('${i + 1}', style: const TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(width: 8),
                          Text('Stanza ${i + 1}', style: const TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                        if (_songStanzaCtrls.length > 1)
                          GestureDetector(
                            onTap: () {
                              _songStanzaCtrls[i].dispose();
                              _songStanzaCtrls.removeAt(i);
                              setModalState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.close, size: 10, color: Colors.red.shade400),
                                SizedBox(width: 3),
                                Text('Remove', style: TextStyle(fontSize: 8, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _songStanzaCtrls[i],
                        style: const TextStyle(color: kText, fontSize: 12, height: 1.5),
                        maxLines: 5,
                        minLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter stanza ${i + 1} lyrics here...',
                          hintStyle: const TextStyle(color: kMuted, fontSize: 11),
                          filled: true, fillColor: kBg3,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kGold, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ]),
                  );
                }),
                // Add Stanza button
                GestureDetector(
                  onTap: () {
                    _songStanzaCtrls.add(TextEditingController());
                    setModalState(() {});
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade800.withOpacity(0.3)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add, size: 16, color: Colors.green),
                      SizedBox(width: 6),
                      Text('Add More Stanza', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                _primaryBtn('Save Song', _addManualSong),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════ FILES TAB ══════════════════
  Widget _filesTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(14),
    child: Column(children: [
      // Upload button
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('UPLOAD PDF / PPT'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _isUploading ? null : _pickAndUploadFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isUploading ? kAccent.withOpacity(0.3) : kBorder,
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: _isUploading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Uploading...', style: TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  )
                : const Column(
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 32, color: kAccent),
                      SizedBox(height: 8),
                      Text('Tap to Upload PDF / PPT', style: TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('PDF, PPT, PPTX files supported', style: TextStyle(color: kMuted, fontSize: 10)),
                    ],
                  ),
          ),
        ),
      ])),

      const SizedBox(height: 12),

      // PDF page navigation (visible when PDF is being cast)
      if (_tvState['type'] == 'pdf') _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('PDF PAGE CONTROL'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kAccent.withOpacity(0.3))),
          child: Column(children: [
            Text(
              'Page $_pdfCurrentPage ${_pdfTotalPages > 0 ? "/ $_pdfTotalPages" : ""}',
              style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _secondaryBtn('Prev Page', _pdfCurrentPage > 1 ? _pdfPrevPage : null)),
              const SizedBox(width: 8),
              Expanded(child: _secondaryBtn('Next Page', (_pdfTotalPages == 0 || _pdfCurrentPage < _pdfTotalPages) ? _pdfNextPage : null)),
            ]),
          ]),
        ),
      ])),

      const SizedBox(height: 12),

      // Uploaded files list
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _label('UPLOADED FILES'),
          if (_uploadedFiles.isNotEmpty)
            Text('${_uploadedFiles.length}', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 10)),
        ]),
        const SizedBox(height: 10),

        if (_uploadedFiles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: const Column(children: [
              Icon(Icons.folder_open, size: 28, color: Color(0xFF1a2d45)),
              SizedBox(height: 8),
              Text('Koi file upload nahi ki hai', style: TextStyle(color: kMuted, fontSize: 11)),
              Text('PDF ya PPT upload karke TV pe dikhao', style: TextStyle(color: Color(0xFF1a2d45), fontSize: 9)),
            ]),
          )
        else
          ..._uploadedFiles.asMap().entries.map((entry) {
            final idx = entry.key;
            final f = entry.value;
            final isActive = idx == _activeFileIndex && _tvState['type'] != 'idle';
            final fileType = f['type'] as String? ?? 'other';
            final fileName = f['name'] as String? ?? 'Unknown';
            final fileSize = f['size'] as int? ?? 0;
            final isPdf = fileType == 'pdf';
            final isPpt = fileType == 'pptx';
            final localPath = f['localPath'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF0c1f3a) : kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? kAccent.withOpacity(0.7) : kBorder),
              ),
              child: Column(children: [
                Row(children: [
                  // Preview thumbnail
                  _buildFilePreview(fileType, localPath, isActive),
                  const SizedBox(width: 10),

                  // File info
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? kText : kMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _fileColor(fileType).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPdf ? 'PDF' : (isPpt ? 'PPT' : 'FILE'),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: _fileColor(fileType),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatFileSize(fileSize),
                        style: const TextStyle(fontSize: 9, color: kMuted, fontFamily: 'monospace'),
                      ),
                    ]),
                  ])),

                  // Cast / Active indicator
                  if (isActive)
                    const Icon(Icons.cast, size: 16, color: kAccent)
                  else
                    GestureDetector(
                      onTap: () => _castFile(idx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kAccent.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.cast, size: 16, color: kAccent),
                      ),
                    ),

                  const SizedBox(width: 6),

                  // Delete button
                  GestureDetector(
                    onTap: () => _deleteUploadedFile(idx),
                    child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                  ),
                ]),

                // Cast button for non-active files
                if (!isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: _castFileBtn(
                        isPdf ? 'Cast PDF to TV' : 'Cast PPT to TV',
                        () => _castFile(idx),
                      ),
                    ),
                  ),
              ]),
            );
          }),
      ])),
    ]),
  );

  // ── File preview widget ──
  Widget _buildFilePreview(String fileType, String localPath, bool isActive) {
    if (fileType == 'pdf' && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Container(
          width: 52,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isActive ? kAccent.withOpacity(0.5) : kBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(children: [
              // PDF first page rendered via server URL
              Center(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 24, height: 24,
                  errorBuilder: (_, __, ___) => const Icon(Icons.picture_as_pdf, size: 24, color: Colors.red),
                ),
              ),
              // PDF label overlay
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.red.shade700,
                  child: const Text(
                    'PDF',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ]),
          ),
        );
      }
    }

    if (fileType == 'pptx') {
      return Container(
        width: 52,
        height: 68,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD04423), Color(0xFFF07030)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? kAccent.withOpacity(0.5) : kBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.slideshow, size: 22, color: Colors.white),
            SizedBox(height: 2),
            Text('PPT', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
      );
    }

    // Default file icon
    return Container(
      width: 52,
      height: 68,
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isActive ? kAccent.withOpacity(0.5) : kBorder),
      ),
      child: const Icon(Icons.insert_drive_file, size: 22, color: kMuted),
    );
  }

  Widget _castFileBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: kAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccent.withOpacity(0.3)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cast, size: 13, color: kAccent),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kAccent, letterSpacing: 0.3)),
        ],
      ),
    ),
  );

  // ══════════════════ SETTINGS TAB ══════════════════
  Widget _settingsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(14),
    child: Column(children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _label('FONT SIZE'),
          Text('$_fontSize px', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kAccent, thumbColor: kAccent,
            inactiveTrackColor: kBorder, overlayColor: kAccent.withOpacity(0.1),
          ),
          child: Slider(min: 24, max: 80, divisions: 56, value: _fontSize.toDouble(), onChanged: (v) => setState(() => _fontSize = v.round())),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Small', style: TextStyle(fontSize: 9, color: kMuted)),
          const Text('Large', style: TextStyle(fontSize: 9, color: kMuted)),
        ]),
      ])),
      const SizedBox(height: 12),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('TV BACKGROUND'),
        const SizedBox(height: 12),
        // Upload custom background button
        GestureDetector(
          onTap: _isUploadingBg ? null : _uploadBgImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAccent.withOpacity(0.3), width: 1.5),
            ),
            child: _isUploadingBg
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Uploading...', style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ])
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 18, color: kAccent),
                    SizedBox(width: 8),
                    Text('Upload Background Image', style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            GestureDetector(
              onTap: () { setState(() => _bgUrl = null); _emit('update-background', {}); },
              child: Container(
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bgUrl == null ? kAccent : kBorder, width: _bgUrl == null ? 2 : 1),
                ),
                alignment: Alignment.center,
                child: Text('None', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _bgUrl == null ? kAccent : kMuted)),
              ),
            ),
            // Uploaded backgrounds (with delete button)
            ..._uploadedBgs.asMap().entries.map((entry) {
              final bgIdx = entry.key;
              final bg = entry.value;
              final isSelected = _bgUrl == bg['url'];
              return GestureDetector(
                onTap: () {
                  setState(() => _bgUrl = bg['url']);
                  _emit('update-background', {'url': bg['url']});
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? kAccent : kBorder, width: isSelected ? 2 : 1),
                    image: DecorationImage(image: NetworkImage(bg['url']!), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)),
                  ),
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    Expanded(child: Text(bg['name']!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis)),
                    if (isSelected) const Icon(Icons.check_circle, size: 12, color: kAccent),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_bgUrl == bg['url']) {
                            _bgUrl = null;
                            _emit('update-background', {});
                          }
                          _uploadedBgs.removeAt(bgIdx);
                        });
                        _showSnack('Background deleted');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.delete_outline, size: 11, color: Color(0xFFFCA5A5)),
                      ),
                    ),
                  ]),
                ),
              );
            }),
            // Preset backgrounds
            ..._presetBgs.map((bg) => GestureDetector(
              onTap: () {
                setState(() => _bgUrl = bg['url']);
                _emit('update-background', {'url': bg['url']});
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bgUrl == bg['url'] ? kAccent : kBorder, width: _bgUrl == bg['url'] ? 2 : 1),
                  image: DecorationImage(image: NetworkImage(bg['url']!), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(child: Text(bg['name']!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
                  if (_bgUrl == bg['url']) const Icon(Icons.check_circle, size: 12, color: kAccent),
                ]),
              ),
            )),
          ],
        ),
      ])),
      const SizedBox(height: 12),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('SERVER STATUS'),
        const SizedBox(height: 10),
        _infoRow('Server', _serverStarted ? 'Running' : 'Not started', _serverStarted ? Colors.green : Colors.red),
        _infoRow('WebSocket', _connected ? 'Connected' : 'Disconnected', _connected ? Colors.green : Colors.red),
        _infoRow('Device IP', _deviceIp, kAccent),
        _infoRow('TV URL', 'http://${_deviceIp == '...' ? '<IP>' : _deviceIp}:3000/tv.html', kAccent),
        const SizedBox(height: 8),
        _secondaryBtn('Reconnect', _connectWS),
      ])),
    ]),
  );

  Widget _infoRow(String label, String value, Color valueColor) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 10, color: kMuted))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 11, color: valueColor, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
    ]),
  );

  // ══════════════════ BOTTOM URL BAR ══════════════════
  Widget _bottomUrlBar() => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
    decoration: const BoxDecoration(
      color: kBg2,
      border: Border(top: BorderSide(color: kBorder)),
    ),
    child: Row(children: [
      const Icon(Icons.wifi, size: 14, color: kAccent),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TV CASTING URL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: kMuted, letterSpacing: 1.5)),
        const SizedBox(height: 2),
        Text(
          'http://$_deviceIp:3000/tv.html',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: kAccent),
          overflow: TextOverflow.ellipsis,
        ),
      ])),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _copyUrl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: kAccent.withOpacity(0.4))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.copy, size: 12, color: kAccent),
            SizedBox(width: 4),
            Text('Copy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kAccent)),
          ]),
        ),
      ),
    ]),
  );

  // ══════════════════ REUSABLE WIDGETS ══════════════════
  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
    child: child,
  );

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kMuted, letterSpacing: 1.5));

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: kAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: kAccent.withOpacity(0.3))),
    child: Text(text, style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: kAccent)),
  );

  Widget _primaryBtn(String label, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: onTap != null ? kAccent : kBorder,
        borderRadius: BorderRadius.circular(12),
        boxShadow: onTap != null ? [BoxShadow(color: kAccent.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4))] : [],
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: onTap != null ? Colors.white : kMuted, letterSpacing: 0.5)),
    ),
  );

  Widget _secondaryBtn(String label, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: onTap != null ? kBorder : kBorder.withOpacity(0.3))),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: onTap != null ? kText : kMuted)),
    ),
  );

  Widget _inputField(TextEditingController ctrl, String label, String hint, {int maxLines = 1}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kMuted, letterSpacing: 1.5)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: kText, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: kMuted, fontSize: 12),
          filled: true, fillColor: kBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kAccent)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ],
  );

  Widget _dropdownField<T>({
    required String label, required T value,
    required List<T> items, required String Function(T) display,
    required void Function(T) onChanged,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 8, color: kMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
    const SizedBox(height: 4),
    Container(
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
          isExpanded: true,
          dropdownColor: kBg3,
          style: const TextStyle(color: kText, fontSize: 11),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(display(i), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    ),
  ]);
}
