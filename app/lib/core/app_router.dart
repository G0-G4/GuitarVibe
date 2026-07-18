import 'package:go_router/go_router.dart';

import '../features/library/library_screen.dart';
import '../features/library/song_detail_screen.dart';
import '../features/player/player_screen.dart';
import '../features/player/session_complete_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'library',
      builder: (context, state) => const LibraryScreen(),
      routes: [
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
