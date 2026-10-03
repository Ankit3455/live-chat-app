import 'package:flutter/material.dart';
import '../../widgets/voice/voice_record_sheet.dart';
import '../../core/constants/app_colors.dart';

/// A lightweight, focused screen that explains
/// why voice intros matter and lets the user record one.
/// Returns `true` to the caller if the user saves a voice intro,
/// `false` (or null) if they skip/back out.
class VoiceIntroScreen extends StatelessWidget {
  const VoiceIntroScreen({super.key});

  Future<void> _openRecorder(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const VoiceRecordSheet(),
    );

    if (saved == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Voice intro saved')));
        Navigator.of(
          context,
        ).pop(true); // notify caller (e.g., post-signup flow)
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solid fallback colors to avoid depending on external theme constants.
    const bg = AppColors.surfaceRaised;
    const headline = Colors.white;
    const sub = Colors.white70;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Your Voice Intro',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      // Scrolls on small screens / large text; Spacer still pins the buttons
      // to the bottom when there is room.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 20)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Why add a voice intro?",
                      style: TextStyle(
                        color: headline,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      // Keep the copy simple, human, and benefits-first.
                      "• Voice shows your vibe — tone, energy, warmth.\n"
                      "• Others get to know you faster than text alone.\n"
                      "• In a blind-dating experience, it builds trust.\n\n"
                      "Say 1–2 things you love or what you’re looking for.",
                      style: TextStyle(
                        color: sub,
                        fontSize: 14.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _LimitPill(),
                    const SizedBox(height: 24),

                    // Spacer pushes buttons to bottom bar if content is short
                    const Spacer(),

                    // Primary actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Skip for now',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openRecorder(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPurple,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(
                              Icons.mic_rounded,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Add voice intro',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LimitPill extends StatelessWidget {
  const _LimitPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.timer_rounded, color: Colors.white70, size: 18),
          SizedBox(width: 8),
          Text(
            'Limit: up to 20 seconds',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
