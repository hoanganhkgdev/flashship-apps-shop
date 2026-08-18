package com.flashship.shop

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (thay vì FlutterActivity) — local_auth cần
// FragmentActivity để hiện BiometricPrompt (vân tay/Face ID).
class MainActivity : FlutterFragmentActivity()
