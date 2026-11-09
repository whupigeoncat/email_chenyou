import '../../data/repositories/mail_local_repository.dart';
import '../entities/unified_email.dart';

/// Search facade. FTS5 trigram is used for >= 3 characters; 1-2 character
/// queries (including CJK) fall back to an escaped LIKE scan in the repository.
class SearchEmailsUseCase {
  const SearchEmailsUseCase({required this._localRepository});

  final MailLocalRepository _localRepository;

  Future<List<UnifiedEmail>> call({
    required String query,
    String? accountId,
    bool unreadOnly = false,
    int limit = 100,
  }) {
    return _localRepository.searchEmails(
      query: query,
      accountId: accountId,
      unreadOnly: unreadOnly,
      limit: limit,
    );
  }
}
