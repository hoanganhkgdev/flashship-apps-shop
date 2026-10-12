import 'package:flutter/material.dart';
import '../widgets/app_decor_widgets.dart';

/// Route cho màn hình mở bằng `Navigator.push`: màn tự vẽ nền đặc của app.
/// Các màn hình để nền trong suốt (nền chung vẽ một lần phía ngoài Navigator),
/// nên nếu không có nền riêng thì khi chuyển màn, màn cũ vẫn hiện xuyên qua
/// màn mới trong lúc trượt.
MaterialPageRoute<T> appRoute<T>(
  Widget child, {
  bool fullscreenDialog = false,
}) =>
    MaterialPageRoute<T>(
      fullscreenDialog: fullscreenDialog,
      builder: (_) => AppBackdrop(child: child),
    );
