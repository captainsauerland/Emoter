import 'dart:io';

import 'package:emotes_to_stickers/emote.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_to_clipboard/image_to_clipboard.dart';

import 'package:path_provider/path_provider.dart';


String limitString(String input, int maxLength) {
  if (input.length <= maxLength) {
    return input;
  } else {
    return '${input.substring(0, maxLength)}...';
  }
}

class ListNotifier extends ChangeNotifier {
  List<bool> listItems = [];

  List<bool> get items => listItems;

  bool getFromIndex(int index) {
    return listItems[index];
  }

  void setList(List<bool> newList) {
    listItems = newList;
    notifyListeners();
  }

  void add(bool newItem){
    listItems.add(newItem);
  }

  void setIndex(int index, bool newValue){
    listItems[index] = newValue;
    notifyListeners();
  }

  void setAllFalseAndTrueAtIndexIfTrue(int index, bool? value) {
    if (value != null && value) {
      for (int i = 0; i < listItems.length; i++) {
        listItems[i] = false;
      }
    }
    listItems[index] = true;
    notifyListeners();
  }
}

class TextStyles{
  static TextStyle bold = TextStyle(
        fontWeight: FontWeight.bold
  );
  static TextStyle light = TextStyle(
      fontSize: 12
  );
  static TextStyle big = TextStyle(
      fontSize: 24
  );
}

Future<String> saveWebPImage(
    Uint8List webPImageBytes, String fileName, {bool saveToExternal = false}) async {
  final Directory? directory;
  if (saveToExternal){
    directory = await getExternalStorageDirectory();
  }else{
    directory = await getApplicationCacheDirectory();
  }
  final filePath = '${directory!.path}/$fileName.webp';

  final file = File(filePath);
  await file.writeAsBytes(webPImageBytes);

  return filePath;
}

Future<Uint8List?> loadWebPImage(String fileName) async {
  final directory = await getApplicationCacheDirectory();
  final filePath = '${directory.path}/$fileName.webp';

  final file = File(filePath);
  if (await file.exists()) {
    return await file.readAsBytes();
  } else {
    return null;
  }
}

Future<String?> getWebpPathFromCache(String fileName) async{
  final directory = await getApplicationCacheDirectory();
  final filePath = '${directory.path}/$fileName.webp';
  final file = File(filePath);
  if (await file.exists()) {
    return filePath;
  } else {
    return null;
  }
}

Future<void> cleanCache({bool cleanAll = false}) async{
  final directory = await getApplicationCacheDirectory();
  //final now = DateTime.now();

  if (await directory.exists()) {
    final files = directory.listSync();

    for (var file in files) {
      if (file is File && (!file.path.contains('_c') || cleanAll)) {
        //final fileStat = await file.stat();
        //final creationTime = fileStat.changed;

        //if (now.difference(creationTime).inHours > 1) {
          await file.delete();
          if (kDebugMode) print('Deleted: ${file.path}');
        //}
      }
    }
  } else {
    if (kDebugMode) print('Directory does not exist');
  }
}

Future<int> calculateCacheSize() async {
  final directory = await getApplicationCacheDirectory();
  return await _calculateDirectorySize(directory);
}

Future<int> _calculateDirectorySize(Directory directory) async {
  int totalSize = 0;
  final List<FileSystemEntity> entities = directory.listSync();

  for (FileSystemEntity entity in entities) {
    if (entity is File) {
      totalSize += await entity.length();
    } else if (entity is Directory) {
      totalSize += await _calculateDirectorySize(entity);
    }
  }

  return totalSize;
}


void addEmoteImageToClipboard(Emote emote) async {
  String path = await saveWebPImage(await emote.fetchEmoteImage(), emote.id, saveToExternal: true);
  await ImageToClipboard.copyImageToClipboard(path);
  // if (result != null){
  //   File out = File(path);
  //   out.delete();
  // }
}

class MyAppBarTitle extends StatelessWidget{
  const MyAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
        (Theme.of(context).brightness == Brightness.dark)
            ? Image.asset(
          'assets/icon/logo_transparent_white.png',
          width: 40,
        )
            : Image.asset(
          'assets/icon/logo_transparent_black.png',
          width: 40,
        ),
        Container(
          width: 10,
        ),
        const Text('Emoter', style: TextStyle(fontSize: 18),
        ),
      ]);
  }
}
