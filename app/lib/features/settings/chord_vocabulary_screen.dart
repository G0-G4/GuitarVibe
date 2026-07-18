import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/chord_tones.dart';
import '../../domain/chord_vocabulary.dart';
import 'settings_providers.dart';

/// Pick which chords free recognition is allowed to guess.
class ChordVocabularyScreen extends ConsumerWidget {
  const ChordVocabularyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocab = ref.watch(chordVocabularyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My chords'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Limit recognition to my chords'),
            subtitle: Text(
              'Mic Lab only ranks chords you select. '
              'Play-along still scores each song’s expected chords.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: vocab.enabled,
            onChanged: (v) =>
                ref.read(chordVocabularyProvider.notifier).setEnabled(v),
          ),
          const SizedBox(height: 8),
          Text('Presets', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Beginner C–G–Am–F'),
                onPressed: () => ref
                    .read(chordVocabularyProvider.notifier)
                    .applyPreset(ChordVocabulary.beginner),
              ),
              ActionChip(
                label: const Text('Open chords'),
                onPressed: () => ref
                    .read(chordVocabularyProvider.notifier)
                    .applyPreset(ChordVocabulary.openChords),
              ),
              ActionChip(
                label: const Text('All maj/min'),
                onPressed: () => ref
                    .read(chordVocabularyProvider.notifier)
                    .applyPreset(ChordVocabulary.majorMinor),
              ),
              ActionChip(
                label: const Text('Reset (off)'),
                onPressed: () =>
                    ref.read(chordVocabularyProvider.notifier).reset(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            vocab.enabled
                ? 'Selected (${vocab.symbols.length})'
                : 'Selected (filter off — full vocabulary)',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final symbol in ChordVocabulary.selectable)
                FilterChip(
                  label: Text(symbol),
                  selected:
                      vocab.symbols.contains(normalizeChordSymbol(symbol)),
                  onSelected: (_) => ref
                      .read(chordVocabularyProvider.notifier)
                      .toggleSymbol(symbol),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (vocab.enabled && vocab.symbols.isNotEmpty)
            Text(
              'Active set: ${vocab.sorted.join(' · ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Tip: a small set (4–8 chords) makes chroma much less ambiguous '
            'when two templates look similar.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
