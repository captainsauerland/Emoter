import 'package:emotes_to_stickers/http_singleton.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:flutter/foundation.dart';

class Emote {
  String id;
  String? name;
  String? ownerUsername;
  String? hostUrl;
  String? stickerpack; //useless
  int? timeAtCash;
  Uint8List? image; //always 512x512 webp

  Emote({ required this.id, this.name, this.ownerUsername, this.hostUrl, this.stickerpack, this.timeAtCash, this.image});

  @override
  String toString() {
    return 'Emote(id: $id, name: $name, ownerUsername: $ownerUsername, hostUrl: $hostUrl)';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_username': ownerUsername,
      'host_url': hostUrl,
      'stickerpack' : stickerpack,
      'time_at_cash' : timeAtCash,
      //'image' : image
    };
  }

  static Emote fromJson(Map<String, dynamic> map){
    return Emote(
        id: map['id'],
        name: map['name'],
        ownerUsername: map['owner_username'],
        hostUrl: map['host_url'],
        stickerpack: map['stickerpack'],
        timeAtCash: map['time_at_cash']
    );
  }

  Future<Uint8List> fetchEmoteImage({int quality = 4}) async {
    if (image == null){
      Uint8List? imageFromFile = await loadWebPImage(id);
      if (imageFromFile != null){
        image = imageFromFile;
        return imageFromFile;
      }else {
        String hostUrlNonNull = "";
        if (hostUrl == null) {
          throw Exception("No internet connection!");
        } else {
          hostUrlNonNull = hostUrl ?? "";
        }

        final request = await HttpClientSingleton.instance.get(
            Uri.parse("https:$hostUrlNonNull/${quality}x.webp"));


        var response = await request.close(); //hier wird abgesendet
        //DateTime previousTime = DateTime.now();

        if (response.statusCode == 200) {
          try {
            image = await consolidateHttpClientResponseBytes(response).timeout(
                Duration(seconds: 10),
                onTimeout: () async {
                  await Future.delayed(const Duration(seconds: 1));
                  return fetchEmoteImage(); //hmmm also das funktioniert manchmal
                }
            );
            //print(DateTime.now().difference(previousTime).inMilliseconds);
          }catch (e){
            //print("caught");
            return fetchEmoteImage();
          }
          saveWebPImage(image!, id);
          return image!;
        } else {
          throw Exception('Failed to load image');
        }
      }
    }else{
      return Future.value(image); //image was in cache
    }
  }
}