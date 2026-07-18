import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/chord_tones.dart';
import '../../domain/recognition_mode.dart';
import 'mic_lab_controller.dart';
import 'widgets/chroma_bars.dart';
import 'widgets/guess_display.dart';
import 'widgets/level_meter.dart';

class MicLabScreen extends ConsumerWidget {
  const MicLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lab = ref.watch(micLabProvider);
    final theme = Theme.of(context);
    final highlight = lab.guess.symbol != null
        ? pitchClassesForChord(lab.guess.symbol!)
        : <int>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mic Lab'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Recognition mode',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in RecognitionMode.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: lab.mode == m,
                    onSelected: (_) =>
                        ref.read(micLabProvider.notifier).setMode(m),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              lab.mode.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (lab.error != null) ...[
              Material(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.mic_off, color: theme.colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lab.error!,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(micLabProvider.notifier).start(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            LevelMeter(rms: lab.guess.rms),
            const SizedBox(height: 28),
            GuessDisplay(guess: lab.guess),
            const SizedBox(height: 28),
            ChromaBars(
              chroma: lab.guess.chroma,
              highlightTones: highlight,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  lab.listening ? Icons.graphic_eq : Icons.mic_none,
                  size: 18,
                  color: lab.listening
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  lab.listening ? 'Listening…' : 'Mic stopped',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: play open chords (C, G, Am, F…) close to the mic. '
              'Chroma ignores soft noise until the signal is tonal and stable; '
              'Hybrid also needs a clear pitch. Single pitch is best for single notes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
