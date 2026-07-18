import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/song_repository.dart';
import '../../domain/song.dart';

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository();
});

final bundledSongsProvider = FutureProvider<List<Song>>((ref) {
  return ref.watch(songRepositoryProvider).loadBundledSongs();
});

final songByIdProvider = FutureProvider.family<Song?, String>((ref, id) {
  return ref.watch(songRepositoryProvider).findById(id);
});
