import 'package:clindiary/app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    initializeDateFormatting('en_US'),
    FlutterGemma.initialize(maxDownloadRetries: 10),
  ]);
  Intl.defaultLocale = 'en_US';
  runApp(const ProviderScope(child: ClinDiaryApp()));
}

