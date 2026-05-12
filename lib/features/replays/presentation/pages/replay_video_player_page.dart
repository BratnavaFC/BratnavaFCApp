import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/replay_clip.dart';
import '../providers/replays_provider.dart';

// ── URL resolver (shared) ─────────────────────────────────────────────────────

/// Returns the best playable URL for [clip]:
/// 1. Direct pre-signed `videoUrl` (Cloudflare R2 — no auth needed).
/// 2. Authenticated backend stream endpoint.
String? resolveClipUrl(ReplayClip clip, String groupId, String? accessToken) {
  if (clip.videoUrl != null && clip.videoUrl!.isNotEmpty) return clip.videoUrl;
  if (clip.clipId.isNotEmpty) {
    final path = ApiConstants.replayStream(groupId, clip.clipId);
    return '${AppConstants.apiUrl}$path?t=${accessToken ?? ''}';
  }
  return null;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ReplayVideoPlayerPage extends ConsumerStatefulWidget {
  final List<ReplayClip> clips;
  final int              initialIndex;
  final String           groupId;
  final String?          accessToken;

  const ReplayVideoPlayerPage({
    super.key,
    required this.clips,
    required this.initialIndex,
    required this.groupId,
    this.accessToken,
  });

  @override
  ConsumerState<ReplayVideoPlayerPage> createState() =>
      _ReplayVideoPlayerPageState();
}

class _ReplayVideoPlayerPageState
    extends ConsumerState<ReplayVideoPlayerPage> {
  late int              _index;
  late List<ReplayClip> _clips;
  late VideoPlayerController _ctrl;

  bool _initialised  = false;
  bool _hasError     = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _actionBusy   = false;

  // ── Helpers ───────────────────────────────────────────────────────────────

  ReplayClip get _clip  => _clips[_index];
  bool get _hasPrev     => _index > 0;
  bool get _hasNext     => _index < _clips.length - 1;
  String? get _currentUrl =>
      resolveClipUrl(_clip, widget.groupId, widget.accessToken);

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _clips = List<ReplayClip>.from(widget.clips);
    _initController();
  }

  void _initController() {
    final url = _currentUrl;
    if (url == null) {
      setState(() { _hasError = true; _initialised = false; });
      return;
    }
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _initialised = true);
          _ctrl.play();
          _ctrl.addListener(_onCtrlUpdate);
        }).catchError((_) {
          if (!mounted) return;
          setState(() => _hasError = true);
        });
  }

  void _onCtrlUpdate() {
    if (!mounted) return;
    setState(() {});
    final v = _ctrl.value;
    if (v.isInitialized &&
        !v.isPlaying &&
        !v.isBuffering &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 300) &&
        _hasNext) {
      _goTo(_index + 1);
    }
  }

  void _goTo(int index) {
    _ctrl
      ..removeListener(_onCtrlUpdate)
      ..pause()
      ..dispose();
    setState(() {
      _index       = index;
      _initialised = false;
      _hasError    = false;
    });
    _initController();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ctrl
      ..removeListener(_onCtrlUpdate)
      ..dispose();
    super.dispose();
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  void _toggleFullscreen() {
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  void _seek(Duration delta) {
    final pos  = _ctrl.value.position;
    final dur  = _ctrl.value.duration;
    final raw  = pos + delta;
    final next = raw < Duration.zero ? Duration.zero : (raw > dur ? dur : raw);
    _ctrl.seekTo(next);
  }

  // ── Social actions ────────────────────────────────────────────────────────

  Future<void> _toggleLike() async {
    if (_actionBusy || _clip.clipId.isEmpty) return;
    final ds   = ref.read(replaysDsProvider);
    final prev = _clip;
    setState(() {
      _actionBusy    = true;
      _clips[_index] = _clip.copyWith(
        isLiked:   !_clip.isLiked,
        likeCount: _clip.isLiked ? _clip.likeCount - 1 : _clip.likeCount + 1,
      );
    });
    try {
      final result = await ds.toggleLike(widget.groupId, _clip.clipId);
      if (mounted) {
        setState(() {
          _clips[_index] = _clips[_index].copyWith(
            isLiked:   result.isLiked,
            likeCount: result.likeCount,
          );
        });
      }
    } catch (_) {
      if (mounted) setState(() => _clips[_index] = prev);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_actionBusy || _clip.clipId.isEmpty) return;
    final ds   = ref.read(replaysDsProvider);
    final prev = _clip;
    setState(() {
      _actionBusy    = true;
      _clips[_index] = _clip.copyWith(isFavorited: !_clip.isFavorited);
    });
    try {
      final isFav = await ds.toggleFavorite(widget.groupId, _clip.clipId);
      if (mounted) {
        setState(() {
          _clips[_index] = _clips[_index].copyWith(isFavorited: isFav);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _clips[_index] = prev);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _currentUrl ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado!')),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        if (!_isFullscreen)
          SafeArea(
            bottom: false,
            child: _TopBar(
              clip:       _clip,
              index:      _index,
              total:      _clips.length,
              onBack:     () => Navigator.pop(context),
              onLike:     _clip.clipId.isNotEmpty ? _toggleLike     : null,
              onFavorite: _clip.clipId.isNotEmpty ? _toggleFavorite : null,
              onCopy:     _copyUrl,
              busy:       _actionBusy,
            ),
          ),

        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
            child: Stack(alignment: Alignment.center, children: [
              Container(color: Colors.black),

              if (_initialised)
                AspectRatio(
                  aspectRatio: _ctrl.value.aspectRatio,
                  child: VideoPlayer(_ctrl),
                ),

              if (!_initialised && !_hasError)
                const CircularProgressIndicator(color: Colors.white),

              if (_hasError)
                _ErrorOverlay(
                  onRetry: () {
                    setState(() { _hasError = false; _initialised = false; });
                    _initController();
                  },
                ),

              if (_initialised && _showControls)
                _ControlsOverlay(
                  isPlaying:    _ctrl.value.isPlaying,
                  isBuffering:  _ctrl.value.isBuffering,
                  isFullscreen: _isFullscreen,
                  hasPrev:      _hasPrev,
                  hasNext:      _hasNext,
                  onPlayPause:  () => _ctrl.value.isPlaying
                      ? _ctrl.pause() : _ctrl.play(),
                  onSeekBack:   () => _seek(const Duration(seconds: -10)),
                  onSeekForward:() => _seek(const Duration(seconds: 10)),
                  onPrev:       _hasPrev ? () => _goTo(_index - 1) : null,
                  onNext:       _hasNext ? () => _goTo(_index + 1) : null,
                  onFullscreen: _toggleFullscreen,
                ),
            ]),
          ),
        ),

        if (_initialised)
          _ProgressBar(ctrl: _ctrl, fmt: _fmt),

        if (!_isFullscreen)
          const SafeArea(top: false, child: SizedBox.shrink()),
      ]),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final ReplayClip    clip;
  final int           index;
  final int           total;
  final VoidCallback  onBack;
  final VoidCallback? onLike;
  final VoidCallback? onFavorite;
  final VoidCallback  onCopy;
  final bool          busy;

  const _TopBar({
    required this.clip,
    required this.index,
    required this.total,
    required this.onBack,
    this.onLike,
    this.onFavorite,
    required this.onCopy,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final label = clip.scorerName?.isNotEmpty == true
        ? clip.scorerName!
        : (clip.eventType ?? 'Replay');

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${index + 1}/$total',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: Colors.white70)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
              if (clip.minute != null)
                Text("${clip.minute}'  ·  ${clip.eventType ?? ''}",
                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ),
        if (onLike != null)
          _TopBtn(
            icon:    clip.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color:   clip.isLiked ? Colors.redAccent : Colors.white60,
            label:   clip.likeCount > 0 ? '${clip.likeCount}' : null,
            onTap:   busy ? null : onLike,
            tooltip: clip.isLiked ? 'Descurtir' : 'Curtir',
          ),
        if (onFavorite != null)
          _TopBtn(
            icon:    clip.isFavorited ? Icons.star_rounded : Icons.star_border_rounded,
            color:   clip.isFavorited ? Colors.amber : Colors.white60,
            onTap:   busy ? null : onFavorite,
            tooltip: clip.isFavorited ? 'Remover favorito' : 'Favoritar',
          ),
        _TopBtn(
          icon:    Icons.link_rounded,
          color:   Colors.white60,
          onTap:   onCopy,
          tooltip: 'Copiar link',
        ),
      ]),
    );
  }
}

class _TopBtn extends StatelessWidget {
  final IconData      icon;
  final Color         color;
  final String?       label;
  final VoidCallback? onTap;
  final String?       tooltip;

  const _TopBtn({
    required this.icon,
    required this.color,
    this.label,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: color),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(label!, style: TextStyle(fontSize: 12, color: color)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Controls overlay ──────────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  final bool         isPlaying;
  final bool         isBuffering;
  final bool         isFullscreen;
  final bool         hasPrev;
  final bool         hasNext;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onFullscreen;

  const _ControlsOverlay({
    required this.isPlaying,
    required this.isBuffering,
    required this.isFullscreen,
    required this.hasPrev,
    required this.hasNext,
    required this.onPlayPause,
    required this.onSeekBack,
    required this.onSeekForward,
    this.onPrev,
    this.onNext,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [
            Color(0xAA000000), Color(0x00000000),
            Color(0x00000000), Color(0xAA000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Stack(children: [
        Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _CtrlBtn(icon: Icons.skip_previous_rounded, size: 28,
                onTap: onPrev, disabled: !hasPrev),
            const SizedBox(width: 8),
            _CtrlBtn(icon: Icons.replay_10_rounded, size: 32, onTap: onSeekBack),
            const SizedBox(width: 16),
            isBuffering
                ? const SizedBox(width: 60, height: 60,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : _CtrlBtn(
                    icon:  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size:  52, onTap: onPlayPause),
            const SizedBox(width: 16),
            _CtrlBtn(icon: Icons.forward_10_rounded, size: 32, onTap: onSeekForward),
            const SizedBox(width: 8),
            _CtrlBtn(icon: Icons.skip_next_rounded, size: 28,
                onTap: onNext, disabled: !hasNext),
          ]),
        ),
        Positioned(
          bottom: 12, right: 12,
          child: _CtrlBtn(
            icon:  isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
            size:  24, onTap: onFullscreen,
          ),
        ),
        if (isFullscreen)
          Positioned(
            top: 16, left: 16,
            child: _CtrlBtn(
              icon: Icons.arrow_back_rounded, size: 22,
              onTap: () => Navigator.pop(context),
            ),
          ),
      ]),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData      icon;
  final double        size;
  final VoidCallback? onTap;
  final bool          disabled;

  const _CtrlBtn({
    required this.icon,
    this.size = 28,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.3 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: size + 18, height: size + 18,
          decoration: const BoxDecoration(
            color: Color(0x55000000), shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final VideoPlayerController      ctrl;
  final String Function(Duration)  fmt;
  const _ProgressBar({required this.ctrl, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(children: [
        Text(fmt(ctrl.value.position),
            style: const TextStyle(
                color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: VideoProgressIndicator(
              ctrl, allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor:     Color(0xFF34D399),
                bufferedColor:   Colors.white24,
                backgroundColor: Colors.white12,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        Text(fmt(ctrl.value.duration),
            style: const TextStyle(
                color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
      ]),
    );
  }
}

// ── Error overlay ─────────────────────────────────────────────────────────────

class _ErrorOverlay extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorOverlay({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Colors.white54, size: 48),
      const SizedBox(height: 12),
      const Text('Não foi possível carregar o vídeo.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: onRetry,
        icon:  const Icon(Icons.refresh, color: Colors.white70),
        label: const Text('Tentar novamente',
            style: TextStyle(color: Colors.white70)),
      ),
    ]);
  }
}
