// Domain models for playable songs (schema v1).
// See docs/SONG_FORMAT.md.

class SongAudio {
  const SongAudio({
    required this.file,
    this.offsetSec = 0,
    this.durationSec,
  });

  final String file;
  final double offsetSec;
  final double? durationSec;

  factory SongAudio.fromJson(Map<String, dynamic> json) {
    return SongAudio(
      file: json['file'] as String,
      offsetSec: (json['offsetSec'] as num?)?.toDouble() ?? 0,
      durationSec: (json['durationSec'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'file': file,
        'offsetSec': offsetSec,
        if (durationSec != null) 'durationSec': durationSec,
      };
}

class AccompanimentPrefs {
  const AccompanimentPrefs({
    this.style = 'metronome',
    this.volume = 0.7,
  });

  final String style;
  final double volume;

  factory AccompanimentPrefs.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AccompanimentPrefs();
    return AccompanimentPrefs(
      style: json['style'] as String? ?? 'metronome',
      volume: (json['volume'] as num?)?.toDouble() ?? 0.7,
    );
  }

  Map<String, dynamic> toJson() => {
        'style': style,
        'volume': volume,
      };
}

class ChordEvent {
  const ChordEvent({
    required this.beat,
    required this.durationBeats,
    required this.chord,
    this.lyrics = '',
  });

  /// Absolute beat from song start.
  final double beat;
  final double durationBeats;
  final String chord;
  final String lyrics;

  double get endBeat => beat + durationBeats;

  factory ChordEvent.fromJson(Map<String, dynamic> json) {
    return ChordEvent(
      beat: (json['beat'] as num).toDouble(),
      durationBeats: (json['durationBeats'] as num).toDouble(),
      chord: json['chord'] as String,
      lyrics: json['lyrics'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'beat': beat,
        'durationBeats': durationBeats,
        'chord': chord,
        'lyrics': lyrics,
      };
}

class SongSection {
  const SongSection({
    required this.id,
    required this.name,
    required this.events,
  });

  final String id;
  final String name;
  final List<ChordEvent> events;

  factory SongSection.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] as List<dynamic>? ?? const [];
    return SongSection(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      events: rawEvents
          .map((e) => ChordEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'events': events.map((e) => e.toJson()).toList(),
      };
}

class Song {
  const Song({
    required this.schemaVersion,
    required this.id,
    required this.title,
    required this.artist,
    required this.tempoBpm,
    required this.timeSignature,
    required this.sections,
    this.key,
    this.capo = 0,
    this.tags = const [],
    this.audio,
    this.accompaniment = const AccompanimentPrefs(),
  });

  final int schemaVersion;
  final String id;
  final String title;
  final String artist;
  final String? key;
  final int capo;
  final double tempoBpm;
  final List<int> timeSignature;
  final List<String> tags;
  final SongAudio? audio;
  final List<SongSection> sections;
  final AccompanimentPrefs accompaniment;

  bool get hasAudio => audio != null;

  /// All chord events in order (flattened).
  List<ChordEvent> get allEvents {
    final events = sections.expand((s) => s.events).toList()
      ..sort((a, b) => a.beat.compareTo(b.beat));
    return events;
  }

  double get totalBeats {
    if (sections.isEmpty) return 0;
    var maxEnd = 0.0;
    for (final section in sections) {
      for (final event in section.events) {
        if (event.endBeat > maxEnd) maxEnd = event.endBeat;
      }
    }
    return maxEnd;
  }

  Duration get estimatedDuration {
    if (tempoBpm <= 0) return Duration.zero;
    final seconds = totalBeats * 60.0 / tempoBpm;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    final ts = json['timeSignature'] as List<dynamic>? ?? [4, 4];
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    final audioJson = json['audio'];

    return Song(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String? ?? 'Unknown',
      key: json['key'] as String?,
      capo: json['capo'] as int? ?? 0,
      tempoBpm: (json['tempoBpm'] as num).toDouble(),
      timeSignature: ts.map((e) => (e as num).toInt()).toList(),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      audio: audioJson is Map<String, dynamic>
          ? SongAudio.fromJson(audioJson)
          : null,
      sections: rawSections
          .map((e) => SongSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      accompaniment: AccompanimentPrefs.fromJson(
        json['accompaniment'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'title': title,
        'artist': artist,
        if (key != null) 'key': key,
        'capo': capo,
        'tempoBpm': tempoBpm,
        'timeSignature': timeSignature,
        'tags': tags,
        'audio': audio?.toJson(),
        'sections': sections.map((s) => s.toJson()).toList(),
        'accompaniment': accompaniment.toJson(),
      };
}
