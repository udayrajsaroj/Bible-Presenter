import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'tv_html.dart';

// ── Global state (shared within same isolate) ──
final List<WebSocketChannel> _clients = [];
Map<String, dynamic> _currentState = {
  'type': 'idle',
  'content': null,
  'fontSize': 44,
  'background': null,
};

// ── Upload directory (set from app's persistent storage) ──
String _uploadDir = '';

void _broadcast(Map<String, dynamic> data) {
  final msg = jsonEncode(data);
  final deadClients = <WebSocketChannel>[];
  for (final c in List.from(_clients)) {
    try {
      c.sink.add(msg);
    } catch (e) {
      deadClients.add(c);
    }
  }
  for (final c in deadClients) {
    _clients.remove(c);
  }
}

// ── MIME type helper ──
String _contentType(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  const types = {
    'pdf': 'application/pdf',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    // Video (Feature 2). MP4/H.264 is the reliable recommendation across TV
    // browsers and DLNA players; browsers vary on mkv.
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'webm': 'video/webm',
    'mov': 'video/quicktime',
    'mkv': 'video/x-matroska',
    'avi': 'video/x-msvideo',
  };
  return types[ext] ?? 'application/octet-stream';
}

// ── File type helper ──
String _fileType(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  if (ext == 'pdf') return 'pdf';
  if (ext == 'ppt' || ext == 'pptx') return 'pptx';
  if (['mp4', 'm4v', 'webm', 'mov', 'mkv', 'avi'].contains(ext)) {
    return 'video';
  }
  return 'other';
}

// ── Entry point for Isolate.spawn ──
Future<void> startServer(dynamic message) async {
  // Use persistent path passed from main isolate
  if (message is String && message.isNotEmpty) {
    _uploadDir = message;
  } else {
    _uploadDir = '${Directory.systemTemp.path}/biblepresenter_uploads';
  }

  // Ensure upload directory exists
  final dir = Directory(_uploadDir);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final router = Router();

  // ── CORS helper ──
  Response _cors(Response response) {
    return response.change(headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
  }

  // ── Serve TV page ──
  router.get(
      '/',
      (Request req) => _cors(Response.ok(
            tvHtmlContent,
            headers: {'Content-Type': 'text/html; charset=utf-8'},
          )));
  router.get(
      '/tv.html',
      (Request req) => _cors(Response.ok(
            tvHtmlContent,
            headers: {'Content-Type': 'text/html; charset=utf-8'},
          )));

  // ── REST: current state ──
  router.get(
      '/api/state',
      (Request req) => _cors(Response.ok(
            jsonEncode(_currentState),
            headers: {'Content-Type': 'application/json'},
          )));

  // ── Health check ──
  router.get(
      '/api/health',
      (Request req) => _cors(Response.ok(
            jsonEncode({'status': 'ok', 'clients': _clients.length}),
            headers: {'Content-Type': 'application/json'},
          )));

  // ── List uploaded files ──
  router.get('/api/uploads', (Request req) async {
    try {
      final dir = Directory(_uploadDir);
      if (!dir.existsSync()) {
        return _cors(Response.ok(jsonEncode([]),
            headers: {'Content-Type': 'application/json'}));
      }
      final imageExts = ['jpg', 'jpeg', 'png', 'webp', 'bmp'];
      final files = <Map<String, dynamic>>[];
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          final ext = name.split('.').last.toLowerCase();
          final stat = entity.statSync();
          files.add({
            'name': name,
            'url': '/uploads/$name',
            'type': imageExts.contains(ext) ? 'image' : _fileType(name),
            'size': stat.size,
            'modified': stat.modified.toIso8601String()
          });
        }
      }
      files.sort((a, b) => b['modified'].compareTo(a['modified']));
      return _cors(Response.ok(jsonEncode(files),
          headers: {'Content-Type': 'application/json'}));
    } catch (_) {
      return _cors(Response.ok(jsonEncode([]),
          headers: {'Content-Type': 'application/json'}));
    }
  });

  // ── File upload endpoint ──
  router.post('/api/upload', (Request req) async {
    IOSink? sink;
    try {
      final filename = req.requestedUri.queryParameters['name'] ?? 'upload.pdf';
      // Sanitize filename
      final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File('$_uploadDir/$safeName');

      // Stream the body straight to disk. Videos reach 1–2 GB (risk R4):
      // buffering the whole request in memory can exhaust the phone, so the
      // Shelf request stream writes incrementally and memory stays flat.
      int total = 0;
      sink = file.openWrite();
      await for (final chunk in req.read()) {
        total += chunk.length;
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      print('[Server] File uploaded: $safeName ($total bytes)');

      return _cors(Response.ok(
        jsonEncode({
          'url': '/uploads/$safeName',
          'name': safeName,
          'type': _fileType(safeName),
          'size': total,
        }),
        headers: {'Content-Type': 'application/json'},
      ));
    } catch (e) {
      await sink?.close();
      print('[Server] Upload error: $e');
      return _cors(Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      ));
    }
  });

  // ── Delete uploaded file ──
  router.delete('/api/upload/<filename>', (Request req, String filename) async {
    try {
      // Only remove path traversal (..) and take basename, preserve dots in filename
      final safeName = filename.replaceAll('..', '').split('/').last;
      final file = File('$_uploadDir/$safeName');
      if (await file.exists()) {
        await file.delete();
        print('[Server] File deleted: $safeName');
        return _cors(Response.ok(
          jsonEncode({'deleted': true, 'name': safeName}),
          headers: {'Content-Type': 'application/json'},
        ));
      }
      return _cors(Response.notFound(
        jsonEncode({'error': 'File not found'}),
        headers: {'Content-Type': 'application/json'},
      ));
    } catch (e) {
      print('[Server] Delete error: $e');
      return _cors(Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      ));
    }
  });

  // ── Serve uploaded files ──
  router.get('/uploads/<filename>', (Request req, String filename) async {
    try {
      // Sanitize: remove path traversal and take basename only
      final safeName = filename.replaceAll('..', '').split('/').last;
      final file = File('$_uploadDir/$safeName');
      if (!await file.exists()) {
        return Response.notFound('File not found');
      }
      final headers = {
        'Content-Type': _contentType(safeName),
        'Access-Control-Allow-Origin': '*',
        'Content-Disposition': 'inline; filename="$safeName"',
        'Cache-Control': 'no-cache',
        'Accept-Ranges': 'bytes',
      };

      // HTTP Range support: TV browsers request partial content so the
      // <video> element can seek inside 1 GB files without downloading
      // them first. Without a 206 response, video-seek remote control
      // would not work until the whole file is buffered.
      final stat = await file.stat();
      final rangeHeader = req.headers['range'];
      if (rangeHeader != null) {
        final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(rangeHeader);
        if (match != null) {
          final startStr = match.group(1);
          final endStr = match.group(2);
          int start = startStr != null && startStr.isNotEmpty
              ? int.parse(startStr)
              : 0;
          int end = endStr != null && endStr.isNotEmpty
              ? int.parse(endStr)
              : stat.size - 1;
          if (start >= stat.size) {
            return Response(
                416,
                body: 'Requested range not satisfiable',
                headers: {'Content-Range': 'bytes */${stat.size}'});
          }
          if (end >= stat.size) end = stat.size - 1;
          if (startStr == null || startStr.isEmpty) {
            // Suffix range (bytes=-N): last N bytes.
            final n = int.parse(endStr!);
            start = (stat.size - n).clamp(0, stat.size - 1);
            end = stat.size - 1;
          }
          final length = end - start + 1;
          final raf = await file.open();
          try {
            await raf.setPosition(start);
            final bytes = await raf.read(length);
            return Response(206, body: bytes, headers: {
              ...headers,
              'Content-Range': 'bytes $start-$end/${stat.size}',
              'Content-Length': '$length',
            });
          } finally {
            await raf.close();
          }
        }
      }

      final bytes = await file.readAsBytes();
      return Response.ok(bytes, headers: {
        ...headers,
        'Content-Length': '${stat.size}',
      });
    } catch (e) {
      return Response.internalServerError(body: 'Error: $e');
    }
  });

  // ── Serve DLNA slide images (TV Direct channel) ──
  // SlideRenderer writes PNGs into <uploadDir>/dlna/ from the main isolate;
  // this route serves them to the TV. no-store: the TV must never cache a
  // slide, or verse changes would show stale images.
  router.get('/dlna/<file>', (Request req, String file) async {
    try {
      final safeName = file.replaceAll('..', '').split('/').last;
      final f = File('$_uploadDir/dlna/$safeName');
      if (!await f.exists()) {
        return Response.notFound('no such slide');
      }
      return Response.ok(await f.readAsBytes(), headers: {
        'Content-Type': 'image/png',
        'Cache-Control': 'no-store',
        'Access-Control-Allow-Origin': '*',
      });
    } catch (e) {
      return Response.internalServerError(body: 'Error: $e');
    }
  });

  // ── WebSocket handler ──
  final wsHandler = webSocketHandler((WebSocketChannel channel, _) {
    _clients.add(channel);
    print('[Server] Client connected. Total: ${_clients.length}');

    try {
      channel.sink.add(jsonEncode(_currentState));
    } catch (_) {}

    channel.stream.listen(
      (raw) {
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          final event = msg['event'] as String? ?? '';
          final data = msg['data'] as Map<String, dynamic>? ?? {};

          switch (event) {
            case 'get-state':
              try {
                channel.sink.add(jsonEncode(_currentState));
              } catch (_) {}
              break;

            case 'cast-verse':
              _currentState = {
                'type': 'verse',
                'content': data,
                'fontSize': data['fontSize'] ?? 44,
                'background': data['background'] ?? _currentState['background'],
              };
              _broadcast(_currentState);
              break;

            case 'cast-slide':
              _currentState = {
                'type': 'slide',
                'content': data,
                'fontSize': data['fontSize'] ?? 44,
                'background': data['background'] ?? _currentState['background'],
              };
              _broadcast(_currentState);
              break;

            case 'cast-song':
              _currentState = {
                'type': 'song',
                'content': data,
                'fontSize': data['fontSize'] ?? 44,
                'background': data['background'] ?? _currentState['background'],
              };
              _broadcast(_currentState);
              break;

            case 'cast-logo':
              _currentState = {
                'type': 'logo',
                'content': data,
                'fontSize': data['fontSize'] ?? 44,
                'background': data['background'] ?? _currentState['background'],
              };
              _broadcast(_currentState);
              break;

            case 'cast-welcome':
              _currentState = {
                'type': 'welcome',
                'content': data,
                'fontSize': _currentState['fontSize'] ?? 44,
                'background': null, // Welcome screen has its own white bg
              };
              _broadcast(_currentState);
              break;

            case 'cast-pdf':
              _currentState = {
                'type': 'pdf',
                'content': data,
                'fontSize': _currentState['fontSize'] ?? 44,
                'background': _currentState['background'],
              };
              _broadcast(_currentState);
              break;

            case 'cast-pptx':
              _currentState = {
                'type': 'pptx',
                'content': data,
                'fontSize': _currentState['fontSize'] ?? 44,
                'background': _currentState['background'],
              };
              _broadcast(_currentState);
              break;

            case 'pdf-loaded':
              // TV reports back total pages after PDF loads
              if (_currentState['type'] == 'pdf' &&
                  _currentState['content'] != null) {
                (_currentState['content']
                        as Map<String, dynamic>)['totalPages'] =
                    data['totalPages'] ?? 0;
                (_currentState['content']
                        as Map<String, dynamic>)['currentPage'] =
                    data['currentPage'] ?? 1;
                _broadcast(_currentState);
              }
              break;

            case 'pdf-page':
              if (_currentState['type'] == 'pdf' ||
                  _currentState['type'] == 'pptx') {
                (_currentState['content']
                    as Map<String, dynamic>)['currentPage'] = data['page'] ?? 1;
                // Also update totalPages if TV sent it (keeps app in sync)
                if (data['totalPages'] != null) {
                  (_currentState['content']
                          as Map<String, dynamic>)['totalPages'] =
                      data['totalPages'];
                }
                _broadcast(_currentState);
              }
              break;

            case 'update-background':
              if (data.isEmpty || data['url'] == null) {
                _currentState['background'] = null;
              } else {
                _currentState['background'] = data;
              }
              _broadcast(_currentState);
              break;

            case 'clear-screen':
              _currentState = {
                'type': 'idle',
                'content': null,
                'fontSize': _currentState['fontSize'] ?? 44,
                'background': _currentState['background'],
              };
              _broadcast(_currentState);
              break;

            case 'cast-blackout':
              _currentState = {
                'type': 'blackout',
                'content': null,
                'fontSize': _currentState['fontSize'] ?? 44,
                'background': null,
              };
              _broadcast(_currentState);
              break;

            // ── Feature 2: local video (V1) ──
            // Phone commands are forwarded raw as {event, data} (the TV page
            // dispatches on `event`) while _currentState keeps a parallel
            // snapshot so late-joining TVs can restore playback.
            case 'cast-video':
              _currentState = {
                'type': 'video',
                'content': {
                  'url': data['url'] ?? '',
                  'title': data['title'] ?? '',
                  'playing': true,
                  'position': 0,
                },
                'fontSize': _currentState['fontSize'] ?? 44,
                'background': _currentState['background'],
              };
              _broadcast({'event': event, 'data': data});
              _broadcast(_currentState);
              break;

            case 'video-control':
              if (_currentState['type'] == 'video') {
                (_currentState['content'] as Map<String, dynamic>)['playing'] =
                    data['action'] == 'play';
              }
              _broadcast({'event': event, 'data': data});
              break;

            case 'video-seek':
              if (_currentState['type'] == 'video') {
                (_currentState['content'] as Map<String, dynamic>)['position'] =
                    data['seconds'] ?? 0;
              }
              _broadcast({'event': event, 'data': data});
              break;

            case 'video-stop':
              _currentState = {
                'type': 'idle',
                'content': null,
                'fontSize': _currentState['fontSize'] ?? 44,
                'background': _currentState['background'],
              };
              _broadcast({'event': event, 'data': data});
              _broadcast(_currentState);
              break;

            // TV → phone reports: forward to every client (the phone filters
            // by event name); video-progress keeps the state snapshot fresh.
            case 'video-progress':
              if (_currentState['type'] == 'video') {
                final c = _currentState['content'] as Map<String, dynamic>;
                c['position'] = data['position'] ?? c['position'];
                c['duration'] = data['duration'] ?? 0;
                c['playing'] = data['playing'] ?? c['playing'];
              }
              _broadcast({'event': event, 'data': data});
              break;

            case 'video-ended':
              if (_currentState['type'] == 'video') {
                (_currentState['content'] as Map<String, dynamic>)['playing'] =
                    false;
              }
              _broadcast({'event': event, 'data': data});
              break;

            case 'video-muted':
            case 'video-error':
              _broadcast({'event': event, 'data': data});
              break;

            // ── Feature 3: YouTube via IFrame API (Y1) ──
            case 'cast-youtube':
              _currentState = {
                'type': 'youtube',
                'content': {
                  'videoId': data['videoId'] ?? '',
                  'title': data['title'] ?? '',
                },
                'fontSize': _currentState['fontSize'] ?? 44,
                'background': _currentState['background'],
              };
              _broadcast({'event': event, 'data': data});
              _broadcast(_currentState);
              break;

            case 'yt-play':
            case 'yt-pause':
            case 'yt-seek':
            case 'yt-volume':
            case 'yt-unmute':
              _broadcast({'event': event, 'data': data});
              break;

            case 'yt-state':
              if (_currentState['type'] == 'youtube') {
                (_currentState['content'] as Map<String, dynamic>)['state'] =
                    data['state'];
              }
              _broadcast({'event': event, 'data': data});
              break;

            case 'yt-error':
              _broadcast({'event': event, 'data': data});
              break;
          }
        } catch (e) {
          print('[Server] WS parse error: $e');
        }
      },
      onDone: () {
        _clients.remove(channel);
        print('[Server] Client disconnected. Total: ${_clients.length}');
      },
      onError: (error) {
        _clients.remove(channel);
        print('[Server] Client error: $error');
      },
    );
  });

  router.get('/ws', (Request req) => wsHandler(req));

  final handler =
      Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  try {
    final server = await shelf_io.serve(handler, '0.0.0.0', 3000);
    print('[BiblePresenter] Server running on http://0.0.0.0:${server.port}');
    print('[BiblePresenter] TV URL -> http://<DEVICE_IP>:3000/tv.html');
  } catch (e) {
    print('[BiblePresenter] Server failed: $e');
    try {
      final server = await shelf_io.serve(handler, '0.0.0.0', 3001);
      print('[BiblePresenter] Server on alternate port ${server.port}');
    } catch (e2) {
      print('[BiblePresenter] Server failed on alternate: $e2');
    }
  }
}
