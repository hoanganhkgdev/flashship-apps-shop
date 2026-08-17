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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyDSYWeYYO9oPK5I2HAkJ145eRp36WwnYaI',
    appId:             '1:219581386028:android:d2e2d77ff6a965bcf27089',
    messagingSenderId: '219581386028',
    projectId:         'flashship-app',
    storageBucket:     'flashship-app.firebasestorage.app',
    databaseURL:       'https://flashship-app-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
