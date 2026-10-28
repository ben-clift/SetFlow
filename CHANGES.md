# Setflow changes

## First version
- Built from the BeatDeck code base, with no peer-to-peer file sharing in it at all.
- Music comes from your own library (phone, Google Drive, Dropbox, other cloud, or your Mac) and from free, legal catalogues (Jamendo, Internet Archive). Each fetched track keeps its licence and a link to its page.
- Listen-only tracks are a temporary buffer and are removed once played.
- Explore links to listen and buy (Bandcamp, Beatport and others).
- Partner slots for Bandcamp and Beatport (`lib/fetch/partner_source.dart`), switched off until an agreement is in place.
- A one-off unlock is planned (`lib/state/entitlement.dart`), switched off until the app is on Google Play.
