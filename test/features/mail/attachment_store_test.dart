import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_mail_client/features/mail/domain/services/attachment_picker.dart';
import 'package:path/path.dart' as p;

void main() {
  test('staged names cannot escape the private outbox directory', () async {
    final sourceDir = await Directory.systemTemp.createTemp('stage_source_');
    final rootDir = await Directory.systemTemp.createTemp('stage_root_');
    addTearDown(() async {
      await sourceDir.delete(recursive: true);
      await rootDir.delete(recursive: true);
    });
    final source = File('${sourceDir.path}/payload.txt');
    await source.writeAsString('safe payload');

    final store = AttachmentStore(
      rootProvider: () async => rootDir,
      idGenerator: () => 'entry',
    );
    final staged = await store.stage(
      PickedAttachment(
        path: source.path,
        fileName: '../../evil/../payload.txt',
        sizeBytes: 12,
        mimeType: 'text/plain',
      ),
    );

    expect(staged.fileName, 'payload.txt');
    expect(p.isWithin(rootDir.path, staged.localPath), isTrue);
    expect(await File(staged.localPath).readAsString(), 'safe payload');

    await store.cleanup([staged]);
    expect(await File(staged.localPath).exists(), isFalse);
  });

  test('missing source is rejected', () async {
    final rootDir = await Directory.systemTemp.createTemp('stage_root_');
    addTearDown(() => rootDir.delete(recursive: true));
    final store = AttachmentStore(rootProvider: () async => rootDir);
    await expectLater(
      store.stage(
        const PickedAttachment(
          path: '/definitely/not/here/file.pdf',
          fileName: 'file.pdf',
          sizeBytes: 1,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  _restartAndForwardTests();
}

void _restartAndForwardTests() {
  test('cleanup works across AttachmentStore instances after restart',
      () async {
    final sourceDir = await Directory.systemTemp.createTemp('stage_source_');
    final rootDir = await Directory.systemTemp.createTemp('stage_root_');
    addTearDown(() async {
      await sourceDir.delete(recursive: true);
      await rootDir.delete(recursive: true);
    });
    final source = File('${sourceDir.path}/persisted.txt');
    await source.writeAsString('persisted payload');

    final first = AttachmentStore(
      rootProvider: () async => rootDir,
      idGenerator: () => 'restart-entry',
    );
    final staged = await first.stage(
      PickedAttachment(
        path: source.path,
        fileName: 'persisted.txt',
        sizeBytes: 17,
        mimeType: 'text/plain',
      ),
    );
    expect(File(staged.localPath).existsSync(), isTrue);

    // A fresh instance has an empty _cachedRoot; cleanup must still resolve
    // the persistent root and remove the old file.
    final restarted = AttachmentStore(rootProvider: () async => rootDir);
    await restarted.cleanupPaths([staged.localPath]);
    expect(File(staged.localPath).existsSync(), isFalse);
  });
}
