import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../data/user_data_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/global_audio_mini_player.dart';
import '../../widgets/reading_appearance_button.dart';
import '../../widgets/sacred_art_header.dart';

/// Leitura em tela cheia, sem distrações, com os quatro passos da Lectio Divina.
class LectioDivinaScreen extends StatefulWidget {
  const LectioDivinaScreen({
    super.key,
    required this.title,
    required this.text,
    this.author,
    this.source,
    this.url,
    this.license,
    this.noteRef,
  });

  final String title;
  final String text;
  final String? author;
  final String? source;
  final String? url;
  final String? license;

  /// Chave da anotação pessoal (tabela `note`, kind 'lectio'). Padrão: o título.
  final String? noteRef;

  @override
  State<LectioDivinaScreen> createState() => _LectioDivinaScreenState();
}

class _LectioDivinaScreenState extends State<LectioDivinaScreen> {
  static const _steps = [
    ('Lectio', 'Leia devagar. O que o texto diz?'),
    ('Meditatio', 'O que o texto diz a mim, hoje?'),
    ('Oratio', 'O que eu digo a Deus a partir desta Palavra?'),
    ('Contemplatio', 'Permaneça em silêncio diante de Deus.'),
  ];
  static const _noteKind = 'lectio';
  bool _immersive = false;
  late final UserDataRepository _userData = context.read<AppServices>().userData;
  late final String _noteRef = widget.noteRef ?? widget.title;
  late final _note = TextEditingController(text: _userData.note(_noteKind, _noteRef) ?? '');
  Timer? _saveDebounce;

  void _onNoteChanged(String _) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _saveNote);
  }

  void _saveNote() => _userData.saveNote(_noteKind, _noteRef, _note.text);

  @override
  void dispose() {
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _saveNote();
    }
    _note.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(_immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pad = VsSpacing.page(context);
    final art = context.read<AppServices>().content.art['header-lectio'];
    return Scaffold(
      appBar: _immersive
          ? null
          : AppBar(
              title: const Text('Lectio Divina'),
              actions: [
                const ReadingAppearanceButton(),
                IconButton(tooltip: 'Modo imersivo', onPressed: _toggleImmersive, icon: const Icon(Icons.fullscreen)),
              ],
            ),
      body: GestureDetector(
        onDoubleTap: _toggleImmersive,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, _immersive ? VsSpacing.xl : VsSpacing.sm, pad, VsSpacing.xxl),
            children: [
              if (!_immersive) ...[
                SacredArtBanner(title: widget.title, subtitle: 'LECTIO · MEDITATIO · ORATIO · CONTEMPLATIO', art: art),
                const SizedBox(height: VsSpacing.lg),
              ],
              if (widget.author != null) Eyebrow(widget.author!),
              const SizedBox(height: 8),
              Text(widget.title, style: t.headlineSmall),
              const CrossDivider(),
              SelectionArea(
                child: Text(widget.text, style: t.bodyLarge?.copyWith(fontSize: (t.bodyLarge?.fontSize ?? 18) + 2)),
              ),
              const CrossDivider(),
              for (final (name, prompt) in _steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: VsSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(name),
                      const SizedBox(height: 4),
                      Text(prompt, style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              TextField(
                controller: _note,
                onChanged: _onNoteChanged,
                minLines: 3,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Minha anotação (somente neste aparelho)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: VsSpacing.md),
              if (widget.source != null)
                SourceAttribution(source: widget.source!, url: widget.url, license: widget.license),
              if (_immersive)
                Padding(
                  padding: const EdgeInsets.only(top: VsSpacing.lg),
                  child: Text('Toque duas vezes para sair do modo imersivo.', style: t.bodySmall),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _immersive ? null : const GlobalAudioMiniPlayer(useSafeArea: true),
    );
  }
}
