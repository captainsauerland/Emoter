import 'dart:math';

import 'package:emotes_to_stickers/api_requester.dart';
import 'package:emotes_to_stickers/database.dart';
import 'package:emotes_to_stickers/emote.dart';
import 'package:string_similarity/string_similarity.dart';

class EmoteSet {
  final String id;
  final String name;
  final int emoteCount;
  final String owner;
  List<Emote>? myEmotes;

  EmoteSet({
    required this.id,
    required this.name,
    required this.emoteCount,
    required this.owner,
  });

  @override
  String toString() {
    return 'EmoteSet(id: $id, name: $name, emoteCount: $emoteCount, owner: $owner)';
  }

  Future<List<Emote>> getEmotes() async{
    myEmotes ??= await fetchEmotesFromSet(id);
    return myEmotes!;
  }

  //one page is 15 emotes
  Future<List<Emote>> getEmotesOnPage(int page, String searchTerm) async{
    var emotes = await getEmotes();

    if (searchTerm.isNotEmpty){
      emotes = emotes.where((emote) =>
        emote.name.toString().toLowerCase().similarityTo(searchTerm.toLowerCase()) > 0.3 //hmm
      ).toList();

      //sorting
      emotes.sort((emote1, emote2) =>
          ((emote1.name.toString().toLowerCase().similarityTo(searchTerm.toLowerCase()) -
          emote2.name.toString().toLowerCase().similarityTo(searchTerm.toLowerCase())) * -100).toInt()
      );
    }

    var shownEmotes = ((page - 1) * 15);
    var remainingEmotes = emotes.length - shownEmotes;

    if (remainingEmotes <= 0) return [];

    var length = min(remainingEmotes, 15);
    emotes = emotes.sublist(shownEmotes, shownEmotes+length);

    List<Emote> emotesLoaded = [];
    for (var emote in emotes){
      emotesLoaded.add(await DatabaseHelper().saveOrGetEmote(emote));
    }
    return emotesLoaded;
  }
}