import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/bible/bible_models.dart';
import '../../services/bible_service.dart';
import '../../widgets/common.dart';

/// Busca instantânea offline: referência ("Jo 3,16") ou palavras (FTS5).
class BibleSearchScreen extends StatefulWidget {
  const BibleSearchScreen({super.key, required this.translationId});
  final String translationId;

  @override
  State<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends State<BibleSearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<BibleVerse> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _results = context.read<BibleService>().repo.search(widget.translationId, q));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tr = context.read<BibleService>().translation(widget.translationId);
    final pad = VsSpacing.page(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Jo 3,16 ou palavra (${tr?.abbreviation ?? ''})',
          ),
          onChanged: _search,
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(pad, VsSpacing.sm, pad, VsSpacing.xxl),
        itemCount: _results.isEmpty ? 1 : _results.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: VsSpacing.sm),
              child: Eyebrow(
                _q.text.trim().isEmpty
                    ? 'Busca offline na tradução ${tr?.name ?? ''}'
                    : '${_results.length}${_results.length == 100 ? '+' : ''} resultado(s)',
              ),
            );
          }
          final v = _results[i - 1];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => Navigator.pop(context, v),
            title: Text(v.reference, style: t.titleMedium?.copyWith(color: cs.primary)),
            subtitle: _Highlighted(text: v.snippet ?? v.text, style: t.bodyMedium),
          );
        },
      ),
    );
  }
}

class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final hl = TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700);
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in RegExp('«(.*?)»').allMatches(text)) {
      spans
        ..add(TextSpan(text: text.substring(last, m.start)))
        ..add(TextSpan(text: m.group(1), style: hl));
      last = m.end;
    }
    spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
