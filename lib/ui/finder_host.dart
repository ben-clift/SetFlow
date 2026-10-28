import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What the finder pages (Explore, My tracks) need from the app around them.
/// The full app passes one that opens its free-music search; without one the
/// search text is copied.
class FinderHost {
  const FinderHost({this.searchFree});

  /// Opens a free-music search for the text. Null when the app has none.
  final void Function(BuildContext context, String query)? searchFree;

  bool get hasFreeSearch => searchFree != null;

  Future<void> findFree(BuildContext context, String query) async {
    final open = searchFree;
    if (open != null) {
      open(context, query);
      return;
    }
    await Clipboard.setData(ClipboardData(text: query));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied "$query".')),
      );
    }
  }
}
