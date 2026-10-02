part of '../screens/home_screen.dart';

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({super.key, required this.order});

  int get _progressStep => switch (order.status) {
        'assigned' => 0,
        'processing' => 1,
        'completed' => 2,
        _ => -1,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final code = order.code.startsWith('#') ? order.code : '#${order.code}';
    final receiver = order.receiverName?.trim();
    final destination = order.isBatch && order.stops.isNotEmpty
        ? '${order.stops.length} điểm giao'
        : receiver == null || receiver.isEmpty
            ? order.deliveryAddress
            : '$receiver · ${order.deliveryAddress}';
    final showDriver = order.driver != null &&
        (order.status == 'assigned' || order.status == 'processing');
    final status = _statusMeta(c);

    final dark = context.isDark;
    final radius = BorderRadius.circular(AppRadius.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: dark ? null : AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/order/${order.code}'),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? [
                            Colors.white.withValues(alpha: .14),
                            Colors.white.withValues(alpha: .05),
                          ]
                        : [
                            Colors.white.withValues(alpha: .85),
                            Colors.white.withValues(alpha: .45),
                          ],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: dark ? .22 : .9),
                      width: 1.2),
                ),
                child: Stack(children: [
                  // Vầng sáng theo màu trạng thái ở góc phải.
                  Positioned(
                    top: -50,
                    right: -40,
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          status.color.withValues(alpha: dark ? .25 : .22),
                          status.color.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Trạng thái hiện tại — thứ chủ shop cần thấy đầu tiên.
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.xs + 2),
                                        decoration: BoxDecoration(
                                          color: status.color
                                              .withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.full),
                                        ),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                    color: status.color,
                                                    shape: BoxShape.circle),
                                              ),
                                              const SizedBox(
                                                  width: AppSpacing.sm),
                                              Flexible(
                                                child: Text(status.label,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppTextStyles.label
                                                        .copyWith(
                                                            color: status.color,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800)),
                                              ),
                                            ]),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Row(children: [
                                        Flexible(
                                          child: Text(
                                            order.isBatch
                                                ? 'Đơn gộp $code'
                                                : 'Đơn $code',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyStrong
                                                .copyWith(color: c.textPrimary),
                                          ),
                                        ),
                                        if (order.isBatch) ...[
                                          const SizedBox(width: AppSpacing.sm),
                                          _OrderPill(
                                            label: '${order.stops.length} điểm',
                                            color: c.accent2,
                                          ),
                                        ],
                                      ]),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('PHÍ SHIP',
                                          style: AppTextStyles.caption.copyWith(
                                              color: c.textTertiary,
                                              letterSpacing: .4)),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(Fmt.currency(order.shippingFee),
                                          style: AppTextStyles.metric
                                              .copyWith(color: c.primary)),
                                    ]),
                              ]),
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(alpha: dark ? .06 : .55),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: dark ? .12 : .8)),
                            ),
                            child: OrderRouteLines(
                              pickup: order.pickupAddress,
                              delivery: destination,
                            ),
                          ),
                          if (showDriver) ...[
                            const SizedBox(height: AppSpacing.md),
                            OrderDriverRow(driver: order.driver!),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          if (order.status == 'pending')
                            _FindingDriverBanner(color: status.color)
                          else
                            _OrderProgress(currentStep: _progressStep),
                          const SizedBox(height: AppSpacing.lg),
                          Divider(height: 1, color: c.divider),
                          const SizedBox(height: AppSpacing.md),
                          Row(children: [
                            if (order.distanceKm != null) ...[
                              Icon(Icons.route_rounded,
                                  size: AppSize.iconSm, color: c.textTertiary),
                              const SizedBox(width: AppSpacing.xs),
                              Text('${order.distanceKm!.toStringAsFixed(1)} km',
                                  style: AppTextStyles.label
                                      .copyWith(color: c.textSecondary)),
                            ],
                            if (order.distanceKm != null &&
                                order.codAmount != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm),
                                child: Text('·',
                                    style: AppTextStyles.label
                                        .copyWith(color: c.textTertiary)),
                              ),
                            if (order.codAmount != null) ...[
                              Icon(Icons.payments_outlined,
                                  size: AppSize.iconSm, color: c.textTertiary),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                    'Tiền lấy hàng ${Fmt.currency(order.codAmount!)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.label
                                        .copyWith(color: c.textSecondary)),
                              ),
                            ],
                            const Spacer(),
                            Text('Xem chi tiết',
                                style: AppTextStyles.label.copyWith(
                                    color: c.primary,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(Icons.arrow_forward_rounded,
                                size: AppSize.iconSm, color: c.primary),
                          ]),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ({String label, Color color}) _statusMeta(Palette c) =>
      switch (order.status) {
        'pending' => (label: 'Đang tìm tài xế', color: c.warning),
        'assigned' => (label: 'Tài xế đang đến lấy', color: c.info),
        'processing' => (label: 'Đang trên đường giao', color: c.primary),
        _ => (label: Fmt.orderStatus(order.status), color: c.textSecondary),
      };
}

class _OrderPill extends StatelessWidget {
  final String label;
  final Color color;

  const _OrderPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(label,
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w800)),
      );
}

class _FindingDriverBanner extends StatelessWidget {
  final Color color;
  const _FindingDriverBanner({required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(children: [
        SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('Hệ thống đang kết nối tài xế gần cửa hàng',
              style: AppTextStyles.label.copyWith(
                  color: c.textSecondary, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  final int currentStep;
  const _OrderProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const labels = ['Đã nhận', 'Đã lấy hàng', 'Hoàn thành'];
    const icons = [
      Icons.check_rounded,
      Icons.inventory_2_rounded,
      Icons.flag_rounded,
    ];

    return Column(children: [
      Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          _ProgressDot(
              icon: icons[i],
              active: i <= currentStep,
              current: i == currentStep),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < currentStep ? c.primary : c.divider,
              ),
            ),
        ],
      ]),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Text(labels[i],
                textAlign: i == 0
                    ? TextAlign.left
                    : i == labels.length - 1
                        ? TextAlign.right
                        : TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontWeight:
                      i == currentStep ? FontWeight.w800 : FontWeight.w600,
                  color: i == currentStep ? c.primary : c.textTertiary,
                )),
          ),
      ]),
    ]);
  }
}

class _ProgressDot extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool current;

  const _ProgressDot({
    required this.icon,
    required this.active,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: AppDuration.fast,
      width: current ? 26 : 22,
      height: current ? 26 : 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? c.primary : c.surface,
        shape: BoxShape.circle,
        border: Border.all(
            color: active ? c.primary : c.divider, width: current ? 3 : 2),
        boxShadow: current && !context.isDark ? AppShadows.soft : null,
      ),
      child: Icon(icon,
          size: current ? 14 : 12,
          color: active ? Colors.white : c.textTertiary),
    );
  }
}
