import 'dart:async';
import 'package:flutter/services.dart';

class NativeCode {
  static const platform = MethodChannel('captainsauerland/native');

  Future<String> callConvertToWebP(String fileName) async {
    try {
      final result = await platform.invokeMethod<String>("convertWebP", fileName);
      return result.toString();
    } on PlatformException catch (e) {
      return "Failed to call Kotlin method: '${e.message}'.";
    }
  }

  Future<String> callConvertToTrayImage(String fileName) async {
    try {
      final result = await platform.invokeMethod<String>("convertToTray", fileName);
      return result.toString();
    } on PlatformException catch (e) {
      return "Failed to call Kotlin method: '${e.message}'.";
    }
  }
}
