import 'package:material_ui/material_ui.dart';

/// Cores litúrgicas do Rito Romano e a tonalidade de destaque usada na UI.
///
/// As cores são deliberadamente dessaturadas para harmonizar com o dourado
/// fosco (#B8860B) e com o fundo pergaminho — nada de verde/vermelho "puros".
enum LiturgicalColor {
  verde('Verde', Color(0xFF4F7A55), Color(0xFF8DB592)),
  roxo('Roxo', Color(0xFF6B4C82), Color(0xFFB39DCB)),
  branco('Branco', Color(0xFFB8860B), Color(0xFFD9B35A)), // branco/dourado → dourado
  vermelho('Vermelho', Color(0xFF9E2B2B), Color(0xFFE08A80)),
  rosa('Rosa', Color(0xFFB5677D), Color(0xFFE3A6B8));

  const LiturgicalColor(this.label, this.light, this.dark);

  final String label;

  /// Tom de destaque sobre fundo claro (pergaminho).
  final Color light;

  /// Tom de destaque sobre fundo escuro (Modo Igreja).
  final Color dark;

  Color accent(Brightness b) => b == Brightness.dark ? dark : light;

  /// Cor do "pontinho" que representa a cor real da veste litúrgica.
  Color get swatch => switch (this) {
    LiturgicalColor.branco => const Color(0xFFF5EFE0),
    _ => light,
  };

  static LiturgicalColor fromName(String? name) {
    switch ((name ?? '').toLowerCase().trim()) {
      case 'roxo':
      case 'roxa':
      case 'violeta':
        return LiturgicalColor.roxo;
      case 'branco':
      case 'branca':
      case 'dourado':
        return LiturgicalColor.branco;
      case 'vermelho':
      case 'vermelha':
        return LiturgicalColor.vermelho;
      case 'rosa':
      case 'rósea':
        return LiturgicalColor.rosa;
      default:
        return LiturgicalColor.verde;
    }
  }
}
