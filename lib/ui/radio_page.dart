import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class _Station {
  _Station(this.name, this.url, this.country, this.tags, this.bitrate, this.homepage);
  final String name;
  final String url;
  final String country;
  final String tags;
  final int bitrate;
  final String homepage;
}

/// Live radio from around the world, found through the open Radio Browser
/// directory. Stations play from their own streams; a few well-known stations
/// that only stream from their own sites open there instead.
class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  static const _genres = [
    'house', 'techno', 'electronic', 'drum and bass', 'dub', 'dance', 'hip hop', 'disco', 'ambient', 'indie',
  ];
  static const _countries = <String, String>{
    'Worldwide': '', 'UK': 'GB', 'USA': 'US', 'Germany': 'DE', 'France': 'FR', 'Netherlands': 'NL',
    'Brazil': 'BR', 'Japan': 'JP', 'Australia': 'AU', 'Canada': 'CA', 'Spain': 'ES', 'Italy': 'IT',
  };
  static const _featured = <(String, String)>[
    ('BBC Radio 6 Music', 'https://www.bbc.co.uk/sounds/play/live:bbc_6music'),
    ('BBC Radio 1', 'https://www.bbc.co.uk/sounds/play/live:bbc_radio_one'),
    ('BBC Radio 1Xtra', 'https://www.bbc.co.uk/sounds/play/live:bbc_1xtra'),
    ('NTS Radio', 'https://www.nts.live'),
    ('Rinse FM', 'https://www.rinse.fm'),
    ('Worldwide FM', 'https://worldwidefm.net'),
    ('KEXP', 'https://www.kexp.org/listen/'),
  ];

  String _genre = 'house';
  String _country = 'Worldwide';
  List<_Station> _stations = [];
  bool _loading = false;
  String _error = '';
  _Station? _now;
  WebViewController? _web;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _web?.loadHtmlString('<html></html>');
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final cc = _countries[_country] ?? '';
      final uri = Uri.https('de1.api.radio-browser.info', '/json/stations/search', {
        'tag': _genre,
        'tagExact': 'false',
        if (cc.isNotEmpty) 'countrycode': cc,
        'order': 'clickcount',
        'reverse': 'true',
        'hidebroken': 'true',
        'limit': '40',
      });
      final r = await http.get(uri, headers: {'User-Agent': 'Setflow/1.0'}).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception('status ${r.statusCode}');
      final out = <_Station>[];
      final seen = <String>{};
      for (final e in (jsonDecode(r.body) as List)) {
        final m = e as Map<String, dynamic>;
        final url = (m['url_resolved'] as String?) ?? '';
        final name = ((m['name'] as String?) ?? '').trim();
        if (url.isEmpty || name.isEmpty || !seen.add(name.toLowerCase())) continue;
        out.add(_Station(name, url, (m['country'] as String?) ?? '', (m['tags'] as String?) ?? '',
            (m['bitrate'] as num?)?.toInt() ?? 0, (m['homepage'] as String?) ?? ''));
      }
      if (!mounted) return;
      setState(() {
        _stations = out;
        _loading = false;
        if (out.isEmpty) _error = 'No stations found. Try another genre or country.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the radio directory. Check your connection and try again.';
      });
    }
  }

  void _play(_Station s) {
    final safe = const HtmlEscape(HtmlEscapeMode.attribute).convert(s.url);
    final c = _web ??= WebViewController()..setBackgroundColor(Colors.black);
    c.loadHtmlString(
        '<html><body style="margin:0;background:#000"><audio controls autoplay style="width:100%" src="$safe"></audio></body></html>');
    setState(() => _now = s);
  }

  Future<void> _open(String url) async {
    var ok = false;
    try {
      ok = (await const MethodChannel('sidedeck/audio').invokeMethod<bool>('openUrl', {'url': url})) ?? false;
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that station.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radio'), toolbarHeight: 48),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final g in _genres)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: ChoiceChip(
                  label: Text(g),
                  selected: _genre == g,
                  onSelected: (_) {
                    _genre = g;
                    _search();
                  },
                ),
              ),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final c in _countries.keys)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: ChoiceChip(
                  label: Text(c),
                  selected: _country == c,
                  onSelected: (_) {
                    _country = c;
                    _search();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 16), children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Famous stations (open on their own site)', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Wrap(spacing: 8, runSpacing: 0, children: [
              const SizedBox(width: 12),
              for (final f in _featured)
                ActionChip(avatar: const Icon(Icons.open_in_new, size: 16), label: Text(f.$1), onPressed: () => _open(f.$2)),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                  _loading ? 'Searching…' : (_error.isNotEmpty ? _error : '${_stations.length} $_genre stations, most listened first'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (_error.isNotEmpty) TextButton(onPressed: _search, child: const Text('Try again')),
            if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            for (final s in _stations)
              ListTile(
                dense: true,
                leading: Icon(_now == s ? Icons.graphic_eq : Icons.radio),
                title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    [s.country, if (s.bitrate > 0) '${s.bitrate} kbps', s.tags.split(',').take(3).join(', ')]
                        .where((x) => x.isNotEmpty)
                        .join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                onTap: () => _play(s),
              ),
          ]),
        ),
        if (_now != null && _web != null)
          SafeArea(
            top: false,
            child: Container(
              color: const Color(0xFF111111),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Now: ${_now!.name}', style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 54, child: WebViewWidget(controller: _web!)),
                const Text('Tap play on the bar if it does not start. Stations: Radio Browser (radio-browser.info).',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8A857C))),
              ]),
            ),
          ),
      ]),
    );
  }
}
