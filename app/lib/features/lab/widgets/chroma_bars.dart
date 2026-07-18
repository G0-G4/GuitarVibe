import 'package:flutter/material.dart';

import '../../../domain/chord_tones.dart';

class ChromaBars extends StatelessWidget {
  const ChromaBars({
    super.key,
    required this.chroma,
    this.highlightTones = const {},
  });

  final List<double> chroma;
  final Set<int> highlightTones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final values = chroma.length == 12 ? chroma : List<double>.filled(12, 0);
    final maxV = values.fold<double>(0, (a, b) => a > b ? a : b);
    final norm = maxV > 1e-9 ? maxV : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Chroma', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 12; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: (values[i] / norm).clamp(0.02, 1.0),
                              widthFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: highlightTones.contains(i)
                                      ? scheme.primary
                                      : scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pitchClassNames[i],
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: highlightTones.contains(i)
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: highlightTones.contains(i)
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
