/// Process-local guard for routes that must not be force-popped.
///
/// Notification taps normally return to the inbox, but a dirty or sending
/// compose page owns unsaved work and has its own PopScope confirmation. The
/// mail shell consults this guard before [Navigator.popUntil] so an external
/// tap cannot bypass that protection.
abstract final class ComposeRouteGuard {
  static final Set<Object> _blocking = <Object>{};

  static bool get blocksPop => _blocking.isNotEmpty;

  static void setBlocking(Object token, bool blocking) {
    if (blocking) {
      _blocking.add(token);
    } else {
      _blocking.remove(token);
    }
  }

  static void remove(Object token) {
    _blocking.remove(token);
  }
}
