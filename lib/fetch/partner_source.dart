import 'package:sidedeck/fetch/catalog.dart';

/// A music service Setflow can connect to once its owner has agreed terms
/// with us (Beatport, Bandcamp and so on). Each one stays switched off until
/// its credentials are built into the app, so nothing here talks to a service
/// that has not signed off on it.
abstract class PartnerSource {
  String get id;
  String get name;

  /// True only when credentials for this service are present.
  bool get available;

  /// Tracks matching a genre and tempo window, or a name search.
  Future<List<CatalogTrack>> search({String query = '', String genre = '', double? bpmLo, double? bpmHi});

  /// Where to buy the track, shown on the track as a "Buy" button.
  Uri? buyLink(CatalogTrack t);
}

/// Slot for Beatport. Beatport streams to DJ apps through its partner
/// programme (Beatport LINK), which needs an agreement and a client id.
/// When that is signed, add `--dart-define=BEATPORT_CLIENT_ID=...` to the
/// build and fill in [search] against their API; the rest of the app already
/// asks every available partner source for tracks.
class BeatportSource implements PartnerSource {
  static const _clientId = String.fromEnvironment('BEATPORT_CLIENT_ID');

  @override
  String get id => 'beatport';

  @override
  String get name => 'Beatport';

  @override
  bool get available => _clientId.isNotEmpty;

  @override
  Future<List<CatalogTrack>> search({String query = '', String genre = '', double? bpmLo, double? bpmHi}) async {
    // TODO(partner): call the Beatport LINK API once the agreement is in place.
    return const [];
  }

  @override
  Uri? buyLink(CatalogTrack t) =>
      Uri.https('www.beatport.com', '/search', {'q': t.name});
}

/// Slot for Bandcamp, the first partner to approach. Bandcamp has no open
/// streaming API for apps, so this needs an agreement with them. Until then
/// it only gives a "Buy on Bandcamp" link. When agreed, add
/// `--dart-define=BANDCAMP_PARTNER_KEY=...` and fill in [search].
class BandcampSource implements PartnerSource {
  static const _key = String.fromEnvironment('BANDCAMP_PARTNER_KEY');

  @override
  String get id => 'bandcamp';

  @override
  String get name => 'Bandcamp';

  @override
  bool get available => _key.isNotEmpty;

  @override
  Future<List<CatalogTrack>> search({String query = '', String genre = '', double? bpmLo, double? bpmHi}) async {
    // TODO(partner): call Bandcamp once they have approved Setflow.
    return const [];
  }

  @override
  Uri? buyLink(CatalogTrack t) =>
      Uri.https('bandcamp.com', '/search', {'q': t.name});
}

/// Every partner connector. Add Juno and others here.
final List<PartnerSource> partnerSources = [BandcampSource(), BeatportSource()];
