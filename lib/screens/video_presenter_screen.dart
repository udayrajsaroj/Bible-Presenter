import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// Full-featured Video & YouTube Live Presenter Screen.
/// Plays and previews the video on the phone controller screen while
/// simultaneously providing full remote control over the TV (DLNA / TV Browser).
class VideoPresenterScreen extends StatefulWidget {
  final String title;
  final String? localPath;
  final String? streamUrl;
  final String? youTubeId;
  final bool isYouTube;
  final ValueNotifier<Map<String, dynamic>> tvState;
  final double initialPosition;
  final double initialDuration;
  final bool initialPlaying;
  final double initialVolume;
  final String? activeTargetName;

  final void Function(bool play) onPlayPause;
  final void Function(double seconds) onSeek;
  final void Function(double volume)? onVolume;
  final VoidCallback onStop;
  final VoidCallback onLogo;
  final VoidCallback onBlackout;

  const VideoPresenterScreen({
    super.key,
    required this.title,
    this.localPath,
    this.streamUrl,
    this.youTubeId,
    this.isYouTube = false,
    required this.tvState,
    this.initialPosition = 0,
    this.initialDuration = 0,
    this.initialPlaying = true,
    this.initialVolume = 100,
    this.activeTargetName,
    required this.onPlayPause,
    required this.onSeek,
    this.onVolume,
    required this.onStop,
    required this.onLogo,
    required this.onBlackout,
  });

  @override
  State<VideoPresenterScreen> createState() => _VideoPresenterScreenState();
}

class _VideoPresenterScreenState extends State<VideoPresenterScreen> {
  VideoPlayerController? _videoCtrl;
  bool _isInit = false;
  bool _isPlaying = true;
  double _position = 0;
  double _duration = 0;
  double _volume = 100;
  bool _phoneMuted = true;
  bool _userSeeking = false;
  double _seekPosition = 0;
  Timer? _ytTicker;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.initialPlaying;
    _position = widget.initialPosition;
    _duration = widget.initialDuration;
    _volume = widget.initialVolume;

    widget.tvState.addListener(_onTvStateChanged);

    if (!widget.isYouTube) {
      _initPhoneVideo();
    } else {
      _startYouTubeTicker();
    }
  }

  void _onTvStateChanged() {
    if (!mounted) return;
    final state = widget.tvState.value;
    final type = state['type'] as String?;
    final content = state['content'] as Map<String, dynamic>?;

    if (type == 'video' || type == 'youtube') {
      final pos = (content?['position'] as num?)?.toDouble();
      final dur = (content?['duration'] as num?)?.toDouble();
      final playing = content?['playing'] as bool?;

      if (!_userSeeking && pos != null && pos > 0) {
        setState(() => _position = pos);
      }
      if (dur != null && dur > 0 && dur != _duration) {
        setState(() => _duration = dur);
      }
      if (playing != null && playing != _isPlaying) {
        setState(() => _isPlaying = playing);
      }
    }
  }

  Future<void> _initPhoneVideo() async {
    try {
      VideoPlayerController? ctrl;
      final localP = widget.localPath;
      if (localP != null && localP.isNotEmpty && File(localP).existsSync()) {
        ctrl = VideoPlayerController.file(File(localP));
      } else if (widget.streamUrl != null && widget.streamUrl!.isNotEmpty) {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl!));
      }

      if (ctrl != null) {
        _videoCtrl = ctrl;
        await ctrl.initialize();
        // Mute phone audio initially so it does not clash with TV speakers
        await ctrl.setVolume(_phoneMuted ? 0.0 : 1.0);
        if (_isPlaying) {
          await ctrl.play();
        }
        if (mounted) {
          setState(() {
            _isInit = true;
            if (ctrl!.value.duration.inSeconds > 0) {
              _duration = ctrl.value.duration.inSeconds.toDouble();
            }
          });
        }

        ctrl.addListener(() {
          if (!mounted || _userSeeking) return;
          final pos = ctrl!.value.position.inSeconds.toDouble();
          final dur = ctrl.value.duration.inSeconds.toDouble();
          final isP = ctrl.value.isPlaying;
          if (pos != _position || isP != _isPlaying) {
            setState(() {
              _position = pos;
              _isPlaying = isP;
              if (dur > 0) _duration = dur;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('[VideoPresenter] Phone video player init error: $e');
    }
  }

  void _startYouTubeTicker() {
    _ytTicker?.cancel();
    _ytTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_isPlaying && !_userSeeking) {
        setState(() {
          if (_duration > 0 && _position < _duration) {
            _position += 1;
          } else if (_duration == 0) {
            _position += 1;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    widget.tvState.removeListener(_onTvStateChanged);
    _ytTicker?.cancel();
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final next = !_isPlaying;
    setState(() => _isPlaying = next);
    widget.onPlayPause(next);
    if (_videoCtrl != null && _isInit) {
      if (next) {
        _videoCtrl!.play();
      } else {
        _videoCtrl!.pause();
      }
    }
  }

  void _seekTo(double seconds) {
    final target = seconds.clamp(0.0, _duration > 0 ? _duration : 36000.0);
    setState(() {
      _position = target;
      _userSeeking = false;
    });
    widget.onSeek(target);
    if (_videoCtrl != null && _isInit) {
      _videoCtrl!.seekTo(Duration(milliseconds: (target * 1000).round()));
    }
  }

  void _stepTime(double deltaSeconds) {
    final newPos = (_position + deltaSeconds).clamp(0.0, _duration > 0 ? _duration : 36000.0);
    _seekTo(newPos);
  }

  void _togglePhoneMute() {
    setState(() => _phoneMuted = !_phoneMuted);
    _videoCtrl?.setVolume(_phoneMuted ? 0.0 : 1.0);
  }

  void _changeVolume(double val) {
    setState(() => _volume = val);
    widget.onVolume?.call(val);
  }

  String _formatTime(double sec) {
    final s = sec.floor();
    final m = s ~/ 60;
    final r = s % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final mRem = m % 60;
      return '$h:${mRem.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
    }
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.activeTargetName ??
        (widget.isYouTube ? 'TV Browser' : 'TV Direct / DLNA');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(target),

            // ── Scrollable Center Stage ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Video Preview Stage
                    _buildVideoStage(),
                    const SizedBox(height: 16),

                    // Media Info Card
                    _buildMediaInfoCard(target),
                    const SizedBox(height: 16),

                    // Full Controls Deck
                    _buildControlsDeck(),
                    const SizedBox(height: 16),

                    // Quick Action Row (Blackout / Logo / Stop)
                    _buildQuickActionsRow(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String target) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: AppColors.borderWhite)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textHigh),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Live · $target',
                      style: const TextStyle(
                        color: AppColors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Logo quick cast
          IconButton(
            tooltip: 'Cast Church Logo',
            icon: const Icon(Icons.church_rounded, color: AppColors.goldSoft, size: 20),
            onPressed: widget.onLogo,
          ),
          // Blackout quick toggle
          IconButton(
            tooltip: 'Blackout Screen',
            icon: const Icon(Icons.visibility_off_rounded, color: AppColors.textMuted, size: 20),
            onPressed: widget.onBlackout,
          ),
          // Stop Cast
          IconButton(
            tooltip: 'Stop Video',
            icon: const Icon(Icons.stop_circle_rounded, color: AppColors.red, size: 22),
            onPressed: () {
              widget.onStop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoStage() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppRadii.cardLg),
        border: Border.all(color: AppColors.cyan.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!widget.isYouTube && _videoCtrl != null && _isInit)
              VideoPlayer(_videoCtrl!)
            else if (widget.isYouTube && widget.youTubeId != null)
              Image.network(
                'https://img.youtube.com/vi/${widget.youTubeId}/hqdefault.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),

            // Top Status Overlay (Phone Mute status & Fullscreen)
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!widget.isYouTube)
                    GestureDetector(
                      onTap: _togglePhoneMute,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderWhite),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _phoneMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              size: 14,
                              color: _phoneMuted ? AppColors.textMuted : AppColors.cyan,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _phoneMuted ? 'Phone Audio Muted' : 'Phone Audio ON',
                              style: TextStyle(
                                color: _phoneMuted ? AppColors.textMuted : AppColors.cyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 3),
                          Text('YouTube',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.green.withOpacity(0.4)),
                    ),
                    child: const Text('CASTING TO TV',
                        style: TextStyle(
                            color: AppColors.green,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),

            // Center Play/Pause tap target
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cyan.withOpacity(0.6), width: 1.5),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.cyan,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF0C1024),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isYouTube ? Icons.video_library_rounded : Icons.movie_rounded,
            size: 48,
            color: AppColors.cyan.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          const Text('Live TV Video Stream',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMediaInfoCard(String target) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppRadii.cardMd),
        border: Border.all(color: AppColors.borderWhite),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (widget.isYouTube ? Colors.red : AppColors.purple)
                  .withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.isYouTube
                  ? Icons.play_circle_filled_rounded
                  : Icons.video_file_rounded,
              color: widget.isYouTube ? Colors.red : AppColors.purpleSoft,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  widget.isYouTube
                      ? 'YouTube Video • Playing on $target'
                      : 'Local Video File • Casting to $target',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsDeck() {
    final currentPos = _userSeeking ? _seekPosition : _position;
    final maxDur = _duration > 0 ? _duration : 1.0;
    final sliderVal = currentPos.clamp(0.0, maxDur);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppRadii.cardLg),
        border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Timeline Slider ──
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.cyan,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
              thumbColor: AppColors.cyan,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayColor: AppColors.cyan.withOpacity(0.2),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: sliderVal,
              min: 0.0,
              max: maxDur,
              onChangeStart: (val) {
                setState(() {
                  _userSeeking = true;
                  _seekPosition = val;
                });
              },
              onChanged: (val) {
                setState(() => _seekPosition = val);
              },
              onChangeEnd: (val) {
                _seekTo(val);
              },
            ),
          ),

          // ── Timestamp Labels ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(currentPos),
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _duration > 0 ? _formatTime(_duration) : '--:--',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Transport Control Buttons ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rewind 10 seconds
              IconButton(
                tooltip: 'Rewind 10s',
                iconSize: 32,
                icon: const Icon(Icons.replay_10_rounded, color: AppColors.textHigh),
                onPressed: () => _stepTime(-10),
              ),

              // Restart / 0s
              IconButton(
                tooltip: 'Restart',
                iconSize: 26,
                icon: const Icon(Icons.skip_previous_rounded, color: AppColors.textHigh),
                onPressed: () => _seekTo(0),
              ),

              // Big Center Play / Pause Button
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.cyan, Color(0xFF0099FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: IconButton(
                  iconSize: 36,
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),

              // Forward 10 seconds
              IconButton(
                tooltip: 'Forward 10s',
                iconSize: 32,
                icon: const Icon(Icons.forward_10_rounded, color: AppColors.textHigh),
                onPressed: () => _stepTime(10),
              ),

              // Stop
              IconButton(
                tooltip: 'Stop Playback',
                iconSize: 26,
                icon: const Icon(Icons.stop_rounded, color: AppColors.red),
                onPressed: () {
                  widget.onStop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),

          if (widget.onVolume != null) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderWhite, height: 1),
            const SizedBox(height: 12),

            // ── Volume Slider ──
            Row(
              children: [
                const Icon(Icons.volume_down_rounded,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: AppColors.textHigh,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                      thumbColor: AppColors.textHigh,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: _volume,
                      min: 0,
                      max: 100,
                      onChanged: _changeVolume,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.volume_up_rounded,
                    color: AppColors.textHigh, size: 20),
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${_volume.round()}%',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        // Church Logo
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: AppColors.goldSoft,
              side: BorderSide(color: AppColors.goldSoft.withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.church_rounded, size: 18),
            label: const Text('Show Logo', style: TextStyle(fontSize: 12)),
            onPressed: widget.onLogo,
          ),
        ),
        const SizedBox(width: 10),

        // Blackout
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: AppColors.textMuted,
              side: const BorderSide(color: AppColors.borderWhite),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.visibility_off_rounded, size: 18),
            label: const Text('Blackout', style: TextStyle(fontSize: 12)),
            onPressed: widget.onBlackout,
          ),
        ),
        const SizedBox(width: 10),

        // Stop & Exit
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: AppColors.red.withOpacity(0.2),
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Stop Cast', style: TextStyle(fontSize: 12)),
            onPressed: () {
              widget.onStop();
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}
