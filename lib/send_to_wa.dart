import 'package:emotes_to_stickers/dart_kotlin.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:whatsapp_stickers_exporter/exceptions.dart';
import 'package:emotes_to_stickers/emote.dart';
import 'package:emotes_to_stickers/stickerpack.dart';
import 'dart:io';
import 'package:path/path.dart' as pth;
import 'package:whatsapp_stickers_exporter/whatsapp_stickers_exporter.dart';

Future<String> sendStickerPackToWhatsApp(Stickerpack stickerpack,
    Function(double) progressNotfier, Function(String) onDone) async {
  try {
    List<String> paths =
        await convertAllStickersOfPack(stickerpack, progressNotfier);
    String trayPath = await convertTrayImage(stickerpack);
    String returnValue =
        await sendToWhatsApp(paths, stickerpack.name, trayPath);
    onDone(returnValue);
    return returnValue;
  } catch (e) {
    final error = e.toString().replaceFirst('Exception: ', '');
    onDone(error);
    return error;
  }
}

Future<List<String>> convertAllStickersOfPack(
    Stickerpack stickerpack, Function(double) progressNotifier) async {
  List<String> fileNames = [];

  for (Emote emote in stickerpack.emotes) {
    String path = await saveWebPImage(await emote.fetchEmoteImage(), emote.id);
    String fileName = pth.basenameWithoutExtension(path);
    fileNames.add(fileName);
  }

  return batchConvert(fileNames, progressNotifier);
}

Future<List<String>> batchConvert(
    List<String> fileNames, Function(double) progressNotfier) async {
  if (fileNames.isEmpty) {
    progressNotfier.call(1.0);
    return [];
  }

  List<String> convertedPaths = [];

  for (int i = 0; i < fileNames.length; i++) {
    final fileName = fileNames[i];

    String? convertedPath = await getWebpPathFromCache("${fileName}_c");
    convertedPath ??= await NativeCode().callConvertToWebP(fileName);

    final exists = await File(convertedPath).exists();
    if (!exists) {
      throw Exception("Failed to convert $fileName to webp");
    }

    convertedPaths.add(convertedPath);
    progressNotfier.call((i + 1) / fileNames.length);
  }

  return convertedPaths;
}

Future<String> convertTrayImage(Stickerpack stickerpack) async {
  int trayIndex = stickerpack.trayIcon;
  Emote tray = stickerpack.emotes[trayIndex];
  String path = await saveWebPImage(await tray.fetchEmoteImage(), tray.id);
  String fileName = pth.basenameWithoutExtension(path);
  String convertedName = await NativeCode().callConvertToTrayImage(fileName);
  return convertedName;
}

Future<String> sendToWhatsApp(
    List<String> paths, String name, String trayImagePath) async {
  List<List<String>> stickerSet = [];

  for (String path in paths) {
    List<String> stickerObject = <String>[];
    stickerObject.add(WhatsappStickerImage.fromFile(path).path);
    stickerObject.add('😀');
    stickerSet.add(stickerObject);
  }

  var trayImage = WhatsappStickerImage.fromFile(trayImagePath).path;

  var exporter = WhatsappStickersExporter();

  try {
    await exporter.addStickerPack(
        name,
        //identifier
        name,
        //name
        "Emoter",
        //publisher
        trayImage,
        //trayImage
        "https://play.google.com/store/apps/details?id=captainsauerland.emotes_to_stickers",
        //publisherWebsite
        "",
        //privacyPolicyWebsite
        "",
        //licenseAgreementWebsite
        true,
        //animatedStickerPack
        stickerSet);
    return "";
  } on WhatsappStickersException catch (e) {
    return e.cause.toString();
  } catch (e) {
    return "unknown problem";
  }
}
