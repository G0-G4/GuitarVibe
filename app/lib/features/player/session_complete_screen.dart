import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/score.dart';
import '../library/library_providers.dart';
import '../scoring/scoring_providers.dart';

class SessionCompleteScreen extends ConsumerWidget {
  const SessionCompleteScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songAsync = ref.watch(songByIdProvider(songId));
    final score = ref.watch(lastSessionScoreProvider);
    final theme = Theme.of(context);

    return songAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (song) {
        if (song == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not found')),
            body: const Center(child: Text('Song not found.')),
          );
        }

        final duration = song.estimatedDuration;
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        final durationLabel =
            '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Finished'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.go('/song/$songId'),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(
                    Icons.check_circle_outline,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    song.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Played · $durationLabel',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  _ScoreSection(score: score, theme: theme),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => context.go('/song/$songId/play'),
                    icon: const Icon(Icons.replay),
                    label: const Text('Play again'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.library_music_outlined),
                    label: const Text('Back to library'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreSection extends StatelessWidget {
  const _ScoreSection({required this.score, required this.theme});

  final SessionScore? score;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (score == null || !score!.scoringEnabled) {
      return Text(
        score == null
            ? 'No score for this session.'
            : 'Scoring was off for this session.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }

    if (!score!.hasResults) {
      return Text(
        'No hits recorded. Play near the mic, or check microphone permission.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }

    final accuracy = score!.accuracyPercent.round();

    return Column(
      children: [
        Text(
          '$accuracy%',
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Accuracy',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            _StatChip(label: 'Good', value: score!.good, color: Colors.green),
            _StatChip(label: 'Early', value: score!.early, color: Colors.blue),
            _StatChip(label: 'Late', value: score!.late, color: Colors.amber.shade800),
            _StatChip(label: 'Miss', value: score!.miss, color: Colors.red),
          ],
        ),
        if (score!.maxStreak > 0) ...[
          const SizedBox(height: 16),
          Text(
            'Max streak · ${score!.maxStreak}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
