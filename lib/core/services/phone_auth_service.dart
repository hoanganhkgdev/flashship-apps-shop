import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';

/// Lỗi xác minh số điện thoại đã được dịch sang tiếng Việt, hiển thị thẳng cho người dùng.
class PhoneAuthException implements Exception {
  final String message;
  const PhoneAuthException(this.message);
  @override
  String toString() => message;
}

/// Thông báo lỗi cho cả lỗi Firebase lẫn lỗi API của backend.
String phoneAuthErrorMessage(Object e) =>
    e is PhoneAuthException ? e.message : parseApiError(e);

final phoneAuthServiceProvider =
    Provider<PhoneAuthService>((_) => PhoneAuthService());

/// Xác minh số điện thoại bằng Firebase Phone Auth (SMS do Firebase gửi),
/// cùng cách làm với app driver và customer. Firebase chỉ dùng để xác minh
/// số: phiên đăng nhập thật do backend cấp, nên sau khi lấy ID token là đăng
/// xuất khỏi Firebase ngay. Backend tự đối chiếu số trong token với số gửi lên.
class PhoneAuthService {
  String? _verificationId;
  int? _resendToken;

  String _e164(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('84')) return '+$digits';
    return '+84${digits.startsWith('0') ? digits.substring(1) : digits}';
  }

  /// Gửi (hoặc gửi lại) mã SMS qua Firebase. Ném [PhoneAuthException] nếu thất bại.
  Future<void> sendCode(String phone) async {
    final completer = Completer<void>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _e164(phone),
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        // Không tự đăng nhập khi Android đọc được SMS — luôn để người dùng
        // nhập mã rồi lấy ID token ở confirmCode().
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          debugPrint('[PhoneAuth] ${e.code}: ${e.message}');
          if (!completer.isCompleted) {
            completer.completeError(PhoneAuthException(_firebaseError(e.code)));
          }
        },
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (e) {
      debugPrint('[PhoneAuth] sendCode lỗi: $e');
      if (!completer.isCompleted) {
        completer.completeError(
            const PhoneAuthException('Có lỗi xảy ra. Vui lòng thử lại.'));
      }
    }
    return completer.future;
  }

  /// Kiểm tra mã SMS với Firebase, trả ID token để gửi lên backend.
  /// Ném [PhoneAuthException] nếu sai mã hoặc hết hạn.
  Future<String> confirmCode(String code) async {
    final id = _verificationId;
    if (id == null) {
      throw const PhoneAuthException('Vui lòng gửi lại mã xác minh');
    }
    try {
      final cred = await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: code),
      );
      final token = await cred.user?.getIdToken();
      await FirebaseAuth.instance.signOut();
      if (token == null) {
        throw const PhoneAuthException('Có lỗi xảy ra. Vui lòng thử lại.');
      }
      return token;
    } on FirebaseAuthException catch (e) {
      throw PhoneAuthException(_firebaseError(e.code));
    }
  }

  String _firebaseError(String code) => switch (code) {
        'invalid-verification-code' => 'Mã OTP không đúng',
        'session-expired' => 'Mã OTP đã hết hạn, vui lòng gửi lại',
        'too-many-requests' => 'Bạn thử quá nhiều lần, vui lòng thử lại sau',
        'invalid-phone-number' => 'Số điện thoại không hợp lệ',
        'network-request-failed' => 'Lỗi mạng, vui lòng thử lại',
        _ => 'Không gửi được mã xác minh ($code), vui lòng thử lại',
      };
}
