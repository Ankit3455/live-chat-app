// lib/screens/questionnaire/widgets/avatar_live_preview.dart
//
// Small avatar card at the top of the questionnaire that redraws after each
// answer, so users see their answers building the face.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/avatar_traits.dart';
import '../../../services/dicebear_avatar_service.dart';

class AvatarLivePreview extends StatefulWidget {
  /// Answers so far (plus dateOfBirth if known).
  final Map<String, dynamic> answers;

  /// Bumped by the parent on every answer change.
  final int revision;

  /// The answer that just changed, e.g. "Reading", for the hint line.
  final String answerLabel;

  final String uid;

  const AvatarLivePreview({
    super.key,
    required this.answers,
    required this.revision,
    required this.answerLabel,
    required this.uid,
  });

  @override
  State<AvatarLivePreview> createState() => _AvatarLivePreviewState();
}

class _AvatarLivePreviewState extends State<AvatarLivePreview> {
  static const _debounce = Duration(milliseconds: 500);

  Timer? _timer;
  String? _url;
  Map<String, String>? _params;
  final List<String> _history = [];
  String? _hint;

  @override
  void initState() {
    super.initState();
    _refresh(withHint: false);
  }

  @override
  void didUpdateWidget(covariant AvatarLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _timer?.cancel();
      _timer = Timer(_debounce, () => _refresh(withHint: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh({required bool withHint}) {
    if (!mounted) return;
    final next = DiceBearAvatarService.preview(
      widget.answers,
      uniqueKey: widget.uid,
    );
    if (next.url == _url) return;
    final hint = withHint
        ? AvatarTraits.changeHint(
            before: _params,
            after: next.params,
            answerLabel: widget.answerLabel,
          )
        : null;
    setState(() {
      if (_url != null) {
        _history.insert(0, _url!);
        if (_history.length > 2) _history.removeLast();
      }
      _url = next.url;
      _params = next.params;
      if (hint != null) _hint = hint;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: _hint == null
          ? 'Your avatar is taking shape'
          : 'Your avatar is taking shape. $_hint',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lavender.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Face(url: _url, size: 64, ring: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your avatar is taking shape',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Every answer adds something.',
                        style: TextStyle(color: AppColors.lavender, fontSize: 13),
                      ),
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              'Earlier: ',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            for (final h in _history)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Opacity(
                                  opacity: 0.55,
                                  child: _Face(url: h, size: 22),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _hint == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(_hint),
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.35),
                        ),
                      ),
                      child: Text(
                        _hint!,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  final String? url;
  final double size;
  final bool ring;

  const _Face({required this.url, required this.size, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final image = url == null
        ? Container(color: AppColors.surfaceCard)
        : CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 250),
            placeholder: (_, __) => Container(color: AppColors.surfaceCard),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceCard,
              child: Icon(
                Icons.person_outline,
                color: AppColors.lavender,
                size: size * 0.5,
              ),
            ),
          );
    return Container(
      width: size,
      height: size,
      padding: ring ? const EdgeInsets.all(2) : EdgeInsets.zero,
      decoration: ring
          ? const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.brandPurpleMid, AppColors.brandPink],
              ),
            )
          : null,
      child: ClipOval(child: image),
    );
  }
}
