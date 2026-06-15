import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Schedule state model
class ScheduleState extends ChangeNotifier {
  List<Map<String, dynamic>> _schedules = [];
  bool _scheduleMode = false;
  int _activeScheduleIndex = -1;
  int _scheduleSongIndex = 0;
  int _scheduleStanzaIndex = 0;
  final TextEditingController _scheduleNameController = TextEditingController();
  DateTime _scheduleDate = DateTime.now();

  ScheduleState() {
    _loadSchedules();
  }

  // Getters
  List<Map<String, dynamic>> get schedules => _schedules;
  bool get scheduleMode => _scheduleMode;
  int get activeScheduleIndex => _activeScheduleIndex;
  int get scheduleSongIndex => _scheduleSongIndex;
  int get scheduleStanzaIndex => _scheduleStanzaIndex;
  TextEditingController get scheduleNameController => _scheduleNameController;
  DateTime get scheduleDate => _scheduleDate;

  // Provider pattern
  static ScheduleState of(BuildContext context) {
    return context.read<ScheduleState>();
  }

  // Setters
  set scheduleMode(bool mode) {
    if (_scheduleMode != mode) {
      _scheduleMode = mode;
      if (!mode) {
        _activeScheduleIndex = -1;
        _scheduleSongIndex = 0;
        _scheduleStanzaIndex = 0;
      }
      notifyListeners();
    }
  }

  set activeScheduleIndex(int index) {
    if (_activeScheduleIndex != index) {
      _activeScheduleIndex = index.clamp(-1, _schedules.length - 1);
      if (_activeScheduleIndex >= 0) {
        _scheduleSongIndex = 0;
        _scheduleStanzaIndex = 0;
      }
      notifyListeners();
    }
  }

  set scheduleSongIndex(int index) {
    if (_scheduleSongIndex != index && _activeScheduleIndex >= 0) {
      final songs = _schedules[_activeScheduleIndex]['songs'] as List? ?? [];
      if (songs.isEmpty) {
        _scheduleSongIndex = 0;
        _scheduleStanzaIndex = 0;
        notifyListeners();
        return;
      }
      _scheduleSongIndex = index.clamp(0, songs.length - 1);
      _scheduleStanzaIndex = 0;
      notifyListeners();
    }
  }

  set scheduleStanzaIndex(int index) {
    if (_scheduleStanzaIndex != index && _activeScheduleIndex >= 0) {
      final songs = _schedules[_activeScheduleIndex]['songs'] as List? ?? [];
      if (_scheduleSongIndex < songs.length) {
        final stanzas =
            songs[_scheduleSongIndex]['stanzas'] as List<String>? ?? [];
        if (stanzas.isEmpty) {
          _scheduleStanzaIndex = 0;
          notifyListeners();
          return;
        }
        _scheduleStanzaIndex = index.clamp(0, stanzas.length - 1);
      }
      notifyListeners();
    }
  }

  set scheduleDate(DateTime date) {
    if (_scheduleDate != date) {
      _scheduleDate = date;
      notifyListeners();
    }
  }

  // Public methods
  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('song_schedules') ?? '[]';
      final List<dynamic> data = jsonDecode(str) as List<dynamic>;
      _schedules = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (_) {
      _schedules = [];
      notifyListeners();
    }
  }

  Future<void> saveSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('song_schedules', jsonEncode(_schedules));
    } catch (_) {}
  }

  Future<void> _saveSchedules() async {
    await saveSchedules();
  }

  void createSchedule(String name, String dateStr) {
    if (name.trim().isEmpty) return;
    _schedules.insert(0, {
      'name': name.trim(),
      'date': dateStr,
      'songs': <Map<String, dynamic>>[]
    });
    _activeScheduleIndex = 0;
    _scheduleNameController.clear();
    _saveSchedules();
    notifyListeners();
  }

  void addSongToSchedule(int scheduleIdx, Map<String, dynamic> song) {
    if (scheduleIdx < 0 || scheduleIdx >= _schedules.length) return;
    // Ensure song has required fields
    final title = song['title'] ?? '';
    final stanzas = List<String>.from(song['stanzas'] ?? []);
    final songs =
        List<Map<String, dynamic>>.from(_schedules[scheduleIdx]['songs'] ?? []);
    songs.add({
      'title': title,
      'stanzas': stanzas,
    });
    _schedules[scheduleIdx]['songs'] = songs;
    _saveSchedules();
    notifyListeners();
  }

  void removeSongFromSchedule(int scheduleIdx, int songPosition) {
    if (scheduleIdx < 0 || scheduleIdx >= _schedules.length) return;
    final songs =
        List<Map<String, dynamic>>.from(_schedules[scheduleIdx]['songs'] ?? []);
    if (songPosition < songs.length) {
      songs.removeAt(songPosition);
      _schedules[scheduleIdx]['songs'] = songs;
    }
    _saveSchedules();
    notifyListeners();
  }

  void deleteSchedule(int idx) {
    if (idx < 0 || idx >= _schedules.length) return;
    _schedules.removeAt(idx);
    if (_activeScheduleIndex >= _schedules.length) {
      _activeScheduleIndex = _schedules.length - 1;
    }
    if (_activeScheduleIndex < 0) {
      _activeScheduleIndex = -1;
    }
    _scheduleMode = false;
    _saveSchedules();
    notifyListeners();
  }

  void startSchedulePresentation(int scheduleIdx) {
    if (scheduleIdx < 0 || scheduleIdx >= _schedules.length) return;
    final songs = _schedules[scheduleIdx]['songs'] as List? ?? [];
    if (songs.isEmpty) {
      // TODO: Show error
      return;
    }
    _scheduleMode = true;
    _activeScheduleIndex = scheduleIdx;
    _scheduleSongIndex = 0;
    _scheduleStanzaIndex = 0;
    notifyListeners();
  }

  void exitScheduleMode() {
    _scheduleMode = false;
    _scheduleSongIndex = 0;
    _scheduleStanzaIndex = 0;
    if (scheduleNameController.text.isNotEmpty) {
      scheduleNameController.clear();
    }
    notifyListeners();
  }

  void disposeController() {
    _scheduleNameController.dispose();
  }

  @override
  void dispose() {
    disposeController();
    super.dispose();
  }
}

// Provider accessors
ScheduleState scheduleStateOf(BuildContext context, {bool listen = true}) =>
    Provider.of<ScheduleState>(context, listen: listen);

ScheduleState? scheduleStateMaybeOf(BuildContext context) =>
    context.read<ScheduleState?>();
