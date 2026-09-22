part of '../../screens/order_detail_screen.dart';

// ─── Driver Card ──────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final OrderModel order;
  final double? realtimeLat;
  final double? realtimeLng;

  const _DriverCard({
    required this.order,
    this.realtimeLat,
    this.realtimeLng,
  });

  Future<void> _call(String phone) async {
    await callPhone(phone);
  }

  Future<void> _openDriverLocation(BuildContext context) async {
    final driver = order.driver!;
    final lat = realtimeLat ?? driver.latitude;
    final lng = realtimeLng ?? driver.longitude;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa nhận được vị trí của tài xế')),
      );
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$lat,$lng',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final driver = order.driver!;
    final parts = driver.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'TX'
        : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return _FlatCard(
      child: Row(children: [
        SizedBox(
          width: 52,
          height: 52,
          child: ClipOval(
            child: driver.avatarUrl?.trim().isNotEmpty == true
                ? Image.network(
                    driver.avatarUrl!.trim(),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _DriverInitialsAvatar(
                      initials: initials,
                      color: c.accent2,
                    ),
                  )
                : _DriverInitialsAvatar(
                    initials: initials,
                    color: c.accent2,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(driver.name,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: AppFontSize.xl,
                    color: c.textPrimary)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.star_rounded, size: 14, color: c.warning),
              const SizedBox(width: 4),
              Text('4.9 · ${driver.phone}',
                  style: TextStyle(
                      fontSize: AppFontSize.sm, color: c.textSecondary)),
            ]),
          ],
        )),
        _ActionBtn(
            icon: Icons.map_outlined,
            color: c.accent2,
            onTap: () => _openDriverLocation(context)),
        const SizedBox(width: 8),
        _ActionBtn(
            icon: Icons.call_rounded,
            color: c.primary,
            onTap: () => _call(driver.phone)),
      ]),
    );
  }
}

class _DriverInitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;

  const _DriverInitialsAvatar({
    required this.initials,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: color,
        child: Center(
          child: Text(initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w800)),
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      );
}

// ─── Driver Map Card ──────────────────────────────────────────────────────────

class _DriverMapCard extends StatefulWidget {
  final OrderModel order;
  const _DriverMapCard({
    required this.order,
  });

  @override
  State<_DriverMapCard> createState() => _DriverMapCardState();
}

class _DriverMapCardState extends State<_DriverMapCard> {
  gm.GoogleMapController? _ctrl;
  gm.BitmapDescriptor? _shipperIcon;
  gm.BitmapDescriptor? _pickupIcon;
  gm.BitmapDescriptor? _deliveryIcon;
  double _heading = 0.0;
  double? _prevLat, _prevLng;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildIcons());
    loadMapStyle().then((s) {
      if (mounted) setState(() => _mapStyle = s);
    });
  }

  Future<void> _buildIcons() async {
    if (!mounted) return;
    _shipperIcon = await buildDriverMarker(color: AppColors.info);
    _pickupIcon = await buildPinMarker(
        color: AppColors.primary, icon: Icons.storefront_rounded);
    _deliveryIcon = await buildPinMarker(
        color: AppColors.success, icon: Icons.person_rounded);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _DriverMapCard old) {
    super.didUpdateWidget(old);
    final newLat = widget.order.driver?.latitude;
    final newLng = widget.order.driver?.longitude;
    final oldLat = old.order.driver?.latitude;
    final oldLng = old.order.driver?.longitude;
    if (newLat != null &&
        newLng != null &&
        (newLat != oldLat || newLng != oldLng)) {
      if (_prevLat != null && _prevLng != null) {
        setState(
            () => _heading = _bearing(_prevLat!, _prevLng!, newLat, newLng));
      }
      _prevLat = newLat;
      _prevLng = newLng;
      _fitCamera(newLat, newLng);
    }
  }

  double _bearing(double lat1, double lng1, double lat2, double lng2) {
    const toRad = pi / 180;
    final dLng = (lng2 - lng1) * toRad;
    final lat1R = lat1 * toRad;
    final lat2R = lat2 * toRad;
    final y = sin(dLng) * cos(lat2R);
    final x = cos(lat1R) * sin(lat2R) - sin(lat1R) * cos(lat2R) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  void _fitCamera(double dLat, double dLng) {
    if (_ctrl == null) return;
    final destLat = widget.order.deliveryLat;
    final destLng = widget.order.deliveryLng;
    if (destLat != null && destLng != null) {
      final sw = gm.LatLng(
        dLat < destLat ? dLat : destLat,
        dLng < destLng ? dLng : destLng,
      );
      final ne = gm.LatLng(
        dLat > destLat ? dLat : destLat,
        dLng > destLng ? dLng : destLng,
      );
      _ctrl!.animateCamera(gm.CameraUpdate.newLatLngBounds(
          gm.LatLngBounds(southwest: sw, northeast: ne), 60));
    } else {
      _ctrl!.animateCamera(
          gm.CameraUpdate.newLatLngZoom(gm.LatLng(dLat, dLng), 15));
    }
  }

  Set<gm.Marker> get _markers {
    final s = <gm.Marker>{};
    final dLat = widget.order.driver?.latitude;
    final dLng = widget.order.driver?.longitude;
    if (dLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('driver'),
        position: gm.LatLng(dLat, dLng!),
        icon: _shipperIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueAzure),
        rotation: _heading,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: gm.InfoWindow(title: widget.order.driver?.name ?? 'Tài xế'),
      ));
    }
    if (widget.order.pickupLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('pickup'),
        position: gm.LatLng(widget.order.pickupLat!, widget.order.pickupLng!),
        icon: _pickupIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueOrange),
        infoWindow: const gm.InfoWindow(title: 'Điểm lấy'),
      ));
    }
    if (widget.order.deliveryLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('delivery'),
        position:
            gm.LatLng(widget.order.deliveryLat!, widget.order.deliveryLng!),
        icon: _deliveryIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueRed),
        infoWindow: const gm.InfoWindow(title: 'Điểm giao'),
      ));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dLat = widget.order.driver?.latitude ?? 10.0452;
    final dLng = widget.order.driver?.longitude ?? 105.7469;

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.location_on_rounded,
            label: 'Vị trí tài xế',
            iconColor: c.primary),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            child: gm.GoogleMap(
              style: _mapStyle,
              initialCameraPosition: gm.CameraPosition(
                target: gm.LatLng(dLat, dLng),
                zoom: 15,
              ),
              onMapCreated: (mapCtrl) => setState(() => _ctrl = mapCtrl),
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer()),
                Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: c.primary, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(widget.order.driver?.name ?? 'Tài xế',
              style: TextStyle(
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary)),
          const Spacer(),
          Icon(Icons.sync_rounded, size: 14, color: c.textSecondary),
          const SizedBox(width: 4),
          Text('Tự động cập nhật',
              style:
                  TextStyle(fontSize: AppFontSize.xs, color: c.textSecondary)),
        ]),
      ]),
    );
  }
}
