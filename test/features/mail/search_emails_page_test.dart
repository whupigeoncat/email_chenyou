import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/app/di/core_providers.dart';
import 'package:local_mail_client/features/mail/domain/usecases/search_emails_usecase.dart';
import 'package:local_mail_client/features/mail/presentation/pages/search_emails_page.dart';
import 'package:local_mail_client/features/mail/presentation/providers/mail_providers.dart';

import 'support/mail_fixture.dart';

void main() {
  testWidgets('search page debounces and renders local results', (tester) async {
    final fixture = await MailFixture.create();
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          searchEmailsUseCaseProvider.overrideWithValue(
            SearchEmailsUseCase(localRepository: fixture.localRepository),
          ),
        ],
        child: const MaterialApp(home: SearchEmailsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('search-field')),
      'Quarterly',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-results')), findsOneWidget);
    expect(find.text('Quarterly report'), findsOneWidget);
  });
}
