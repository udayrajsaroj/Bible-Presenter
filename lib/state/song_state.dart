import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Song state model
class SongState extends ChangeNotifier {
  List<Map<String, dynamic>> _allSongs = [];
  List<Map<String, dynamic>> _filteredSongs = [];
  bool _songsLoaded = false;
  String _songSearchQuery = '';
  int _selectedSongIndex = -1;
  int _selectedStanzaIndex = 0;
  final TextEditingController _songSearchController = TextEditingController();
  final TextEditingController _songTitleController = TextEditingController();
  final List<TextEditingController> _songStanzaControllers = [
    TextEditingController(),
    TextEditingController()
  ];

  SongState() {
    _loadSongs();
  }

  // Getters
  List<Map<String, dynamic>> get allSongs => _allSongs;
  List<Map<String, dynamic>> get filteredSongs => _filteredSongs;
  bool get songsLoaded => _songsLoaded;
  String get songSearchQuery => _songSearchQuery;
  int get selectedSongIndex => _selectedSongIndex;
  int get selectedStanzaIndex => _selectedStanzaIndex;
  TextEditingController get songSearchController => _songSearchController;
  TextEditingController get songTitleController => _songTitleController;
  List<TextEditingController> get songStanzaControllers =>
      _songStanzaControllers;

  // Selected song access
  Map<String, dynamic>? get selectedSong =>
      _selectedSongIndex >= 0 && _selectedSongIndex < _filteredSongs.length
          ? _filteredSongs[_selectedSongIndex]
          : null;
  List<String>? get selectedSongStanzas =>
      selectedSong?['stanzas'] as List<String>?;
  String? get currentStanza =>
      _selectedStanzaIndex < (selectedSongStanzas?.length ?? 0)
          ? selectedSongStanzas![_selectedStanzaIndex]
          : '';

  // Provider pattern
  static SongState of(BuildContext context) {
    return context.read<SongState>();
  }

  // Setters
  set songSearchQuery(String query) {
    if (_songSearchQuery != query) {
      _songSearchQuery = query.toLowerCase().trim();
      _filterSongs();
      // _filterSongs() handles notifyListeners() internally
    }
  }

  set selectedSongIndex(int index) {
    if (_selectedSongIndex != index) {
      _selectedSongIndex = index.clamp(-1, _filteredSongs.length - 1);
      _selectedStanzaIndex = 0; // Reset stanza when song changes
      notifyListeners();
    }
  }

  set selectedStanzaIndex(int index) {
    if (_selectedStanzaIndex != index && selectedSong != null) {
      final maxIndex = (selectedSongStanzas?.length ?? 0) - 1;
      _selectedStanzaIndex = index.clamp(0, maxIndex);
      notifyListeners();
    }
  }

  // Public methods
  Future<void> _loadSongs() async {
    try {
      final songsJsonStr = await rootBundle.loadString('assets/songs.json');
      final List<dynamic> assetSongs =
          jsonDecode(songsJsonStr) as List<dynamic>;
      final List<Map<String, dynamic>> songs = [];
      for (final s in assetSongs) {
        songs.add({
          'title': s['title'] as String? ?? '',
          'stanzas': List<String>.from(s['stanzas'] as List? ?? []),
          'source': 'asset'
        });
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final manualSongsStr = prefs.getString('manual_songs') ?? '[]';
        final List<dynamic> manualSongs =
            jsonDecode(manualSongsStr) as List<dynamic>;
        for (final s in manualSongs) {
          songs.add({
            'title': s['title'] as String? ?? '',
            'stanzas': List<String>.from(s['stanzas'] as List? ?? []),
            'source': 'manual'
          });
        }
      } catch (_) {}
      _allSongs = songs;
      _filteredSongs = List.from(songs);
      _songsLoaded = true;
      notifyListeners();
    } catch (_) {
      _allSongs = [];
      _filteredSongs = [];
      _songsLoaded = true;
      notifyListeners();
    }
  }

  void _filterSongs() {
    if (_songSearchQuery.isEmpty) {
      _filteredSongs = List.from(_allSongs);
    } else {
      _filteredSongs = _allSongs.where((song) {
        final title = (song['title'] as String? ?? '').toLowerCase();
        if (title.contains(_songSearchQuery)) return true;
        final stanzas = song['stanzas'] as List<String>? ?? [];
        for (final stanza in stanzas) {
          if (stanza.toLowerCase().contains(_songSearchQuery)) return true;
        }
        return false;
      }).toList();
    }
    // Reset selection if current song no longer matches filter
    if (_filteredSongs.isEmpty) {
      _selectedSongIndex = -1;
    } else if (_selectedSongIndex >= _filteredSongs.length) {
      _selectedSongIndex = 0;
    } else if (_selectedSongIndex < 0) {
      _selectedSongIndex = 0;
    }
    _selectedStanzaIndex = 0;
    notifyListeners();
  }

  Future<void> saveManualSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final manualSongs =
          _allSongs.where((s) => s['source'] == 'manual').toList();
      await prefs.setString('manual_songs', jsonEncode(manualSongs));
    } catch (_) {}
  }

  Future<void> _saveManualSongs() async {
    await saveManualSongs();
  }

  void addManualSong() {
    final title = _songTitleController.text.trim();
    if (title.isEmpty) return;
    final stanzas = _songStanzaControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (stanzas.isEmpty) return;
    _allSongs
        .insert(0, {'title': title, 'stanzas': stanzas, 'source': 'manual'});
    _filteredSongs = List.from(_allSongs);
    _selectedSongIndex = 0;
    _selectedStanzaIndex = 0;
    clearSongControllers();
    _saveManualSongs();
    notifyListeners();
  }

  void deleteSong(int index) {
    if (index < 0 || index >= _allSongs.length) return;
    final song = _allSongs[index];
    if (song['source'] != 'manual') return;
    _allSongs.removeAt(index);
    _filteredSongs = List.from(_allSongs);
    if (_selectedSongIndex >= _allSongs.length) {
      _selectedSongIndex = _allSongs.length - 1;
    }
    if (_selectedSongIndex < 0) {
      _selectedSongIndex = -1;
    }
    _selectedStanzaIndex = 0;
    _saveManualSongs();
    notifyListeners();
  }

  void clearSongControllers() {
    _songTitleController.clear();
    // Dispose old stanza controllers to avoid memory leaks
    for (final c in _songStanzaControllers) {
      c.dispose();
    }
    _songStanzaControllers.clear();
    _songStanzaControllers
        .addAll([TextEditingController(), TextEditingController()]);
  }

  void addStanzaController() {
    _songStanzaControllers.add(TextEditingController());
    notifyListeners();
  }

  void disposeControllers() {
    _songSearchController.dispose();
    _songTitleController.dispose();
    for (final c in _songStanzaControllers) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }
}

// Provider accessors
SongState songStateOf(BuildContext context, {bool listen = true}) =>
    Provider.of<SongState>(context, listen: listen);

SongState? songStateMaybeOf(BuildContext context) => context.read<SongState?>();
