import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../utils/map_style.dart';
import 'app_decor_widgets.dart';

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
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            AppPageHeader(
              title: 'Chọn vị trí shop',
              subtitle: 'Kéo bản đồ để đặt ghim đúng vị trí',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Stack(
                children: [
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
                  // Ghim cố định giữa bản đồ + chấm bóng dưới đầu nhọn.
                  IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 44),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_pin,
                                color: c.primary, size: 52),
                            Container(
                              width: 12,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.lg,
                    right: AppSpacing.lg,
                    child: Material(
                      color: c.surface,
                      elevation: 3,
                      shadowColor: c.shadow,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        onTap: _loadGpsLocation,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(Icons.my_location_rounded,
                              size: AppSize.iconMd, color: c.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  MediaQuery.paddingOf(context).bottom + AppSpacing.lg),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl)),
                boxShadow: isDark ? null : AppShadows.raised,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('ĐỊA CHỈ ĐÃ CHỌN',
                      style: AppTextStyles.caption
                          .copyWith(color: c.textTertiary, letterSpacing: .6)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_rounded,
                            color: c.primary, size: AppSize.iconMd),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: AppDuration.fast,
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          ),
                          child: _loadingAddress
                              ? Padding(
                                  key: const ValueKey('loading'),
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.full),
                                    child: LinearProgressIndicator(
                                        color: c.primary,
                                        backgroundColor: c.primarySoft),
                                  ),
                                )
                              : Text(
                                  _address ?? 'Đang xác định địa chỉ...',
                                  key: ValueKey(_address),
                                  style: AppTextStyles.bodyStrong.copyWith(
                                      fontSize: AppFontSize.md,
                                      height: 1.35,
                                      color: c.textPrimary),
                                  textAlign: TextAlign.left,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: canConfirm ? _confirm : null,
                    style: FilledButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(AppSize.buttonHeight)),
                    icon: const Icon(Icons.check_rounded, size: AppSize.iconMd),
                    label: const Text('Chọn địa điểm này'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
