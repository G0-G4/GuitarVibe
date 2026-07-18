import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/recognition_mode.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoringEnabled = ref.watch(scoringEnabledProvider);
    final mode = ref.watch(recognitionModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Score with microphone'),
            subtitle: Text(
              'Listen to your guitar and show Good / Early / Late / Miss. '
              'Requires microphone permission.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: scoringEnabled,
            onChanged: (v) =>
                ref.read(scoringEnabledProvider.notifier).setEnabled(v),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Recognition mode',
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final m in RecognitionMode.values)
            ListTile(
              enabled: scoringEnabled,
              selected: mode == m,
              title: Text(m.label),
              subtitle: Text(
                m.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              leading: Icon(
                mode == m
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: mode == m
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              onTap: scoringEnabled
                  ? () =>
                      ref.read(recognitionModeProvider.notifier).setMode(m)
                  : null,
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Mic Lab'),
            subtitle: const Text('Test recognition — play a chord, see the guess'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/lab'),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Tips',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              'Play near the mic and keep speaker volume moderate so the '
              'metronome does not drown out your guitar. Use Mic Lab to '
              'compare modes before a scored play-along.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
