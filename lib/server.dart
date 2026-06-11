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
  };
  return types[ext] ?? 'application/octet-stream';
}

// ── File type helper ──
String _fileType(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  if (ext == 'pdf') return 'pdf';
  if (ext == 'ppt' || ext == 'pptx') return 'pptx';
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
    try {
      final filename = req.requestedUri.queryParameters['name'] ?? 'upload.pdf';
      final bytes = await req.read().expand((list) => list).toList();

      // Sanitize filename
      final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File('$_uploadDir/$safeName');
      await file.writeAsBytes(bytes);

      print('[Server] File uploaded: $safeName (${bytes.length} bytes)');

      return _cors(Response.ok(
        jsonEncode({
          'url': '/uploads/$safeName',
          'name': safeName,
          'type': _fileType(safeName),
          'size': bytes.length,
        }),
        headers: {'Content-Type': 'application/json'},
      ));
    } catch (e) {
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
      final bytes = await file.readAsBytes();
      return Response.ok(bytes, headers: {
        'Content-Type': _contentType(safeName),
        'Access-Control-Allow-Origin': '*',
        'Content-Disposition': 'inline; filename="$safeName"',
        'Cache-Control': 'no-cache',
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
