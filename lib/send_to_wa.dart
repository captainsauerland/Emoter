import 'dart:isolate';
import 'package:emotes_to_stickers/dart_kotlin.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:flutter/services.dart';
import 'package:whatsapp_stickers_exporter/exceptions.dart';
import 'package:emotes_to_stickers/emote.dart';
import 'package:emotes_to_stickers/stickerpack.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as pth;
import 'package:whatsapp_stickers_exporter/whatsapp_stickers_exporter.dart';

Future<String> sendStickerPackToWhatsApp(Stickerpack stickerpack,
    Function(double) progressNotfier, Function(String) onDone) async {
  List<String> paths =
      await convertAllStickersOfPack(stickerpack, progressNotfier);
  String trayPath = await convertTrayImage(stickerpack);
  String returnValue = await sendToWhatsApp(paths, stickerpack.name, trayPath);
  onDone(returnValue);
  return returnValue;
}

Future<List<String>> convertAllStickersOfPack(
    Stickerpack stickerpack, Function(double) progressNotifier) async {
  List<String> fileNames = [];

  for (Emote emote in stickerpack.emotes) {
    String path = await saveWebPImage(await emote.fetchEmoteImage(), emote.id);
    String fileName = pth.basenameWithoutExtension(path);
    fileNames.add(fileName);
  }

  List<String> resultNames = await batchConvert(fileNames, progressNotifier);
  List<String> resultPaths = [];
  Directory dir = await getApplicationCacheDirectory();
  for (String name in resultNames) {
    resultPaths.add("${dir.path}/$name");
  }

  return resultNames;
}

void convertWebP(Map<String, dynamic> params) async {
  final sendPort = params['sendPort'] as SendPort;
  final input = params['input'] as String;
  final rootIsolateToken = params['rootIsolateToken'] as RootIsolateToken;

  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

  final result = await NativeCode().callConvertToWebP(input);
  sendPort.send(result);
}

Future<String> runIsolateConverter(String path, VoidCallback finished) async {
  final receivePort = ReceivePort();
  final rootIsolateToken = ServicesBinding.rootIsolateToken!;

  await Isolate.spawn(convertWebP, {
    'sendPort': receivePort.sendPort,
    'input': path,
    'rootIsolateToken': rootIsolateToken
  });
  String result = await receivePort.first;
  finished();
  return result;
}

Future<List<String>> batchConvert(
    List<String> fileNames, Function(double) progressNotfier) async {
  List<Future<String>> results = [];

  int completed = 0;

  finished() {
    completed++;
    progressNotfier.call(completed / fileNames.length);
  }

  for (String fileName in fileNames) {
    String? convertedPath = await getWebpPathFromCache("${fileName}_c");
    if (convertedPath != null) {
      finished();
      results.add(Future.value(convertedPath));
    } else {
      results.add(runIsolateConverter(fileName, finished));
    }
  }

  Future<List<String>> finishedResults = Future.wait(results);

  return finishedResults;
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
