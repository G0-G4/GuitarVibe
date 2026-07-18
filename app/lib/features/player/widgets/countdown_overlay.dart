import 'package:flutter/material.dart';

import '../../../domain/play_session.dart';

/// Dim overlay with large count-in number (or "Go").
class CountdownOverlay extends StatelessWidget {
  const CountdownOverlay({
    super.key,
    required this.snapshot,
  });

  final PlaySessionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.status != PlayStatus.countdown) {
      return const SizedBox.shrink();
    }

    final left = snapshot.countdownBeatsLeft;
    final label = left <= 0 ? 'Go' : '$left';
    final theme = Theme.of(context);

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                label,
                key: ValueKey(label),
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 96,
                  shadows: const [
                    Shadow(blurRadius: 16, color: Colors.black54),
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
