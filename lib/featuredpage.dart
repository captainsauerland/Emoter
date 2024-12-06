import 'dart:convert';

import 'package:emotes_to_stickers/database.dart';
import 'package:emotes_to_stickers/emote.dart';
import 'package:emotes_to_stickers/stickerpack.dart';
import 'package:emotes_to_stickers/stickerpackviewer_light.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emotes_to_stickers/imagerow.dart';


class FeaturedPage extends StatefulWidget {
  final VoidCallback triggerStickerpageUpdate;

  const FeaturedPage({super.key, required this.triggerStickerpageUpdate});

  @override
  FeaturedPageState createState() => FeaturedPageState();
}

class FeaturedPageState extends State<FeaturedPage> {
  List<Stickerpack> stickerpacks = [];
  ListNotifier alreadyAddedListNotifier = ListNotifier();

  get folder => null;

  void updateCurrentPage() async {
    int i = 0;
    for (Stickerpack pack in stickerpacks){
      alreadyAddedListNotifier.setIndex(i, await DatabaseHelper().doesPackExist(pack.name));
      i++;
    }
  }

  void loadAllFeaturedPacks() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final jsonFiles = manifestMap.keys
        .where((String key) => key.startsWith('assets/featured/') && key.endsWith('.json'))
        .toList();

    List<String> jsonContents = [];

    for (var filePath in jsonFiles) {
      final jsonString = await rootBundle.loadString(filePath);
      jsonContents.add(jsonString);
    }

    List<Stickerpack> stickerPacksNew = [];

    for (String content in jsonContents){
      Stickerpack pack = Stickerpack.getStickerpackFromJson(content);
      stickerPacksNew.add(pack);

      alreadyAddedListNotifier.add(await DatabaseHelper().doesPackExist(pack.name));
    }

    setState(() {
      stickerpacks = stickerPacksNew;
    });
  }

  @override
  void initState() {
    loadAllFeaturedPacks();
    super.initState();
  }

  void addPackAndUpdate(int packIndex, BuildContext context) async {
    Stickerpack stickerpack = stickerpacks[packIndex];

    //ist etwas umständlich aber naja
    await DatabaseHelper().addStickerpack(stickerpack.name);
    for (Emote emote in stickerpack.emotes){
      await DatabaseHelper().saveOrGetEmote(emote);
      await DatabaseHelper().addEmoteToStickerpack(stickerpack.name, emote.id);
    }
    widget.triggerStickerpageUpdate();

    alreadyAddedListNotifier.setIndex(packIndex, true);


    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("Added ${stickerpack.name} to your sticker packs")
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: <Widget>[
      SliverToBoxAdapter(
          child: Container(
            alignment: Alignment.center,
            height: 100,
            child: Text("pre made stickerpacks :)"),
          )),
      (stickerpacks.isEmpty) ?
      SliverToBoxAdapter(child: Text("no pack added"),) :
      SliverList(
          delegate:
          SliverChildBuilderDelegate((BuildContext context, int index) {
            final pack = stickerpacks[index];
            return Card(
              child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return StickerPackViewerLight(stickerpack: stickerpacks[index]);
                      }),
                  child: ListTile(
                      title:
                      Row(
                        children: [
                          Text(pack.name, style: TextStyles.bold,),
                          Text("  ${pack.emotes.length}/30"),
                        ],
                      ),
                      //Text('${pack.emotes.length} emotes'),
                      subtitle: FutureBuilder(
                          future: Future.value(
                              stickerpacks[index].emotes), //temporary
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return Center(
                                  child: Text('Error: ${snapshot.error}'));
                            } else {
                              return ImageRow(emotes: snapshot.requireData);
                            }
                          }),
                      trailing:
                          ListenableBuilder(
                              listenable: alreadyAddedListNotifier,
                              builder: (BuildContext context, Widget? child) {
                            return (
                                (alreadyAddedListNotifier.getFromIndex(index)) ?
                                    IconButton(
                                        onPressed: () => (),
                                        icon: Icon(CupertinoIcons.checkmark_square_fill),
                                        color: Theme.of(context).colorScheme.primary) :
                                    IconButton(
                                        onPressed: () => addPackAndUpdate(index, context),
                                        icon: Icon(CupertinoIcons.plus_app_fill),
                                    )
                            );
                          })

                      )
              ),
            );
          }, childCount: stickerpacks.length)),
      SliverToBoxAdapter(
        child: Container(
          height: 90,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/ppl.webp',
            width: 40,
          ),
        ),
      )
    ]);
  }
}