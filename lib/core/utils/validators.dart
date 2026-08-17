class Validators {
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
    if (v.trim().length < 9) return 'Số điện thoại không hợp lệ';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
    return null;
  }

  static String? required(String? v, {String message = 'Trường này là bắt buộc'}) {
    if (v == null || v.trim().isEmpty) return message;
    return null;
  }
}
