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
  final String? orderCode;
  final List<NotificationItem> items; // newest first

  const _NotifGroup({required this.orderCode, required this.items});

  NotificationItem get latest => items.first;
  bool get hasUnread => items.any((n) => !n.isRead);
  bool get isGrouped => items.length > 1;
}

enum _NotificationFilter { all, unread, orders }

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
  _NotificationFilter _filter = _NotificationFilter.all;

  Future<void> _onLoadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    await ref.read(notificationProvider.notifier).loadMore();
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(notificationProvider);
    // Đếm chính xác trên toàn bộ DB qua unreadCountProvider — không derive
    // từ items (chỉ gồm các trang đã tải) để khớp với badge ở trang chủ.
    final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final groups = _groupItems(items);
    final filteredGroups = switch (_filter) {
      _NotificationFilter.all => groups,
      _NotificationFilter.unread =>
        groups.where((group) => group.hasUnread).toList(),
      _NotificationFilter.orders =>
        groups.where((group) => group.orderCode != null).toList(),
    };
    final hasMore = ref.watch(notificationHasMoreProvider);
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          _NotificationHeader(
            unreadCount: unreadCount,
            onBack: () => context.pop(),
            onMarkAllRead: unreadCount > 0
                ? () => ref.read(notificationProvider.notifier).markAllRead()
                : null,
          ),
          _NotificationFilters(
            selected: _filter,
            totalCount: groups.length,
            unreadCount: groups.where((group) => group.hasUnread).length,
            orderCount: groups.where((group) => group.orderCode != null).length,
            onSelected: (filter) => setState(() => _filter = filter),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              Expanded(
                child: Text(
                  switch (_filter) {
                    _NotificationFilter.all => 'Cập nhật mới nhất',
                    _NotificationFilter.unread => 'Thông báo chưa đọc',
                    _NotificationFilter.orders => 'Cập nhật đơn hàng',
                  },
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${filteredGroups.length} mục',
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ]),
          ),
          Expanded(
            child: items.isEmpty
                ? const _EmptyState()
                : filteredGroups.isEmpty
                    ? _FilteredEmptyState(filter: _filter)
                    : RefreshIndicator(
                        color: c.primary,
                        onRefresh: () =>
                            ref.read(notificationProvider.notifier).refresh(),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          itemCount: filteredGroups.length + (hasMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (i == filteredGroups.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: OutlinedButton.icon(
                                  onPressed: _loadingMore ? null : _onLoadMore,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: c.primary,
                                    backgroundColor: c.surface,
                                    side: BorderSide(color: c.divider),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize:
                                        const Size(double.infinity, 48),
                                  ),
                                  icon: _loadingMore
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: c.primary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.expand_more_rounded,
                                          size: 19,
                                        ),
                                  label: const Text(
                                    'Xem thêm thông báo',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            }
                            final group = filteredGroups[i];
                            return _GroupCard(
                              group: group,
                              onTap: () {
                                for (final notification in group.items) {
                                  ref
                                      .read(notificationProvider.notifier)
                                      .markRead(notification.id);
                                }
                                if (group.orderCode != null) {
                                  context.push('/order/${group.orderCode}');
                                }
                              },
                              onDismiss: () async {
                                final notifier =
                                    ref.read(notificationProvider.notifier);
                                var allOk = true;
                                for (final notification in group.items) {
                                  final ok =
                                      await notifier.delete(notification.id);
                                  if (!ok) allOk = false;
                                }
                                if (!allOk && context.mounted) {
                                  AppSnackbar.error(
                                    context,
                                    'Không thể xoá thông báo, vui lòng thử lại.',
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onBack;
  final VoidCallback? onMarkAllRead;

  const _NotificationHeader({
    required this.unreadCount,
    required this.onBack,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      color: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Row(children: [
            IconButton(
              tooltip: 'Quay lại',
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: c.surface,
                foregroundColor: c.textPrimary,
                fixedSize: const Size.square(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Thông '),
                      TextSpan(
                        text: 'báo',
                        style: TextStyle(color: c.primary),
                      ),
                    ]),
                    style: AppTextStyles.screenTitle.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.notifications_active_outlined,
                        size: 14, color: c.primary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        unreadCount > 0
                            ? '$unreadCount thông báo chưa đọc'
                            : 'Bạn đã xem tất cả thông báo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            if (onMarkAllRead != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Đánh dấu tất cả đã đọc',
                onPressed: onMarkAllRead,
                style: IconButton.styleFrom(
                  backgroundColor: c.surface,
                  foregroundColor: c.primary,
                  fixedSize: const Size.square(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 20),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _NotificationFilters extends StatelessWidget {
  final _NotificationFilter selected;
  final int totalCount;
  final int unreadCount;
  final int orderCount;
  final ValueChanged<_NotificationFilter> onSelected;

  const _NotificationFilters({
    required this.selected,
    required this.totalCount,
    required this.unreadCount,
    required this.orderCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final options = [
      (_NotificationFilter.all, Icons.inbox_outlined, 'Tất cả', totalCount),
      (
        _NotificationFilter.unread,
        Icons.mark_email_unread_outlined,
        'Chưa đọc',
        unreadCount
      ),
      (
        _NotificationFilter.orders,
        Icons.receipt_long_outlined,
        'Đơn hàng',
        orderCount
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: options.map((option) {
          final active = option.$1 == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(option.$1),
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? c.primary : c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: active ? c.primary : c.divider,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(option.$2,
                        size: 16,
                        color: active ? Colors.white : c.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      option.$3,
                      style: AppTextStyles.caption.copyWith(
                        color: active ? Colors.white : c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withValues(alpha: .20)
                            : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${option.$4}',
                        style: AppTextStyles.caption.copyWith(
                          color: active ? Colors.white : c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Group card ────────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final _NotifGroup group;
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

  (IconData, Color) _visual(Palette c) {
    final title = g.latest.title.toLowerCase();
    if (title.contains('voucher') || title.contains('ưu đãi')) {
      return (Icons.card_giftcard_rounded, c.warning);
    }
    if (title.contains('huỷ') || title.contains('hủy')) {
      return (Icons.cancel_outlined, c.danger);
    }
    if (title.contains('hoàn thành') || title.contains('thành công')) {
      return (Icons.check_circle_outline_rounded, c.success);
    }
    if (title.contains('tài xế')) {
      return (Icons.delivery_dining_outlined, c.info);
    }
    if (g.orderCode != null) {
      return (Icons.local_shipping_outlined, c.primary);
    }
    return (Icons.notifications_none_rounded, const Color(0xFF8B5CF6));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visual = _visual(c);
    final icon = visual.$1;
    final color = visual.$2;
    final unread = g.hasUnread;

    return Dismissible(
      key: ValueKey(g.orderCode ?? g.latest.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline_rounded, color: c.danger, size: 21),
          const SizedBox(height: 3),
          Text(
            'Xóa',
            style: AppTextStyles.caption.copyWith(
              color: c.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: unread
                  ? c.primary.withValues(alpha: context.isDark ? .10 : .045)
                  : c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unread ? c.primary.withValues(alpha: .28) : c.divider,
              ),
            ),
            child: Column(children: [
              // ── Main row ──
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Accent block
                      Stack(clipBehavior: Clip.none, children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(icon, size: 22, color: color),
                        ),
                        if (g.isGrouped)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: c.primary,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: c.surface, width: 1.5),
                              ),
                              child: Text('${g.items.length}',
                                  style: const TextStyle(
                                      fontSize: AppFontSize.xs,
                                      fontWeight: FontWeight.w600,
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
                            Text(
                              g.latest.title,
                              style: AppTextStyles.bodyStrong.copyWith(
                                fontWeight:
                                    unread ? FontWeight.w600 : FontWeight.w500,
                                color: c.textPrimary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(Icons.schedule_rounded,
                                  size: 13, color: c.textTertiary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  Fmt.timeAgo(g.latest.createdAt),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: c.textTertiary,
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                                g.isGrouped && !_expanded
                                    ? '${g.latest.body} · ${g.items.length} cập nhật'
                                    : g.latest.body,
                                style: AppTextStyles.body.copyWith(
                                  color: c.textSecondary,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            if (g.orderCode != null) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: widget.onTap,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: color.withValues(
                                            alpha:
                                                context.isDark ? 0.18 : 0.10),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(children: [
                                        Icon(Icons.receipt_long_outlined,
                                            size: 12, color: color),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            'Đơn #${g.orderCode}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      ]),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (g.isGrouped)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _expanded = !_expanded),
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
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: c.primary.withValues(alpha: .25),
                                blurRadius: 5,
                              ),
                            ],
                          ),
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
    final c = context.colors;
    final unread = !item.isRead;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: unread ? c.primary : c.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              item.title,
              style: AppTextStyles.label.copyWith(
                fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(item.body,
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Text(
          Fmt.timeAgo(item.createdAt),
          style: AppTextStyles.caption.copyWith(color: c.textTertiary),
        ),
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
        titleFontSize: AppFontSize.xl,
        titleWeight: FontWeight.w600,
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  final _NotificationFilter filter;
  const _FilteredEmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isUnread = filter == _NotificationFilter.unread;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              isUnread
                  ? Icons.mark_email_read_outlined
                  : Icons.receipt_long_outlined,
              size: 34,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isUnread ? 'Bạn đã đọc hết rồi' : 'Chưa có cập nhật đơn hàng',
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isUnread
                ? 'Thông báo mới sẽ xuất hiện tại đây.'
                : 'Các thay đổi trạng thái đơn sẽ được cập nhật tại đây.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ]),
      ),
    );
  }
}
