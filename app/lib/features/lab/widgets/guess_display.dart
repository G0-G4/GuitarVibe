import 'package:flutter/material.dart';

import '../../../domain/chord_guess.dart';
import '../../../domain/chord_tones.dart';

class GuessDisplay extends StatelessWidget {
  const GuessDisplay({super.key, required this.guess});

  final ChordGuess guess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (guess.isSilence) {
      return Column(
        children: [
          Text(
            '—',
            style: theme.textTheme.displayLarge?.copyWith(
              color: scheme.outline,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play a chord near the mic',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final symbol = guess.symbol;
    final pct = (guess.confidence * 100).round();

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: Text(
            symbol ?? '?',
            key: ValueKey(symbol ?? '?'),
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: symbol == null ? scheme.outline : scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          symbol == null ? 'Low confidence' : '$pct% match',
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (guess.top.length > 1) ...[
          const SizedBox(height: 12),
          Text(
            'Alternatives: ${guess.top.skip(1).take(3).map((r) => '${r.symbol} ${(r.score * 100).round()}%').join(' · ')}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.outline,
            ),
          ),
        ],
        if (guess.yinHz != null) ...[
          const SizedBox(height: 8),
          Text(
            'Pitch: ${_fmtHz(guess.yinHz!)}'
            '${guess.yinConfidence != null ? ' · conf ${(guess.yinConfidence! * 100).round()}%' : ''}'
            '${_pcLabel(guess.yinHz!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (guess.symbol == null && guess.blockReason != null) ...[
          const SizedBox(height: 10),
          Text(
            guess.blockReason!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.tertiary,
            ),
          ),
        ],
      ],
    );
  }

  static String _fmtHz(double hz) {
    if (hz >= 100) return '${hz.round()} Hz';
    return '${hz.toStringAsFixed(1)} Hz';
  }

  static String _pcLabel(double hz) {
    final pc = pitchClassFromHz(hz);
    if (pc == null) return '';
    return ' (${pitchClassNames[pc]})';
  }
}
