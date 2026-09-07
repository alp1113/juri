import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/feed_models.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';
import 'feed.dart';

/// Past this the indentation eats the phone. Deeper replies still nest in the
/// data — the thread keeps its true shape — they just stop stepping right.
const _maxIndent = 5;

/// How deep the server will accept a reply, matching replies_depth_bound.
const _maxDepth = 12;

void openThread(BuildContext context, Take take) =>
    openPage(context, ThreadScreen(take: take));

/// One take and everything said back to it.
class ThreadScreen extends StatefulWidget {
  final Take take;
  const ThreadScreen({super.key, required this.take});
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _composer = TextEditingController();
  final _focus = FocusNode();

  /// Replies the reader has folded away. Collapsing hides the whole branch,
  /// which is the only thing that makes a deep argument readable on a phone.
  final Set<String> _collapsed = {};
  Reply? _replyingTo;
  bool _sending = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final remote = AppScope.of(context).remote;
    if (remote == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await remote.loadThread(widget.take.id);
    } catch (_) {
      if (mounted) setState(() => _error = Tr.t('loadError'));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    final scope = AppScope.of(context);
    final remote = scope.remote;
    final body = _composer.text.trim();
    if (remote == null || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await remote.postReply(
        reviewId: widget.take.id,
        body: body,
        parentId: _replyingTo?.id,
      );
      if (!mounted) return;
      _composer.clear();
      setState(() => _replyingTo = null);
      scope.tick();
    } catch (_) {
      if (mounted) showSaveError(context);
    }
    if (mounted) setState(() => _sending = false);
  }

  /// A reply is hidden when any ancestor is folded, so collapsing the top of a
  /// branch takes the whole branch with it.
  bool _hiddenByCollapse(List<Reply> ordered, Reply reply) {
    final byId = {for (final r in ordered) r.id: r};
    var parent = reply.parentId;
    while (parent != null) {
      if (_collapsed.contains(parent)) return true;
      parent = byId[parent]?.parentId;
    }
    return false;
  }

  int _descendants(List<Reply> ordered, Reply reply) {
    final byId = {for (final r in ordered) r.id: r};
    var count = 0;
    for (final r in ordered) {
      var parent = r.parentId;
      while (parent != null) {
        if (parent == reply.id) {
          count++;
          break;
        }
        parent = byId[parent]?.parentId;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final remote = scope.remote;
    final all = remote?.thread(widget.take.id) ?? const <Reply>[];
    final visible = [
      for (final r in all)
        if (!_hiddenByCollapse(all, r)) r,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Tr.t('threadTitle'),
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: JuriTheme.gold,
              backgroundColor: JuriTheme.surface,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  TakeCard(take: widget.take, showThreadLink: false),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Eyebrow(
                        '${Tr.t('replies').toUpperCase()} · ${all.length}',
                        color: JuriTheme.gold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: JuriTheme.gold,
                          ),
                        ),
                      ),
                    )
                  else if (_error != null)
                    Center(
                      child: TextButton(
                        onPressed: _load,
                        child: Text(Tr.t('retry')),
                      ),
                    )
                  else if (all.isEmpty)
                    EmptyView(
                      title: Tr.t('noReplies'),
                      body: remote == null
                          ? Tr.t('signInToReply')
                          : Tr.t('noRepliesBody'),
                    )
                  else
                    for (final reply in visible)
                      _ReplyRow(
                        key: Key('reply-${reply.id}'),
                        reply: reply,
                        collapsed: _collapsed.contains(reply.id),
                        hiddenCount: _collapsed.contains(reply.id)
                            ? _descendants(all, reply)
                            : 0,
                        onToggleCollapse: () => setState(
                          () => _collapsed.contains(reply.id)
                              ? _collapsed.remove(reply.id)
                              : _collapsed.add(reply.id),
                        ),
                        onReply: reply.depth >= _maxDepth
                            ? null
                            : () {
                                setState(() => _replyingTo = reply);
                                _focus.requestFocus();
                              },
                      ),
                ],
              ),
            ),
          ),
          if (remote != null) _composerBar(),
        ],
      ),
    );
  }

  Widget _composerBar() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: JuriTheme.surface,
        border: Border(top: BorderSide(color: JuriTheme.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Tr.t('replyingTo')}: '
                      '${_replyingTo!.authorName ?? Tr.t('yourTake')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: JuriTheme.gold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _replyingTo = null),
                    child: Text(
                      Tr.t('cancel'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('replyComposer'),
                  controller: _composer,
                  focusNode: _focus,
                  maxLength: 500,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: Tr.t('replyHint'),
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('sendReply'),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward, size: 18),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ReplyRow extends StatelessWidget {
  final Reply reply;
  final bool collapsed;
  final int hiddenCount;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onReply;
  const _ReplyRow({
    super.key,
    required this.reply,
    required this.collapsed,
    required this.hiddenCount,
    required this.onToggleCollapse,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final club = scope.repository.club(reply.authorClubId);
    final indent = (reply.depth > _maxIndent ? _maxIndent : reply.depth) * 14.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        decoration: BoxDecoration(
          color: JuriTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: reply.depth == 0
              ? null
              : Border(
                  left: BorderSide(
                    color: JuriTheme.clubColor(reply.authorClubId)
                        .withValues(alpha: .5),
                    width: 2,
                  ),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClubBadge(club, size: 18, linked: false),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reply.mine
                        ? Tr.t('yourTake')
                        : reply.authorName ?? '?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: JuriTheme.gold,
                    ),
                  ),
                ),
                Text(
                  formatMatchDate(reply.updatedAt),
                  style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(reply.body, style: const TextStyle(fontSize: 13, height: 1.45)),
            Row(
              children: [
                VoteBar(
                  likeCount: reply.likeCount,
                  dislikeCount: reply.dislikeCount,
                  myVote: reply.myVote,
                  onVote: (v) async {
                    final remote = scope.remote;
                    if (remote == null) return;
                    try {
                      await remote.voteOnReply(reply, v);
                      scope.tick();
                    } catch (_) {
                      if (context.mounted) showSaveError(context);
                    }
                  },
                ),
                if (onReply != null)
                  TextButton(
                    onPressed: onReply,
                    child: Text(
                      Tr.t('reply'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                const Spacer(),
                if (hiddenCount > 0 || collapsed)
                  TextButton(
                    onPressed: onToggleCollapse,
                    child: Text(
                      collapsed ? '+$hiddenCount' : Tr.t('collapse'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  )
                else
                  IconButton(
                    onPressed: onToggleCollapse,
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.keyboard_arrow_up,
                      color: JuriTheme.muted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
