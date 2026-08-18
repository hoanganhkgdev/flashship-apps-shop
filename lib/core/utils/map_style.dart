import 'package:flutter/services.dart' show rootBundle;

/// Style JSON ẩn POI mặc định của Google Maps (nhà hàng, cửa hàng, trạm
/// xăng...) — chỉ giữ lại marker do app tự vẽ. Dùng chung cho mọi
/// GoogleMap trong app qua tham số `style`.
Future<String> loadMapStyle() async =>
    rootBundle.loadString('assets/map_style.json');
