import 'package:flutter/material.dart';

// ── Theme constants ──
const kBg     = Color(0xFF060c18);
const kBg2    = Color(0xFF0b1526);
const kBg3    = Color(0xFF0d1a2e);
const kBorder = Color(0xFF1a2d45);
const kAccent = Color(0xFF0EA5E9);
const kGold   = Color(0xFFc9a96e);
const kText   = Color(0xFFe2e8f0);
const kMuted  = Color(0xFF64748b);

// ── Preset backgrounds ──
final List<Map<String, String>> presetBackgrounds = [
  {'name': 'Glowing Cross', 'url': 'https://images.unsplash.com/photo-1515787366009-7cbdd2dc587b?auto=format&fit=crop&q=80&w=1200'},
  {'name': 'Sabbath Dawn',  'url': 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?auto=format&fit=crop&q=80&w=1200'},
  {'name': 'Night Sky',     'url': 'https://images.unsplash.com/photo-1506318137071-a8e063b4bec0?auto=format&fit=crop&q=80&w=1200'},
  {'name': 'Golden Hour',   'url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=1200'},
  {'name': 'Dark Abstract', 'url': 'https://images.unsplash.com/photo-1509023464722-18d996393ca8?auto=format&fit=crop&q=80&w=1200'},
];

// ── Animated backgrounds (Dark motion themes with rich ambient effects) ──
final List<Map<String, String>> animatedBackgrounds = [
  {'name': 'Celestial Nebula', 'id': 'animated:aurora'},
  {'name': 'Divine Glory', 'id': 'animated:divine'},
  {'name': 'Living Waters', 'id': 'animated:ocean'},
  {'name': 'Altar Flame', 'id': 'animated:fire'},
  {'name': 'Midnight Sanctuary', 'id': 'animated:sunset'},
];

// ── Default slides ──
final List<Map<String, String>> defaultSlides = [
  {'title': 'WELCOME', 'subtitle': 'Covenant Fellowship', 'text': 'Welcome to our Sunday worship service. May God bless you today.'},
  {'title': 'OPENING PRAYER', 'subtitle': '', 'text': 'Let us bow our heads and open our hearts in prayer to our Heavenly Father.'},
  {'title': 'ANNOUNCEMENTS', 'subtitle': 'This Week', 'text': 'Sunday school at 9:00 AM · Prayer meeting Wednesday 7 PM · Youth camp registration open.'},
  {'title': 'OFFERING', 'subtitle': '', 'text': '"Each of you should give what you have decided in your heart to give." — 2 Corinthians 9:7'},
];
