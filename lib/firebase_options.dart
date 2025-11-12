import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Default [FirebaseOptions] used by the application for each supported platform.
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAzzRSKczzI7rv9l85o_GVqxz4CvyMQhkU',
    appId: '1:563870455681:android:30543e8d6b501c9321ba80',
    messagingSenderId: '563870455681',
    projectId: 'drug-tracker-868f1',
    storageBucket: 'drug-tracker-868f1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD3XwTmPvWEfuze8zNIFP0kSF0eBnOCJaM',
    appId: '1:563870455681:ios:e963e3135547023e21ba80',
    messagingSenderId: '563870455681',
    projectId: 'drug-tracker-868f1',
    storageBucket: 'drug-tracker-868f1.firebasestorage.app',
    iosBundleId: 'com.example.drugsTaken',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4rFirk3_qopMZMPOSYprEdEchp9qcr40',
    appId: '1:563870455681:web:40d8a66ee74c996021ba80',
    messagingSenderId: '563870455681',
    projectId: 'drug-tracker-868f1',
    authDomain: 'drug-tracker-868f1.firebaseapp.com',
    storageBucket: 'drug-tracker-868f1.firebasestorage.app',
    measurementId: 'G-R1XRYLQ1CH',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC4rFirk3_qopMZMPOSYprEdEchp9qcr40',
    appId: '1:563870455681:web:44953c5b1adcfa9d21ba80',
    messagingSenderId: '563870455681',
    projectId: 'drug-tracker-868f1',
    authDomain: 'drug-tracker-868f1.firebaseapp.com',
    storageBucket: 'drug-tracker-868f1.firebasestorage.app',
    measurementId: 'G-TWQ2V7YNDG',
  );
}
