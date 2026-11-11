import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/mail/presentation/pages/mail_shell_page.dart';
import 'motion/mail_motion.dart';
import 'theme/mail_theme.dart';

/// Application root. All mail/provider wiring starts from [MailShellPage],
/// which watches `appRuntimeProvider` exactly once.
class LocalMailApp extends StatefulWidget {
  const LocalMailApp({super.key});

  @override
  State<LocalMailApp> createState() => _LocalMailAppState();
}

class _LocalMailAppState extends State<LocalMailApp> {
  final _navigation = MailNavigationObserver();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _navigation.clearPointer();
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _navigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '本地邮箱',
      debugShowCheckedModeBanner: false,
      theme: buildMailTheme(Brightness.light),
      darkTheme: buildMailTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      navigatorObservers: [_navigation],
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _navigation.pointerDown,
        onPointerMove: _navigation.pointerMove,
        onPointerUp: _navigation.pointerUp,
        onPointerCancel: _navigation.pointerCancel,
        child: child!,
      ),
      home: const MailShellPage(),
    );
  }
}
