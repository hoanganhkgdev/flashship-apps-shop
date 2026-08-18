import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show BitmapDescriptor;

/// Vẽ marker "pin giọt nước" (đầu tròn + đuôi nhọn) bằng Canvas, raster ra
/// BitmapDescriptor lúc runtime — dùng cho điểm lấy/điểm giao trên bản đồ,
/// thay cho asset PNG tĩnh. Neo mặc định của BitmapDescriptor.bytes là đáy
/// giữa ảnh, khớp đúng với mũi nhọn của pin nằm sát cạnh dưới canvas.
Future<BitmapDescriptor> buildPinMarker({
  required Color color,
  required IconData icon,
  double size = 72,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas   = Canvas(recorder);

  final headRadius = size * 0.35; // đầu tròn: đường kính 0.7*size
  final headCenter = Offset(size / 2, headRadius);
  final tailHalfWidth = headRadius * 0.45;
  final tailTopY = headCenter.dy + headRadius * 0.35; // nằm trong lòng vòng tròn

  final headPath = Path()
    ..addOval(Rect.fromCircle(center: headCenter, radius: headRadius));
  final tailPath = Path()
    ..moveTo(headCenter.dx - tailHalfWidth, tailTopY)
    ..lineTo(headCenter.dx + tailHalfWidth, tailTopY)
    ..lineTo(headCenter.dx, size)
    ..close();
  final pinPath = Path.combine(PathOperation.union, headPath, tailPath);

  canvas.drawPath(pinPath, Paint()..color = color);

  final iconPainter = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: headRadius * 0.85,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    )
    ..layout();
  iconPainter.paint(
    canvas,
    Offset(headCenter.dx - iconPainter.width / 2,
        headCenter.dy - iconPainter.height / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.round(), size.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// Vẽ marker tài xế — hình tròn đặc + mũi tên trắng chỉ lên trên, để
/// Marker(rotation: bearing) xoay theo hướng di chuyển thực tế. Neo tâm
/// giữa (cần set anchor: Offset(0.5, 0.5) khi tạo Marker, giống code cũ).
Future<BitmapDescriptor> buildDriverMarker({
  Color color = const Color(0xFF3B82F6),
  double size = 24,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas   = Canvas(recorder);
  final center   = Offset(size / 2, size / 2);
  final radius   = size / 2;

  canvas.drawCircle(center, radius, Paint()..color = color);

  final arrow = Path()
    ..moveTo(center.dx, center.dy - radius * 0.32)
    ..lineTo(center.dx + radius * 0.26, center.dy + radius * 0.22)
    ..lineTo(center.dx - radius * 0.26, center.dy + radius * 0.22)
    ..close();
  canvas.drawPath(arrow, Paint()..color = Colors.white);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.round(), size.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}
