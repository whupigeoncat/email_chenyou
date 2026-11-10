import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/mail/presentation/services/compose_route_guard.dart';

void main() {
  test('dirty compose route blocks external inbox navigation', () {
    final token = Object();
    expect(ComposeRouteGuard.blocksPop, isFalse);

    ComposeRouteGuard.setBlocking(token, true);
    expect(ComposeRouteGuard.blocksPop, isTrue);

    ComposeRouteGuard.setBlocking(token, false);
    expect(ComposeRouteGuard.blocksPop, isFalse);

    ComposeRouteGuard.setBlocking(token, true);
    ComposeRouteGuard.remove(token);
    expect(ComposeRouteGuard.blocksPop, isFalse);
  });
}
