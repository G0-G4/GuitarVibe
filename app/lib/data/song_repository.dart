import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/song.dart';

/// Loads bundled songs from Flutter assets.
class SongRepository {
  SongRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const _indexAsset = 'assets/songs/index.json';

  Future<List<Song>> loadBundledSongs() async {
    final indexRaw = await _bundle.loadString(_indexAsset);
    final index = jsonDecode(indexRaw) as Map<String, dynamic>;
    final paths = (index['songs'] as List<dynamic>).cast<String>();

    final songs = <Song>[];
    for (final path in paths) {
      final song = await loadSongAsset('assets/songs/$path');
      songs.add(song);
    }
    return songs;
  }

  Future<Song> loadSongAsset(String assetPath) async {
    final raw = await _bundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return Song.fromJson(json);
  }

  Future<Song?> findById(String id) async {
    final songs = await loadBundledSongs();
    for (final song in songs) {
      if (song.id == id) return song;
    }
    return null;
  }
}
