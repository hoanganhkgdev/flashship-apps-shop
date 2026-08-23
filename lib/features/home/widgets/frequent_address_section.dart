part of '../screens/home_screen.dart';

// ─── Địa chỉ thường dùng ────────────────────────────────────────────────────────

class _FrequentAddressSection extends ConsumerWidget {
  const _FrequentAddressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressProvider);
    final c = context.colors;

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (addresses) {
        if (addresses.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(Icons.location_on_rounded, size: 15, color: c.info),
                ),
                const SizedBox(width: 8),
                Text('Địa chỉ thường dùng',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
              ]),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _AddressChip(entry: addresses[i]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _AddressChip extends StatelessWidget {
  final AddressEntry entry;
  const _AddressChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => context.push('/create-order', extra: entry),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.divider),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on_rounded, size: 14, color: c.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
          ),
        ]),
      ),
    );
  }
}
