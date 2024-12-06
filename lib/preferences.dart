import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> saveThemeBrightness(bool isLightMode) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/preferences.txt');
  await file.writeAsString(isLightMode ? 'light' : 'dark');
}

Future<String> readThemeBrightness() async{
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/preferences.txt');
  if (file.existsSync()) {
    final contents = file.readAsStringSync();
    return contents == 'dark' ? 'dark' : 'light';
  }
  return 'none'; // Default to light mode if no preference is found
}