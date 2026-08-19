import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';

// ── Group model ───────────────────────────────────────────────────────────────

class _NotifGroup {
  final String?              orderCode;
  final List<NotificationItem> items; // newest first

  const _NotifGroup({required this.orderCode, required this.items});

  NotificationItem get latest => items.first;
  bool get hasUnread => items.any((n) => !n.isRead);
  bool get isGrouped => items.length > 1;
}

List<_NotifGroup> _groupItems(List<NotificationItem> items) {
  // preserve insertion order by orderCode; no-order items stay individual
  final Map<String, List<NotificationItem>> byOrder = {};
  final List<_NotifGroup> result = [];

  for (final item in items) {
    if (item.orderCode == null) {
      result.add(_NotifGroup(orderCode: null, items: [item]));
    } else {
      byOrder.putIfAbsent(item.orderCode!, () => []).add(item);
    }
  }

  // Insert grouped order notifications at position of their first occurrence
  final seen = <String>{};
  final List<_NotifGroup> merged = [];
  for (final item in items) {
    if (item.orderCode == null) {
      merged.add(_NotifGroup(orderCode: null, items: [item]));
    } else if (!seen.contains(item.orderCode)) {
      seen.add(item.orderCode!);
      merged.add(_NotifGroup(
        orderCode: item.orderCode,
        items: byOrder[item.orderCode!]!,
      ));
    }
  }
  return merged;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationInboxScreen extends ConsumerStatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  ConsumerState<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState
    extends ConsumerState<NotificationInboxScreen> {
  bool _loadingMore = false;

  Future<void> _onLoadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    await ref.read(notificationProvider.notifier).loadMore();
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final items       = ref.watch(notificationProvider);
    // Đếm chính xác trên toàn bộ DB qua unreadCountProvider — không derive
    // từ items (chỉ gồm các trang đã tải) để khớp với badge ở trang chủ.
    final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final groups      = _groupItems(items);
    final hasMore     = ref.watch(notificationHasMoreProvider);
    final c           = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            color: c.surface,
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 8, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Thông báo',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$unreadCount',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ],
                  ]),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 2),
                    Text('$unreadCount thông báo chưa đọc',
                        style: TextStyle(
                            fontSize: 12, color: c.textSecondary)),
                  ],
                ]),
                const Spacer(),
                if (unreadCount > 0)
                  GestureDetector(
                    onTap: () =>
                        ref.read(notificationProvider.notifier).markAllRead(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Đọc tất cả',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: c.primary)),
                    ),
                  ),
              ],
            ),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: groups.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    itemCount: groups.length + (hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      if (i == groups.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: OutlinedButton(
                            onPressed: _loadingMore ? null : _onLoadMore,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.primary,
                              side: BorderSide(
                                  color: c.primary.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md)),
                              minimumSize: const Size(double.infinity, 46),
                            ),
                            child: _loadingMore
                                ? SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: c.primary),
                                  )
                                : Text('Xem thêm',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: c.primary)),
                          ),
                        );
                      }
                      final g = groups[i];
                      return _GroupCard(
                        group: g,
                        onTap: () {
                          for (final n in g.items) {
                            ref
                                .read(notificationProvider.notifier)
                                .markRead(n.id);
                          }
                          if (g.orderCode != null) {
                            context.push('/order/${g.orderCode}');
                          }
                        },
                        onDismiss: () async {
                          final notifier = ref.read(notificationProvider.notifier);
                          // Xoá tuần tự (không Future.wait song song) — mỗi
                          // delete() backup/restore toàn bộ state, chạy song
                          // song có thể khiến 2 lần restore chồng lấn nhau
                          // nếu nhiều item trong cùng nhóm cùng thất bại.
                          var allOk = true;
                          for (final n in g.items) {
                            final ok = await notifier.delete(n.id);
                            if (!ok) allOk = false;
                          }
                          if (!allOk && context.mounted) {
                            AppSnackbar.error(context,
                                'Không thể xoá thông báo, vui lòng thử lại.');
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Group card ────────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final _NotifGroup  group;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _GroupCard({
    required this.group,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;

  _NotifGroup get g => widget.group;

  Color _accentColor(Palette c) =>
      g.orderCode != null ? c.primary : const Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final color  = _accentColor(c);
    final unread = g.hasUnread;

    return Dismissible(
      key: ValueKey(g.orderCode ?? g.latest.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Icon(Icons.delete_outline_rounded, color: c.danger, size: 22),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            decoration: BoxDecoration(
              color: unread
                  ? c.primary.withValues(alpha: context.isDark ? 0.08 : 0.04)
                  : c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: unread
                  ? Border.all(color: c.primary.withValues(alpha: 0.3))
                  : null,
              boxShadow: c.cardShadow,
            ),
            child: Column(children: [
              // ── Main row ──
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Accent block
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color,
                            color.withValues(alpha: 0.65),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft:     Radius.circular(AppRadius.card),
                          topRight:    Radius.circular(AppRadius.sm),
                          bottomLeft:  Radius.circular(AppRadius.sm),
                          bottomRight: Radius.circular(AppRadius.card),
                        ),
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          size: 22, color: Colors.white),
                    ),
                    if (g.isGrouped)
                      Positioned(
                        right: -4, top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: c.surface, width: 1.5),
                          ),
                          child: Text('${g.items.length}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                  ]),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Text(g.latest.title,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: c.textPrimary,
                                    height: 1.3)),
                          ),
                          const SizedBox(width: 8),
                          Text(Fmt.timeAgo(g.latest.createdAt),
                              style: TextStyle(
                                  fontSize: 11, color: c.textSecondary)),
                        ]),
                        const SizedBox(height: 5),
                        Text(g.latest.body,
                            style: TextStyle(
                                fontSize: 13,
                                color: c.textSecondary,
                                height: 1.45),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (g.orderCode != null) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            GestureDetector(
                              onTap: widget.onTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                      alpha: context.isDark ? 0.18 : 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.receipt_long_outlined,
                                      size: 12, color: color),
                                  const SizedBox(width: 5),
                                  Text('Đơn #${g.orderCode}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: color)),
                                ]),
                              ),
                            ),
                            const Spacer(),
                            if (g.isGrouped)
                              GestureDetector(
                                onTap: () => setState(() => _expanded = !_expanded),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    _expanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: c.textSecondary,
                                  ),
                                ),
                              )
                            else
                              Icon(Icons.chevron_right_rounded,
                                  size: 16, color: c.textTertiary),
                          ]),
                        ],
                      ],
                    ),
                  ),

                  // Unread dot
                  if (unread) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                          color: c.primary, shape: BoxShape.circle),
                    ),
                  ],
                ]),
              ),

              // ── Expanded messages ──
              if (_expanded && g.isGrouped) ...[
                Divider(height: 1, color: c.divider, indent: 16, endIndent: 16),
                ...g.items.map((n) => _SubRow(item: n)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Sub-row (expanded messages) ───────────────────────────────────────────────

class _SubRow extends StatelessWidget {
  final NotificationItem item;
  const _SubRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final unread = !item.isRead;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 6, height: 6,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: unread ? c.primary : c.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    color: c.textPrimary)),
            const SizedBox(height: 2),
            Text(item.body,
                style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Text(Fmt.timeAgo(item.createdAt),
            style: TextStyle(fontSize: 10, color: c.textTertiary)),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: AppEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Chưa có thông báo nào',
        titleColor: c.textPrimary,
        subtitle: 'Thông báo đơn hàng sẽ xuất hiện tại đây',
        boxSize: 80,
        boxRadius: 24,
        boxColor: c.primary.withValues(alpha: 0.08),
        iconColor: c.primary,
        iconSize: 40,
        titleFontSize: 16,
        titleWeight: FontWeight.w700,
      ),
    );
  }
}
