import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../utils/map_style.dart';

class MapPickResult {
  final String address;
  final double lat;
  final double lng;
  final String? placeName;
  final String? contactName;
  final String? contactPhone;

  const MapPickResult({
    required this.address,
    required this.lat,
    required this.lng,
    this.placeName,
    this.contactName,
    this.contactPhone,
  });
}

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  gm.GoogleMapController? _controller;
  double _centerLat = 10.0452;
  double _centerLng = 105.7469;
  String? _address;
  bool _loadingAddress = false;
  bool _mapReady = false;
  bool _hasLocationPermission = false;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _centerLat = widget.initialLat!;
      _centerLng = widget.initialLng!;
    } else {
      _loadGpsLocation();
    }
    _ensureLocationPermission();
    loadMapStyle().then((s) {
      if (mounted) setState(() => _mapStyle = s);
    });
  }

  // GoogleMap(myLocationEnabled: true) crash nếu chưa có quyền vị trí — xin
  // quyền tường minh ở đây thay vì trông chờ vào side-effect của _loadGpsLocation
  // (không chạy khi đã có initialLat/Lng truyền sẵn).
  Future<void> _ensureLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (mounted && granted) setState(() => _hasLocationPermission = true);
    } catch (_) {}
  }

  Future<void> _loadGpsLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      // Không lấy được vị trí hiện tại: giữ tâm bản đồ mặc định và nhắc người
      // dùng tự kéo bản đồ tới chỗ cần chọn.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Không lấy được vị trí hiện tại. Hãy kéo bản đồ tới địa điểm cần chọn.'),
      ));
      return;
    }
    _centerLat = pos.latitude;
    _centerLng = pos.longitude;
    if (_mapReady && _controller != null) {
      await _controller!.animateCamera(
        gm.CameraUpdate.newCameraPosition(
          gm.CameraPosition(
              target: gm.LatLng(_centerLat, _centerLng), zoom: 15.5),
        ),
      );
    } else {
      setState(() {});
    }
    _reverseGeocode(_centerLat, _centerLng);
  }

  void _onMapCreated(gm.GoogleMapController controller) {
    _controller = controller;
    _mapReady = true;
    _reverseGeocode(_centerLat, _centerLng);
  }

  void _onCameraMove(gm.CameraPosition position) {
    _centerLat = position.target.latitude;
    _centerLng = position.target.longitude;
  }

  void _onCameraIdle() => _reverseGeocode(_centerLat, _centerLng);

  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() => _loadingAddress = true);
    final addr = await LocationService.addressFromCoords(lat, lng);
    if (!mounted) return;
    setState(() {
      _address = addr ?? 'Không xác định được địa chỉ';
      _loadingAddress = false;
    });
  }

  void _confirm() {
    if (_address == null || _loadingAddress) return;
    Navigator.of(context).pop(MapPickResult(
      address: _address!,
      lat: _centerLat,
      lng: _centerLng,
    ));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    final canConfirm = !_loadingAddress && _address != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        appBar: const _MapPickerHeader(),
        body: Column(children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: gm.GoogleMap(
                  style: _mapStyle,
                  initialCameraPosition: gm.CameraPosition(
                    target: gm.LatLng(_centerLat, _centerLng),
                    zoom: 15.5,
                  ),
                  onMapCreated: _onMapCreated,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  myLocationEnabled: _hasLocationPermission,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                right: 72,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: c.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Icon(Icons.touch_app_outlined,
                          size: 18, color: c.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Di chuyển bản đồ để đặt ghim',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .18),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.location_on_rounded,
                              color: Colors.white, size: 25),
                        ),
                        Container(
                          width: 3,
                          height: 14,
                          color: c.primary,
                        ),
                        Container(
                          width: 15,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Material(
                  color: c.surface,
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    onTap: _loadGpsLocation,
                    borderRadius: BorderRadius.circular(13),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.my_location_rounded,
                          size: 21, color: c.primary),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          _SelectedLocationPanel(
            address: _address,
            loading: _loadingAddress,
            canConfirm: canConfirm,
            onConfirm: _confirm,
          ),
        ]),
      ),
    );
  }
}

class _MapPickerHeader extends StatelessWidget implements PreferredSizeWidget {
  const _MapPickerHeader();

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppBar(
      backgroundColor: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 70,
      leadingWidth: 72,
      centerTitle: false,
      titleSpacing: 0,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.maybePop(context),
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            side: BorderSide(color: c.divider),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: c.textPrimary),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Chọn trên '),
                TextSpan(text: 'bản đồ', style: TextStyle(color: c.primary)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sectionTitle.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Đặt ghim đúng vị trí giao nhận',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedLocationPanel extends StatelessWidget {
  final String? address;
  final bool loading;
  final bool canConfirm;
  final VoidCallback onConfirm;

  const _SelectedLocationPanel({
    required this.address,
    required this.loading,
    required this.canConfirm,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vị trí đã chọn',
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.location_on_outlined,
                      size: 20, color: c.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppDuration.fast,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    ),
                    child: loading
                        ? Padding(
                            key: const ValueKey('loading'),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              child: LinearProgressIndicator(
                                minHeight: 5,
                                color: c.primary,
                                backgroundColor: c.primarySoft,
                              ),
                            ),
                          )
                        : Column(
                            key: ValueKey(address),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                address ?? 'Đang xác định địa chỉ...',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kiểm tra địa chỉ trước khi xác nhận',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canConfirm ? onConfirm : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              disabledBackgroundColor: c.primary.withValues(alpha: .45),
              disabledForegroundColor: c.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(
              loading ? 'Đang xác định địa chỉ...' : 'Xác nhận vị trí',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
