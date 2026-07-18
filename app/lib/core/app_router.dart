import 'package:go_router/go_router.dart';

import '../features/lab/mic_lab_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/song_detail_screen.dart';
import '../features/player/player_screen.dart';
import '../features/player/session_complete_screen.dart';
import '../features/settings/chord_vocabulary_screen.dart';
import '../features/settings/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'library',
      builder: (context, state) => const LibraryScreen(),
      routes: [
        GoRoute(
          path: 'settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'chords',
              name: 'chords',
              builder: (context, state) => const ChordVocabularyScreen(),
            ),
          ],
        ),
        GoRoute(
          path: 'lab',
          name: 'lab',
          builder: (context, state) => const MicLabScreen(),
        ),
        GoRoute(
          path: 'song/:id',
          name: 'song',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return SongDetailScreen(songId: id);
          },
          routes: [
            GoRoute(
              path: 'play',
              name: 'play',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return PlayerScreen(songId: id);
              },
            ),
            GoRoute(
              path: 'complete',
              name: 'complete',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return SessionCompleteScreen(songId: id);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);
