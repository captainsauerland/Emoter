import 'dart:convert';
import 'dart:io';

import 'package:emotes_to_stickers/emote.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Stickerpack {
  String name;
  List<Emote> emotes;
  int trayIcon;
  int version;

  Stickerpack({required this.name, required this.emotes, required this.trayIcon, required this.version});

  Map<String, dynamic> toJson(){
    List<Map<String, dynamic>> emotesJsonList = emotes.map((item) => item.toJson()).toList();

    return {
      'name': name,
      'emotes': emotesJsonList,
    };
  }

  Future<void> saveToJson() async {
    // Get the directory to save the file
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    final file = File('$path/$name.json');

    // Convert the object to JSON
    String jsonString = jsonEncode(toJson());

    // Write the JSON string to the file
    await file.writeAsString(jsonString);

    if (kDebugMode) print('Object saved to $path/$name.json');
  }

  static Stickerpack getStickerpackFromJson(String content) {
    Map<String, dynamic> map = jsonDecode(content);

    List<dynamic> emotesListDynamic = map['emotes'];
    List<Emote> emotesList = emotesListDynamic.map((item) => Emote.fromJson(item)).toList();

    return Stickerpack(name: map['name'], emotes: emotesList, trayIcon: 0, version: 0);
  }
}