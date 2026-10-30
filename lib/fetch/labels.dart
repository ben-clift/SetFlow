/// A label whose music is featured in Setflow with their agreement.
class PartnerLabel {
  const PartnerLabel(this.name, this.blurb, this.bandcampUrl, {this.genres = const []});
  final String name;
  final String blurb;
  final String bandcampUrl;
  final List<String> genres;
}

/// Where labels get in touch. Set before the Play Store release.
const String labelContactEmail = '';

/// Labels that have agreed to be featured. Add an entry only once the label
/// has said yes in writing (an email is enough).
const List<PartnerLabel> partnerLabels = [];
