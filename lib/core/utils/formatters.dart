import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Fmt {
  static final _vnd   = NumberFormat('#,###', 'vi_VN');
  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm');

  static String currency(num amount) => '${_vnd.format(amount)}đ';
  static String dateTime(DateTime dt) => _dtFmt.format(dt.toLocal());

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1)  return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24)   return '${diff.inHours} giờ trước';
    if (diff.inDays < 7)     return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static String orderStatus(String status) {
    const m = {
      'pending':    'Đang tìm tài xế',
      'assigned':   'Tài xế đã nhận',
      'processing': 'Đang lấy hàng',
      'completed':  'Hoàn thành',
      'cancelled':  'Đã huỷ',
    };
    return m[status] ?? status;
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'pending':    return const Color(0xFFF59E0B);
      case 'assigned':
      case 'processing':
      case 'on_the_way': return const Color(0xFF3B82F6);
      case 'completed':  return const Color(0xFF10B981);
      case 'cancelled':  return const Color(0xFFEF4444);
      default:           return const Color(0xFF6B7280);
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'pending':    return Icons.hourglass_top_rounded;
      case 'assigned':   return Icons.person_pin_rounded;
      case 'processing': return Icons.inventory_2_rounded;
      case 'on_the_way': return Icons.local_shipping_rounded;
      case 'completed':  return Icons.check_circle_rounded;
      case 'cancelled':  return Icons.cancel_rounded;
      default:           return Icons.help_outline_rounded;
    }
  }
}
