import 'package:flutter/material.dart';

import '../features/mail/presentation/pages/mail_shell_page.dart';

/// Application root. All mail/provider wiring starts from [MailShellPage],
/// which watches `appRuntimeProvider` exactly once.
class LocalMailApp extends StatelessWidget {
  const LocalMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '本地邮箱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MailShellPage(),
    );
  }
}
