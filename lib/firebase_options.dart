// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web is not configured for this app.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyBiEyWGNhWj-sVJYmkfk_V5Y6wkNm5LJIA',
    appId:             '1:219581386028:ios:12ac30c4966da582f27089',
    messagingSenderId: '219581386028',
    projectId:         'flashship-app',
    storageBucket:     'flashship-app.firebasestorage.app',
    iosBundleId:       'com.flashship.shop',
    databaseURL:       'https://flashship-app-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // Thêm app Android com.flashship.shop vào Firebase Console để lấy appId
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBiEyWGNhWj-sVJYmkfk_V5Y6wkNm5LJIA',
    appId:             'REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: '219581386028',
    projectId:         'flashship-app',
    storageBucket:     'flashship-app.firebasestorage.app',
    databaseURL:       'https://flashship-app-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
