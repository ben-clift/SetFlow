import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sidedeck/fetch/labels.dart';

/// Featured labels, and the explanation for labels that want to take part.
class LabelsPage extends StatelessWidget {
  const LabelsPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    var ok = false;
    try {
      ok = (await const MethodChannel('sidedeck/audio').invokeMethod<bool>('openUrl', {'url': url})) ?? false;
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that page.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const dim = Color(0xFF8A857C);
    return Scaffold(
      appBar: AppBar(title: const Text('Labels'), toolbarHeight: 48),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Featured labels', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (partnerLabels.isEmpty)
          const Text('The first partner labels are being lined up. Their music will appear here, with a link to buy from them.',
              style: TextStyle(color: dim))
        else
          for (final l in partnerLabels)
            Card(
              child: ListTile(
                title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([l.blurb, if (l.genres.isNotEmpty) l.genres.join(', ')].join('\n')),
                isThreeLine: true,
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(context, l.bandcampUrl),
              ),
            ),
        const SizedBox(height: 28),
        const Text('Run a label?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'Setflow is a DJ app that builds a set from music and blends it in time. '
          'Your tracks could be part of it.\n\n'
          'What you get\n'
          '• Your label name, artist and track credit shown every time a track plays\n'
          '• A "Buy" link on every track, so listeners go to your Bandcamp or shop\n'
          '• A featured label page like the list above\n\n'
          'What you control\n'
          '• Which tracks are included, and how (full play or listen-only)\n'
          '• You can remove any or all of your music at any time\n'
          '• Nothing is sold or given away: tracks are never offered as free downloads unless you say so\n\n'
          'What it costs you: nothing.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 16),
        if (labelContactEmail.isNotEmpty)
          FilledButton.icon(
            icon: const Icon(Icons.mail_outline),
            label: const Text('Copy contact email'),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: labelContactEmail));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied. Say hello!')));
            },
          )
        else
          const Text('Contact details will be added before launch.', style: TextStyle(color: dim)),
      ]),
    );
  }
}
