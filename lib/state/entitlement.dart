import 'package:sidedeck/state/admin.dart';

/// Whether the paid features are open.
///
/// The plan is a one-off 99p unlock through Google Play Billing, with the
/// admin code opening everything for Ben. Payment is NOT switched on yet:
/// while [paywallLive] is false every feature is open to everyone. When the
/// app is on Google Play, wire the purchase into [paid] and set
/// [paywallLive] to true.
class Entitlement {
  static const bool paywallLive = false;

  /// Set by the Play Billing purchase once it exists.
  static bool paid = false;

  static bool get unlocked => !paywallLive || paid || Admin.on.value;
}
