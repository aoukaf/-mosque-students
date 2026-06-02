import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return android;
  }

  // ─── Web ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3rBLNZnusYoIKSvBYJZzxmEHzL-wU6Vs',
    authDomain: 'bn-aouf.firebaseapp.com',
    projectId: 'bn-aouf',
    storageBucket: 'bn-aouf.firebasestorage.app',
    messagingSenderId: '533389705737',
    appId: '1:533389705737:web:96413aee0323113c4e6ed8',
    measurementId: 'G-FBHWETY9BM',
  );

  // ─── Android ───────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDOMrVC7S3McS-hbYRJxXohlzUKtxV8AAc',
    appId: '1:533389705737:android:e8b9128479c5438b4e6ed8',
    messagingSenderId: '533389705737',
    projectId: 'bn-aouf',
    storageBucket: 'bn-aouf.firebasestorage.app',
  );
}
