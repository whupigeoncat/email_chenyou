import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/core_providers.dart';
import '../providers/search_provider.dart';
import '../widgets/account_color_badge.dart';
import 'email_detail_page.dart';

class SearchEmailsPage extends ConsumerStatefulWidget {
  const SearchEmailsPage({super.key});

  @override
  ConsumerState<SearchEmailsPage> createState() => _SearchEmailsPageState();
}

class _SearchEmailsPageState extends ConsumerState<SearchEmailsPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchEmailsProvider);
    final notifier = ref.read(searchEmailsProvider.notifier);
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('search-field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索主题、发件人或正文…',
            border: InputBorder.none,
          ),
          onChanged: notifier.updateQuery,
          onSubmitted: (_) => notifier.searchNow(),
        ),
        actions: [
          IconButton(
            tooltip: state.unreadOnly ? '显示全部' : '仅未读',
            onPressed: () => notifier.setUnreadOnly(!state.unreadOnly),
            icon: Icon(
              state.unreadOnly
                  ? Icons.mark_email_unread
                  : Icons.mark_email_read_outlined,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: accounts.when(
              loading: () => const SizedBox(height: 36),
              error: (_, _) => const SizedBox(height: 36),
              data: (items) => DropdownButtonFormField<String?>(
                key: const Key('search-account-filter'),
                initialValue: state.accountId,
                decoration: const InputDecoration(
                  labelText: '账户筛选',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('全部账户'),
                  ),
                  for (final account in items)
                    DropdownMenuItem<String?>(
                      value: account.id,
                      child: Text(account.email),
                    ),
                ],
                onChanged: notifier.setAccountId,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('仅搜索本地缓存；正文需下载后才能检索。草稿与发件队列仅保存在当前设备。'),
          ),
          Expanded(child: _buildResults(context, state, notifier)),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    SearchEmailsState state,
    SearchEmails notifier,
  ) {
    if (state.query.trim().isEmpty) {
      return const Center(child: Text('输入关键词搜索本地邮件'));
    }
    if (state.isSearching && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    if (state.results.isEmpty) {
      return const Center(child: Text('没有匹配的邮件'));
    }

    return ListView.separated(
      key: const Key('search-results'),
      itemCount: state.results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final email = state.results[index];
        return ListTile(
          leading: AccountColorBadge(colorValue: email.accountColorValue),
          title: Text(
            email.subject.isEmpty ? '(无主题)' : email.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${email.senderDisplay} · ${DateFormat('MM/dd').format(email.sentAt.toLocal())}\n${email.snippet}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          onTap: () {
            final localId = email.localId;
            if (localId == null) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EmailDetailPage(emailLocalId: localId),
              ),
            );
          },
        );
      },
    );
  }
}
