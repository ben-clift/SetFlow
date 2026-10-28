import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidedeck/debug/debug_log.dart';
import 'package:sidedeck/fetch/ingest.dart';
import 'package:sidedeck/fetch/partner_source.dart';

/// Free, legal music for Setflow. Every track here comes from a catalogue
/// whose artists have published it under an open licence (Jamendo, Internet
/// Archive). The licence and a link back are kept with each track so they can
/// be shown to the listener.
class CatalogTrack {
  CatalogTrack({
    required this.source,
    required this.id,
    required this.artist,
    required this.title,
    required this.audioUrl,
    this.ext = 'mp3',
    this.durationSec = 0,
    this.bpm = 0,
    this.genre = '',
    this.license = '',
    this.licenseUrl = '',
    this.pageUrl = '',
    this.canKeep = true,
  });

  final String source; // 'Jamendo' or 'Internet Archive'
  final String id;
  final String artist;
  final String title;
  final String audioUrl;
  final String ext;
  final int durationSec;
  final double bpm;
  final String genre;
  final String license;
  final String licenseUrl;
  final String pageUrl;

  /// False when the licence only allows listening, so the file is a temporary
  /// buffer that is removed once it has been played.
  final bool canKeep;

  String get name => artist.isEmpty ? title : '$artist - $title';
}

enum DlState { connecting, queued, waiting, downloading, done, failed }

class Download {
  Download(this.track);
  final CatalogTrack track;
  DlState state = DlState.connecting;
  String message = '';
  int size = 0;
  int received = 0;
  String? savedPath;
  double get progress => size > 0 ? received / size : 0;
}

/// Credit and licence for every file Setflow fetched, keyed by saved path.
class Credits {
  static final Map<String, CatalogTrack> _byPath = {};
  static CatalogTrack? of(String path) => _byPath[path];
}

class Catalog extends ChangeNotifier {
  /// Free Jamendo client id, built in with --dart-define=JAMENDO_ID=...
  static const _builtInJamendo = String.fromEnvironment('JAMENDO_ID');

  /// Folder fetched files go to, and the storage check, set by FetchSetup.
  String Function()? downloadDir;
  Future<String?> Function(int size)? storageCheck;
  Future<void> Function(String path)? onFileSaved;

  final List<Download> downloads = [];
  List<CatalogTrack> results = [];
  bool searching = false;

  static const _jamendoFlag = 'jamendo_id';

  Future<String> _jamendoId() async {
    if (_builtInJamendo.isNotEmpty) return _builtInJamendo;
    try {
      return (await SharedPreferences.getInstance()).getString(_jamendoFlag) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Name or title search across the catalogues.
  Future<List<CatalogTrack>> find(String artist, String title) async {
    final q = '$artist $title'.trim();
    return _all(q, jamendo: {'search': q}, archive: q);
  }

  /// Tracks for a genre inside a tempo window. Jamendo has no tempo field,
  /// only a speed band, so the window is turned into the nearest bands.
  Future<List<CatalogTrack>> byGenre(String genre, double? lo, double? hi,
      {int vocal = 0}) async {
    final tags = genre.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim().split(RegExp(r'\s+'));
    final speeds = <String>{};
    if (lo != null && hi != null) {
      String band(double b) => b < 80 ? 'verylow' : b < 100 ? 'low' : b < 125 ? 'medium' : b < 145 ? 'high' : 'veryhigh';
      speeds.add(band(lo));
      speeds.add(band((lo + hi) / 2));
      speeds.add(band(hi));
    }
    final out = <CatalogTrack>[];
    final seen = <String>{};
    final params = <String, String>{
      'fuzzytags': tags.join('+'),
      'order': 'popularity_month',
      if (speeds.isNotEmpty) 'speed': speeds.join('+'),
      if (vocal == 0) 'vocalinstrumental': 'instrumental',
    };
    for (final t in await _all(tags.join(' '), jamendo: params, archive: '${tags.join(' ')} AND (subject:electronic OR subject:dance OR subject:house OR subject:techno OR subject:music)')) {
      if (seen.add(t.id)) out.add(t);
    }
    out.shuffle();
    return out;
  }

  Future<List<CatalogTrack>> _all(String q,
      {required Map<String, String> jamendo, required String? archive}) async {
    searching = true;
    notifyListeners();
    final out = <CatalogTrack>[];
    try {
      for (final ps in partnerSources) {
        if (ps.available) out.addAll(await ps.search(query: q));
      }
      out.addAll(await _jamendo(jamendo));
      if (archive != null && out.length < 5) out.addAll(await _archive(archive));
    } finally {
      searching = false;
      results = out;
      notifyListeners();
    }
    return out;
  }

  Future<List<CatalogTrack>> _jamendo(Map<String, String> extra) async {
    final id = await _jamendoId();
    if (id.isEmpty) return const [];
    try {
      final uri = Uri.https('api.jamendo.com', '/v3.0/tracks/', {
        'client_id': id,
        'format': 'json',
        'limit': '40',
        'audioformat': 'mp32',
        'include': 'licenses+musicinfo',
        ...extra,
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return const [];
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final out = <CatalogTrack>[];
      for (final t in (data['results'] as List? ?? const [])) {
        final m = t as Map<String, dynamic>;
        final allowed = m['audiodownload_allowed'] == true;
        final url = (allowed ? m['audiodownload'] : m['audio']) as String? ?? '';
        if (url.isEmpty) continue;
        out.add(CatalogTrack(
          source: 'Jamendo',
          id: 'jamendo:${m['id']}',
          artist: m['artist_name'] as String? ?? '',
          title: m['name'] as String? ?? 'Track',
          audioUrl: url,
          durationSec: (m['duration'] as num?)?.toInt() ?? 0,
          license: 'Creative Commons',
          licenseUrl: m['license_ccurl'] as String? ?? '',
          pageUrl: m['shareurl'] as String? ?? '',
          // Without a download right the file is only a listening buffer.
          canKeep: allowed,
        ));
      }
      return out;
    } catch (e) {
      DebugLog.add('fetch', 'Jamendo search failed: $e');
      return const [];
    }
  }

  Future<List<CatalogTrack>> _archive(String q) async {
    try {
      final uri = Uri.https('archive.org', '/advancedsearch.php', {
        'q': '($q) AND mediatype:audio AND (licenseurl:*creativecommons* OR licenseurl:*publicdomain*)',
        'fl[]': ['identifier', 'title', 'creator', 'licenseurl'],
        'rows': '10',
        'output': 'json',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 20));
      final docs = ((jsonDecode(r.body) as Map)['response'] as Map?)?['docs'] as List? ?? const [];
      final out = <CatalogTrack>[];
      for (final d in docs.take(4)) {
        final m = d as Map<String, dynamic>;
        final id = '${m['identifier']}';
        final meta = await http.get(Uri.parse('https://archive.org/metadata/$id')).timeout(const Duration(seconds: 20));
        final files = ((jsonDecode(meta.body) as Map)['files'] as List? ?? const []);
        for (final f in files) {
          final fm = f as Map<String, dynamic>;
          final name = '${fm['name']}';
          final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
          if (ext != 'mp3' && ext != 'flac' && ext != 'ogg') continue;
          if (fm['source'] == 'derivative' && ext == 'ogg') continue;
          out.add(CatalogTrack(
            source: 'Internet Archive',
            id: 'ia:$id/$name',
            artist: m['creator'] is List ? (m['creator'] as List).join(', ') : '${m['creator'] ?? ''}',
            title: fm['title'] as String? ?? p.basenameWithoutExtension(name),
            audioUrl: 'https://archive.org/download/$id/${Uri.encodeComponent(name)}',
            ext: ext,
            durationSec: double.tryParse('${fm['length']}')?.round() ?? 0,
            license: 'Open licence',
            licenseUrl: m['licenseurl'] is String ? m['licenseurl'] as String : '',
            pageUrl: 'https://archive.org/details/$id',
          ));
          break;
        }
      }
      return out;
    } catch (e) {
      DebugLog.add('fetch', 'Internet Archive search failed: $e');
      return const [];
    }
  }

  /// Starts fetching [t] into the music folder. Progress is on the returned
  /// object.
  Download download(CatalogTrack t) {
    final d = Download(t);
    downloads.add(d);
    _run(d);
    return d;
  }

  void removeDownload(Download d) {
    downloads.remove(d);
    notifyListeners();
  }

  Future<void> _run(Download d) async {
    final dir = downloadDir?.call() ?? '';
    if (dir.isEmpty) {
      d.state = DlState.failed;
      d.message = 'No music folder';
      return;
    }
    final client = http.Client();
    File? file;
    try {
      await Directory(dir).create(recursive: true);
      final safe = d.track.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      file = File(p.join(dir, '$safe.${d.track.ext}'));
      d.state = DlState.downloading;
      notifyListeners();
      final resp = await client.send(http.Request('GET', Uri.parse(d.track.audioUrl)))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) throw HttpException('${resp.statusCode}');
      d.size = resp.contentLength ?? 0;
      final reason = await storageCheck?.call(d.size > 0 ? d.size : 12 * 1024 * 1024);
      if (reason != null) throw Exception(reason);
      final sink = file.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        d.received += chunk.length;
      }
      await sink.close();
      final bad = await verifyDownload(file.path, d.size);
      if (bad != null) throw Exception(bad);
      d.savedPath = file.path;
      Credits._byPath[file.path] = d.track;
      d.state = DlState.done;
      await onFileSaved?.call(file.path);
    } catch (e) {
      d.state = DlState.failed;
      d.message = '$e';
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
    } finally {
      client.close();
      notifyListeners();
    }
  }
}

final Catalog catalog = Catalog();
