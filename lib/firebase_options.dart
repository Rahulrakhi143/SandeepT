// File generated from your Firebase project configuration
// Project: sandeep-23e47

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAz_dyCOa9HftwFJpPmUoeezrzK_qeefaE',
    appId: '1:33983741180:web:ccabdb2e028b65fbe1ab79',
    messagingSenderId: '33983741180',
    projectId: 'sandeep-23e47',
    authDomain: 'sandeep-23e47.firebaseapp.com',
    storageBucket: 'sandeep-23e47.firebasestorage.app',
    databaseURL: 'https://sandeep-23e47-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAz_dyCOa9HftwFJpPmUoeezrzK_qeefaE',
    appId: '1:33983741180:android:1139ed6323175f22e1ab79',
    messagingSenderId: '33983741180',
    projectId: 'sandeep-23e47',
    storageBucket: 'sandeep-23e47.firebasestorage.app',
    databaseURL: 'https://sandeep-23e47-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAz_dyCOa9HftwFJpPmUoeezrzK_qeefaE',
    appId: '1:33983741180:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '33983741180',
    projectId: 'sandeep-23e47',
    storageBucket: 'sandeep-23e47.firebasestorage.app',
    iosBundleId: 'com.example.trivoraProvider',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAz_dyCOa9HftwFJpPmUoeezrzK_qeefaE',
    appId: '1:33983741180:macos:YOUR_MACOS_APP_ID',
    messagingSenderId: '33983741180',
    projectId: 'sandeep-23e47',
    storageBucket: 'sandeep-23e47.firebasestorage.app',
    iosBundleId: 'com.example.trivoraProvider',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAz_dyCOa9HftwFJpPmUoeezrzK_qeefaE',
    appId: '1:33983741180:windows:YOUR_WINDOWS_APP_ID',
    messagingSenderId: '33983741180',
    projectId: 'sandeep-23e47',
    authDomain: 'sandeep-23e47.firebaseapp.com',
    storageBucket: 'sandeep-23e47.firebasestorage.app',
  );
}
