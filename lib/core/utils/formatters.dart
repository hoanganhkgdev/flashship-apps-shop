import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Fmt {
  static final _vnd = NumberFormat('#,###', 'vi_VN');
  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm');

  static String currency(num amount) => '${_vnd.format(amount)}đ';

  static int toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '0') ?? 0;
  static String dateTime(DateTime dt) => _dtFmt.format(dt.toLocal());

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static String orderStatus(String status) {
    const m = {
      'pending': 'Đang tìm tài xế',
      'assigned': 'Tài xế đã nhận',
      'processing': 'Đã lấy hàng',
      'completed': 'Hoàn thành',
      'cancelled': 'Đã huỷ',
    };
    return m[status] ?? status;
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFAC6900);
      case 'assigned':
      case 'processing':
        return const Color(0xFF1F6DD8);
      case 'completed':
        return const Color(0xFF218A45);
      case 'cancelled':
        return const Color(0xFFCC3336);
      default:
        return const Color(0xFF938A86);
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'assigned':
        return Icons.person_pin_rounded;
      case 'processing':
        return Icons.inventory_2_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
