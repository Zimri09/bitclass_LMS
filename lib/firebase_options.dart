// File generated manually - replace with your Firebase project credentials
// Get these values from: Firebase Console > Project Settings > Your apps > Web app
//
// To use FlutterFire CLI instead, install Git and run:
//   dart pub global activate flutterfire_cli
//   flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  // Firebase credentials from Firebase Console > Project Settings > General > Your apps

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB7VgfhkmhDtcYIsVf6FsyYBl_qISss8Rk',
    appId: '1:157798445220:web:ae062f04998c1dbada7631',
    messagingSenderId: '157798445220',
    projectId: 'bitclass-lms',
    authDomain: 'bitclass-lms.firebaseapp.com',
    storageBucket: 'bitclass-lms.firebasestorage.app',
    measurementId: 'G-7Q5E69L1EX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCVwK9rK948v-hRoG7VW8zKRHaS_hxicXw',
    appId: '1:157798445220:android:9ecbbace73b12627da7631',
    messagingSenderId: '157798445220',
    projectId: 'bitclass-lms',
    storageBucket: 'bitclass-lms.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCx4pHOFkm0yDuI72mbAcS_wizc-euRpFE',
    appId: '1:157798445220:ios:4848a204b91191ebda7631',
    messagingSenderId: '157798445220',
    projectId: 'bitclass-lms',
    storageBucket: 'bitclass-lms.firebasestorage.app',
    iosClientId:
        '157798445220-f9sjsv2lgo3jv011i1e3kphcpul2bbh8.apps.googleusercontent.com',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCx4pHOFkm0yDuI72mbAcS_wizc-euRpFE',
    appId: '1:157798445220:ios:4848a204b91191ebda7631',
    messagingSenderId: '157798445220',
    projectId: 'bitclass-lms',
    storageBucket: 'bitclass-lms.firebasestorage.app',
    iosClientId:
        '157798445220-f9sjsv2lgo3jv011i1e3kphcpul2bbh8.apps.googleusercontent.com',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB7VgfhkmhDtcYIsVf6FsyYBl_qISss8Rk',
    appId: '1:157798445220:web:72e3523094367164da7631',
    messagingSenderId: '157798445220',
    projectId: 'bitclass-lms',
    authDomain: 'bitclass-lms.firebaseapp.com',
    storageBucket: 'bitclass-lms.firebasestorage.app',
    measurementId: 'G-3BK0QVKD3V',
  );
}
