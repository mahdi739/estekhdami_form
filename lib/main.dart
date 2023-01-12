import 'package:estekhdami_form/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/home_page.dart';
import 'values.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  String supabaseUrl = const String.fromEnvironment("SUPABASE_URL");
  String supabaseKey = const String.fromEnvironment("SUPABASE_KEY");

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseKey);

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = ThemeData.light().textTheme.apply(fontFamily: 'IRAN Sans').copyWith(button: TextStyle(fontSize: 22, fontFamily: 'IRAN Sans'));
    return MaterialApp(
      theme: ThemeData.light().copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 223, 245, 252)), textTheme: textTheme),
      localizationsDelegates: [
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        Locale("fa", "IR"),
      ],
      locale: Locale("fa", "IR"),
      home: HomePage(),
    );
  }
}
