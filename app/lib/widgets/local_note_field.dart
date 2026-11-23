import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/user_data_repository.dart';

/// Campo de anotação pessoal guardada só no aparelho (tabela `note`).
/// Grava 600 ms após a última tecla e, se houver pendência, ao sair da tela.
class LocalNoteField extends StatefulWidget {
  const LocalNoteField({
    super.key,
    required this.kind,
    required this.noteRef,
    this.label,
    this.hint,
    this.autofocus = false,
    this.onSaved,
  });

  final String kind;
  final String noteRef;
  final String? label;
  final String? hint;
  final bool autofocus;

  /// Chamado depois de gravar (inclusive ao sair da tela com texto pendente).
  final VoidCallback? onSaved;

  @override
  State<LocalNoteField> createState() => _LocalNoteFieldState();
}

class _LocalNoteFieldState extends State<LocalNoteField> {
  static const _debounce = Duration(milliseconds: 600);
  late final UserDataRepository _userData = context.read<AppServices>().userData;
  late final _ctrl = TextEditingController(text: _userData.note(widget.kind, widget.noteRef) ?? '');
  Timer? _timer;

  void _save() {
    _userData.saveNote(widget.kind, widget.noteRef, _ctrl.text);
    widget.onSaved?.call();
  }

  @override
  void dispose() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _save();
    }
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      autofocus: widget.autofocus,
      onChanged: (_) {
        _timer?.cancel();
        _timer = Timer(_debounce, _save);
      },
      minLines: 3,
      maxLines: 10,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: widget.label,
        hintText: widget.hint,
        alignLabelWithHint: true,
      ),
    );
  }
}
