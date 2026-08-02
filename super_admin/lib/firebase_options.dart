// Mismo proyecto Firebase que CV Maker (solo web).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAe1Ux9JkMRzvWXUcflXjuFVrplNfND6Xg',
    appId: '1:929255435139:web:2305abba6d9f2d1a7be4b6',
    messagingSenderId: '929255435139',
    projectId: 'cvmaker-saas-jb',
    authDomain: 'cvmaker-saas-jb.firebaseapp.com',
    storageBucket: 'cvmaker-saas-jb.firebasestorage.app',
  );
}
