// lib/feature/games/game_list_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../screens/shell/main_shell.dart';
import 'carrom/carrom_lobby_screen.dart';
import 'carrom/common/game_leaderboard_screen.dart';
import 'carrom/services/carrom_stats_service.dart';
import 'chat_games/chat_game_registry.dart';
import 'chat_games/random_match_screen.dart';
import 'chat_games/ui/game_ui.dart';
import 'ludo/ludo_lobby_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptics.dart';

class GameListScreen extends StatefulWidget {
  const GameListScreen({super.key});

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  CarromStats? _myStats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _myStats = null;
          _loadingStats = false;
        });
      }
      return;
    }

    final stats = await CarromStatsService.getUserStats(uid);
    if (mounted) {
      setState(() {
        _myStats = stats;
        _loadingStats = false;
      });
    }
  }

  /// "Invite a match from chats" on the random-match screen.
  VoidCallback? get _openChats {
    final shell = MainShell.maybeOf(context);
    return shell == null ? null : () => shell.selectTab(MainShell.chatsTab);
  }

  // Stats can change while a game screen is open, so reload on return.
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _myStats;
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildStatsCard(stats),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Choose a game',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                'Play with someone new who is online right now. To play with '
                'a match, open your chat and tap + → Games.',
                style: TextStyle(color: AppColors.lavender, fontSize: 13.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _GameCard(
                    title: 'Ludo',
                    players: '2–4 players',
                    description: 'Race your tokens home first.',
                    icon: Icons.casino_outlined,
                    accent: AppColors.brandPurpleLight,
                    onTap: () => _open(const LudoLobbyScreen()),
                  ),
                  const SizedBox(height: 12),
                  _GameCard(
                    title: 'Carrom',
                    players: '2 players',
                    record: stats != null && stats.totalGames > 0
                        ? 'W–L ${stats.wins}–${stats.losses}'
                        : null,
                    description: 'Flick the striker, pocket your coins.',
                    icon: Icons.adjust,
                    accent: AppColors.pinkLight,
                    onTap: () => _open(const CarromLobbyScreen()),
                  ),
                  // The chat games: here with a random player; with a
                  // match they start from the chat's Games button.
                  for (final g in ChatGames.spaceGames) ...[
                    const SizedBox(height: 12),
                    _GameCard(
                      title: g.title,
                      players: '2 players',
                      description: g.tagline,
                      emoji: g.emoji,
                      icon: Icons.sports_esports_outlined,
                      accent: GameTheme.of(g.name).a,
                      onTap: () => _open(
                        RandomMatchScreen(
                          game: g.name,
                          onOpenChats: _openChats,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Back is hidden when shown as a tab of the main shell (nothing to pop).
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(canPop ? 4 : 20, 4, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Games',
                        style: GoogleFonts.montserrat(
                          color: AppColors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const Text(
                  'Play with a match or someone new',
                  style: TextStyle(color: AppColors.lavender, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.leaderboard_outlined,
              color: AppColors.brandPurpleLight,
            ),
            tooltip: 'Carrom leaderboard',
            onPressed: () => _open(const CarromLeaderboardScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(CarromStats? stats) {
    final Widget body;
    if (_loadingStats) {
      body = Row(
        children: List.generate(
          4,
          (_) => Expanded(
            child: Column(
              children: [
                _skeleton(width: 36, height: 24),
                const SizedBox(height: 6),
                _skeleton(width: 48, height: 12),
              ],
            ),
          ),
        ),
      );
    } else if (stats == null || stats.totalGames == 0) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'No games yet. Play a round of Carrom to see your stats here.',
          style: TextStyle(color: AppColors.lavender, fontSize: 14),
        ),
      );
    } else {
      body = IntrinsicHeight(
        child: Row(
          children: [
            _stat('Games', '${stats.totalGames}'),
            const VerticalDivider(width: 1, thickness: 1),
            _stat('Wins', '${stats.wins}'),
            const VerticalDivider(width: 1, thickness: 1),
            _stat('Win rate', '${stats.winRate.toStringAsFixed(0)}%'),
            const VerticalDivider(width: 1, thickness: 1),
            _stat('Streak', '${stats.winStreak}', highlight: true),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandPurple.withOpacity(0.22),
            AppColors.brandPink.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandPurpleMid.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your stats',
                  style: GoogleFonts.montserrat(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                stats != null && stats.totalGames > 0
                    ? 'Carrom · ${stats.rank}'
                    : 'Carrom',
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _skeleton({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _stat(String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.montserrat(
                color: highlight ? AppColors.pinkLight : AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.lavender, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== GAME CARD WIDGET =====
/// A null [onTap] renders the card disabled with a "Coming soon" badge.
class _GameCard extends StatefulWidget {
  final String title;
  final String players;
  final String? record;
  final String? description;
  final IconData icon;

  /// Drawn instead of [icon] when set.
  final String? emoji;
  final Color accent;
  final VoidCallback? onTap;

  const _GameCard({
    required this.title,
    required this.players,
    this.record,
    this.description,
    this.emoji,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    Haptics.selection();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final players = widget.players;
    final icon = widget.icon;
    final accent = widget.accent;
    final available = widget.onTap != null;
    final desc = widget.description;
    final rec = widget.record;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tileBg = available ? accent.withOpacity(0.14) : AppColors.surface2;
    final tileBorder = available ? accent.withOpacity(0.4) : AppColors.border;

    return Semantics(
      button: available,
      enabled: available,
      label: available ? 'Play $title' : '$title, coming soon',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed && available && !reduceMotion ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: available ? AppColors.surfaceCard : AppColors.surfaceRaised,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: available ? _handleTap : null,
            onHighlightChanged: _setPressed,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: accent),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: tileBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: tileBorder),
                        ),
                        alignment: Alignment.center,
                        child: widget.emoji != null
                            ? Text(
                                widget.emoji!,
                                style: const TextStyle(fontSize: 32),
                              )
                            : Icon(icon, color: accent, size: 34),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.montserrat(
                                    color: available
                                        ? AppColors.white
                                        : AppColors.textSubtle,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (!available) const _SoonBadge(),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                text: players,
                                children: [
                                  if (rec != null) ...[
                                    const TextSpan(text: '  ·  '),
                                    TextSpan(
                                      text: rec,
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              style: TextStyle(
                                color: available
                                    ? AppColors.lavender
                                    : AppColors.textSubtle,
                                fontSize: 13,
                              ),
                            ),
                            if (desc != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.lavender,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tileBg,
                          border: Border.all(color: tileBorder),
                        ),
                        child: Icon(
                          available
                              ? Icons.play_arrow_rounded
                              : Icons.lock_outline,
                          color: available
                              ? accent
                              : AppColors.textSubtle.withOpacity(0.6),
                          size: available ? 24 : 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: const Text(
        'Coming soon',
        style: TextStyle(
          color: AppColors.lavender,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
