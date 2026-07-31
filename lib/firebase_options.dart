// File generated for CV Maker SaaS (Firebase project: cvmaker-saas-jb).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAe1Ux9JkMRzvWXUcflXjuFVrplNfND6Xg',
    appId: '1:929255435139:web:2305abba6d9f2d1a7be4b6',
    messagingSenderId: '929255435139',
    projectId: 'cvmaker-saas-jb',
    authDomain: 'cvmaker-saas-jb.firebaseapp.com',
    storageBucket: 'cvmaker-saas-jb.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDj43PdCanvCotnNPA_kLL-4kpOvKP3gV8',
    appId: '1:929255435139:android:9fe09d56d2b257387be4b6',
    messagingSenderId: '929255435139',
    projectId: 'cvmaker-saas-jb',
    storageBucket: 'cvmaker-saas-jb.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAe1Ux9JkMRzvWXUcflXjuFVrplNfND6Xg',
    appId: '1:929255435139:web:2305abba6d9f2d1a7be4b6',
    messagingSenderId: '929255435139',
    projectId: 'cvmaker-saas-jb',
    storageBucket: 'cvmaker-saas-jb.firebasestorage.app',
    iosBundleId: 'com.brs.creadorCv',
  );

  static const FirebaseOptions macos = ios;

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAe1Ux9JkMRzvWXUcflXjuFVrplNfND6Xg',
    appId: '1:929255435139:web:6c1bc263994ca7287be4b6',
    messagingSenderId: '929255435139',
    projectId: 'cvmaker-saas-jb',
    authDomain: 'cvmaker-saas-jb.firebaseapp.com',
    storageBucket: 'cvmaker-saas-jb.firebasestorage.app',
  );
  static const FirebaseOptions linux = windows;
}
