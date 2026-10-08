import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyAW1RRLCETnqCtW9bdIMt_ch3hqa6qrXSw",
            authDomain: "twoja-gastromania.firebaseapp.com",
            projectId: "twoja-gastromania",
            storageBucket: "twoja-gastromania.firebasestorage.app",
            messagingSenderId: "514492810536",
            appId: "1:514492810536:web:d5ecd47b524859b57abc1d",
            measurementId: "G-RF6PSFTJD4"));
  } else {
    await Firebase.initializeApp();
  }
}
