/// Robust YouTube URL and ID parser supporting watch, youtu.be, shorts,
/// live, embed and bare IDs.
class YouTubeParser {
  YouTubeParser._();

  /// Extracts the eleven-character video ID from common YouTube link formats.
  static String? extractId(String url) {
    final trimmed = url.trim();
    if (RegExp(r'^[\w-]{11}$').hasMatch(trimmed)) return trimmed;
    final patterns = [
      RegExp(r'v=([\w-]{11})'), // youtube.com/watch?v=ID
      RegExp(r'youtu\.be/([\w-]{11})'), // https://youtu.be/ID
      RegExp(r'shorts/([\w-]{11})'), // youtube.com/shorts/ID
      RegExp(r'live/([\w-]{11})'), // youtube.com/live/ID
      RegExp(r'embed/([\w-]{11})'), // youtube.com/embed/ID
    ];
    for (final re in patterns) {
      final m = re.firstMatch(trimmed);
      if (m != null) return m.group(1);
    }
    return null;
  }
}
