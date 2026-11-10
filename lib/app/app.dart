import 'package:flutter/material.dart';

import '../features/mail/presentation/pages/mail_shell_page.dart';
import 'theme/mail_theme.dart';

/// Application root. All mail/provider wiring starts from [MailShellPage],
/// which watches `appRuntimeProvider` exactly once.
class LocalMailApp extends StatelessWidget {
  const LocalMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '本地邮箱',
      debugShowCheckedModeBanner: false,
      theme: buildMailTheme(Brightness.light),
      darkTheme: buildMailTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const MailShellPage(),
    );
  }
}
