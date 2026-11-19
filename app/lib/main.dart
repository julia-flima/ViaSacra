import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'app_state.dart';

/// Via Sacra — Liturgia, Terço, Catecismo e Orações.
/// Idealizado e desenvolvido por Júlia Lima. Licença GPL-3.0.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final services = await AppServices.bootstrap();
  runApp(ViaSacraApp(services: services));
}
