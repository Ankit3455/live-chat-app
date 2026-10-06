import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorHandler {
  static void initialize() {
    // Crashlytics has no web implementation: keep Flutter's default logging.
    if (kIsWeb) return;

    // Log Flutter framework errors
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Log asynchronous errors
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  static void logError(String message, dynamic error, StackTrace? stack) {
    debugPrint('❌ ERROR: $message');
    debugPrint('Error: $error');
    if (kIsWeb) return;
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: message,
    );
  }

  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.grey[300])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.purple)),
          ),
        ],
      ),
    );
  }
}