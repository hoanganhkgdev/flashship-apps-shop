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
    if (!mounted || pos == null) return;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(bottom: BorderSide(color: c.divider)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: c.divider),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 17, color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('Chọn vị trí shop',
                        style: TextStyle(
                            fontSize: AppFontSize.xxl,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary)),
                  ],
                ),
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
                    const IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 42),
                          child: Icon(Icons.location_pin,
                              color: AppColors.primary, size: 58),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 18,
                      right: 18,
                      child: Material(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InkWell(
                          onTap: _loadGpsLocation,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: c.divider),
                              boxShadow: c.cardShadow,
                            ),
                            child: Icon(Icons.my_location_rounded,
                                size: 22, color: c.textPrimary),
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
                    20, 18, 20, MediaQuery.paddingOf(context).bottom + 18),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.divider)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: c.primary, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
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
                                    child: LinearProgressIndicator(
                                        color: c.primary,
                                        backgroundColor: c.primarySoft),
                                  )
                                : Text(
                                    _address ?? 'Đang xác định địa chỉ...',
                                    key: ValueKey(_address),
                                    style: TextStyle(
                                        fontSize: AppFontSize.xl,
                                        height: 1.35,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary),
                                    textAlign: TextAlign.left,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: (_loadingAddress || _address == null)
                            ? null
                            : _confirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: c.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                        child: const Text('Chọn địa điểm này',
                            style: TextStyle(
                                fontSize: AppFontSize.xl,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
