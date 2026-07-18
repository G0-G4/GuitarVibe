import 'package:go_router/go_router.dart';

import '../features/library/library_screen.dart';
import '../features/library/song_detail_screen.dart';

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
        ),
      ],
    ),
  ],
);
