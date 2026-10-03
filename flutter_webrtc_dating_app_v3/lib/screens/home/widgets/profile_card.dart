import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/user_model.dart';
import '../../astrology/widgets/compatibility_chip.dart';
import 'profile_quick_sheet.dart';

/// Tap opens the quick sheet; its Message button calls [onTap].
class ProfileCard extends StatefulWidget {
  const ProfileCard({
    Key? key,
    required this.user,
    required this.currentUser,
    required this.onTap,
  }) : super(key: key);

  final UserModel user;
  final UserModel? currentUser;
  final VoidCallback onTap;

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapCtrl;
  bool _floating = false;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: .94,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Float only while visible and when the user allows motion.
    final shouldFloat = TickerMode.of(context) &&
        !MediaQuery.of(context).disableAnimations;
    if (shouldFloat != _floating) {
      _floating = shouldFloat;
      shouldFloat ? _CardFloat.instance.acquire() : _CardFloat.instance.release();
    }
  }

  @override
  void dispose() {
    if (_floating) _CardFloat.instance.release();
    _tapCtrl.dispose();
    super.dispose();
  }

  void _openQuickSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProfileQuickSheet(
        currentUser: widget.currentUser,
        user: widget.user,
        onMessage: widget.onTap,
      ),
    );
  }

  String _initial() {
    final name = widget.user.username.trim();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String? _avatarUrl() {
    final url = widget.user.profileImage;
    if (url.isEmpty) return null;
    final v = widget.user.avatarVersion ?? 0;
    return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
  }

  Widget _avatarBox() {
    final url = _avatarUrl();

    final fallback = Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7B2CBF), Color(0xFF9C4DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        _initial(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 72,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (url == null) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: CachedNetworkImage(
        imageUrl: url,
        memCacheWidth: 600,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.user.online == true;

    final card = GestureDetector(
      onTapDown: (_) => _tapCtrl.reverse(),
      onTapCancel: () => _tapCtrl.forward(),
      onTapUp: (_) {
        _tapCtrl.forward();
        _openQuickSheet();
      },
      onLongPress: _openQuickSheet,
        child: ScaleTransition(
          scale: _tapCtrl,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF7B2CBF), Color(0xFF9C4DFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.25),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // glossy overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(.10),
                            Colors.white.withOpacity(.02),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // avatar area (image or initials)
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: _avatarBox()),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: CompatibilityChip(
                              currentUser: widget.currentUser,
                              user: widget.user,
                            ),
                          ),
                          if (online)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // dark label strip
                    Container(
                      padding:
                      const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF150B25).withOpacity(.70),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.work_outline,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.user.profession?.isNotEmpty == true
                                      ? widget.user.profession!
                                      : '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildInterestsRow(widget.user.interests),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ),
    );

    return RepaintBoundary(
      child: _floating
          ? ValueListenableBuilder<double>(
              valueListenable: _CardFloat.instance.phase,
              builder: (_, t, child) => Transform.translate(
                offset: Offset(-4 + 8 * t, -3 + 6 * t),
                child: child,
              ),
              child: card,
            )
          : card,
    );
  }

  Widget _buildInterestsRow(List<String> interests) {
    final chips = interests.take(2).toList();
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: chips
          .map(
            (e) => Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withOpacity(.15), width: 1),
          ),
          child: Text(
            e,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      )
          .toList(),
    );
  }
}

/// One ticker shared by every visible card instead of one controller per card
/// (DEST-096). Runs only while at least one card is floating.
class _CardFloat {
  _CardFloat._();
  static final _CardFloat instance = _CardFloat._();

  static const _halfPeriodMs = 5200;

  final ValueNotifier<double> phase = ValueNotifier<double>(0.5);
  Ticker? _ticker;
  int _users = 0;
  int _offsetMs = 0;
  int _lastMs = 0;

  void acquire() {
    if (_users++ > 0) return;
    _ticker ??= Ticker(_onTick, debugLabel: 'ProfileCardFloat');
    _ticker!.start();
  }

  void release() {
    if (_users == 0 || --_users > 0) return;
    _ticker?.stop();
    _offsetMs += _lastMs;
    _lastMs = 0;
  }

  void _onTick(Duration elapsed) {
    _lastMs = elapsed.inMilliseconds;
    final ms = (_offsetMs + _lastMs) % (2 * _halfPeriodMs);
    final linear =
        ms < _halfPeriodMs ? ms / _halfPeriodMs : 2 - ms / _halfPeriodMs;
    phase.value = Curves.easeInOut.transform(linear);
  }
}
