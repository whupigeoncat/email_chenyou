import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../../../app/di/core_providers.dart';
import '../../domain/entities/unified_email.dart';
import 'mail_providers.dart';

part 'email_detail_provider.g.dart';

enum EmailBodyViewMode { html, plain }

const Object _unset = Object();

@immutable
class EmailDetailState {
  const EmailDetailState({
    this.emailLocalId,
    this.allowRemoteImages = false,
    this.trustedSender = false,
    this.isLoadingBody = false,
    this.isLoadingAttachments = false,
    this.cidLocalPaths = const {},
    this.viewMode = EmailBodyViewMode.html,
    this.errorMessage,
  });

  final int? emailLocalId;
  final bool allowRemoteImages;
  final bool trustedSender;
  final bool isLoadingBody;
  final bool isLoadingAttachments;

  /// Normalized Content-ID -> local cache file path.
  final Map<String, String> cidLocalPaths;
  final EmailBodyViewMode viewMode;
  final String? errorMessage;

  bool get canLoadRemoteImages => allowRemoteImages || trustedSender;

  EmailDetailState copyWith({
    Object? emailLocalId = _unset,
    bool? allowRemoteImages,
    bool? trustedSender,
    bool? isLoadingBody,
    bool? isLoadingAttachments,
    Map<String, String>? cidLocalPaths,
    EmailBodyViewMode? viewMode,
    Object? errorMessage = _unset,
  }) {
    return EmailDetailState(
      emailLocalId: identical(emailLocalId, _unset)
          ? this.emailLocalId
          : emailLocalId as int?,
      allowRemoteImages: allowRemoteImages ?? this.allowRemoteImages,
      trustedSender: trustedSender ?? this.trustedSender,
      isLoadingBody: isLoadingBody ?? this.isLoadingBody,
      isLoadingAttachments:
          isLoadingAttachments ?? this.isLoadingAttachments,
      cidLocalPaths: cidLocalPaths ?? this.cidLocalPaths,
      viewMode: viewMode ?? this.viewMode,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

@riverpod
class EmailDetail extends _$EmailDetail {
  @override
  EmailDetailState build() => const EmailDetailState();

  void open(int? emailLocalId) {
    if (emailLocalId == null) {
      state = const EmailDetailState();
      return;
    }
    state = EmailDetailState(
      emailLocalId: emailLocalId,
      viewMode: state.viewMode,
    );
    unawaited(_loadBody(emailLocalId));
    unawaited(_loadTrust(emailLocalId));
  }

  void setViewMode(EmailBodyViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void allowRemoteImagesOnce() {
    state = state.copyWith(allowRemoteImages: true, errorMessage: null);
  }

  void resetRemoteImagePermission() {
    state = state.copyWith(
      allowRemoteImages: false,
      errorMessage: null,
    );
  }

  Future<void> trustSender(String senderEmail) async {
    if (senderEmail.trim().isEmpty) return;
    try {
      await ref
          .read(trustedSendersRepositoryProvider)
          .trustSender(senderEmail);
      if (!ref.mounted) return;
      state = state.copyWith(trustedSender: true, allowRemoteImages: true);
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(errorMessage: failure.userMessage);
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(errorMessage: '保存信任发件人失败：$error');
    }
  }

  Future<void> loadBody() async {
    final localId = state.emailLocalId;
    if (localId == null) return;
    await _loadBody(localId, force: true);
  }

  Future<void> downloadInlineAttachments() async {
    final localId = state.emailLocalId;
    if (localId == null || state.isLoadingAttachments) return;
    await _downloadInlineAttachments(localId);
  }

  Future<void> _loadBody(int localId, {bool force = false}) async {
    if (state.emailLocalId != localId) return;
    if (state.isLoadingBody && !force) return;

    try {
      final local = ref.read(mailLocalRepositoryProvider);
      final email = await local.getEmail(localId);
      if (email == null) {
        if (!ref.mounted) return;
        state = state.copyWith(errorMessage: '邮件已不在本地缓存中。');
        return;
      }
      if (email.bodyDownloaded) {
        // Second open: restore only cached CID paths from SQLite. Missing
        // inline images are deliberately left to the explicit manual button;
        // opening an already downloaded email must never fetch attachments.
        _restoreCachedInlinePaths(localId, email);
        return;
      }
      if (!ref.mounted || state.emailLocalId != localId) return;

      state = state.copyWith(isLoadingBody: true, errorMessage: null);
      final account = await ref
          .read(authRepositoryProvider)
          .getAccount(email.accountId);
      if (account == null) throw StateError('账户不存在或已被删除');
      await ref.read(fetchMessageBodyUseCaseProvider).call(
            account: account,
            emailLocalId: localId,
          );
      if (!ref.mounted || state.emailLocalId != localId) return;
      state = state.copyWith(isLoadingBody: false, errorMessage: null);
      await _downloadInlineAttachments(localId);
    } on AppFailure catch (failure) {
      if (!ref.mounted || state.emailLocalId != localId) return;
      state = state.copyWith(
        isLoadingBody: false,
        errorMessage: failure.userMessage,
      );
    } catch (error) {
      if (!ref.mounted || state.emailLocalId != localId) return;
      state = state.copyWith(
        isLoadingBody: false,
        errorMessage: '加载正文失败：$error',
      );
    }
  }

  void _restoreCachedInlinePaths(int localId, UnifiedEmail email) {
    if (!ref.mounted || state.emailLocalId != localId) return;
    final paths = <String, String>{};
    for (final attachment in email.attachments) {
      final contentId = attachment.contentId;
      final path = attachment.localCachePath;
      if (!attachment.isInline ||
          contentId == null ||
          path == null ||
          path.isEmpty) {
        continue;
      }
      paths[_normalizeCid(contentId)] = path;
    }
    state = state.copyWith(
      cidLocalPaths: paths,
      isLoadingAttachments: false,
      errorMessage: null,
    );
  }

  Future<void> _downloadInlineAttachments(int localId) async {
    if (state.emailLocalId != localId || state.isLoadingAttachments) return;
    state = state.copyWith(isLoadingAttachments: true);
    try {
      final local = ref.read(mailLocalRepositoryProvider);
      final email = await local.getEmail(localId);
      if (email == null) return;
      final account = await ref
          .read(authRepositoryProvider)
          .getAccount(email.accountId);
      if (account == null) return;

      final paths = Map<String, String>.of(state.cidLocalPaths);
      for (final attachment in email.attachments) {
        final contentId = attachment.contentId;
        if (!attachment.isInline || contentId == null) continue;
        if (attachment.localCachePath != null &&
            attachment.localCachePath!.isNotEmpty) {
          paths[_normalizeCid(contentId)] = attachment.localCachePath!;
          continue;
        }
        try {
          final path = await ref.read(downloadAttachmentUseCaseProvider).call(
                account: account,
                emailLocalId: localId,
                partId: attachment.partId,
              );
          paths[_normalizeCid(contentId)] = path;
        } on Object {
          // A missing inline image must not block the textual body.
        }
      }
      if (!ref.mounted || state.emailLocalId != localId) return;
      state = state.copyWith(
        isLoadingAttachments: false,
        cidLocalPaths: paths,
      );
    } finally {
      if (ref.mounted && state.emailLocalId == localId) {
        state = state.copyWith(isLoadingAttachments: false);
      }
    }
  }

  Future<void> _loadTrust(int localId) async {
    final email = await ref.read(mailLocalRepositoryProvider).getEmail(localId);
    if (email == null || !ref.mounted || state.emailLocalId != localId) {
      return;
    }
    final trusted = await ref
        .read(trustedSendersRepositoryProvider)
        .isTrusted(email.fromAddress);
    if (!ref.mounted || state.emailLocalId != localId) return;
    state = state.copyWith(trustedSender: trusted);
  }

  static String _normalizeCid(String value) {
    var cid = value.trim();
    if (cid.startsWith('<')) cid = cid.substring(1);
    if (cid.endsWith('>')) cid = cid.substring(0, cid.length - 1);
    return cid.trim();
  }
}

@riverpod
Stream<UnifiedEmail?> emailById(Ref ref, int localId) {
  return ref.watch(mailLocalRepositoryProvider).watchEmail(localId);
}
