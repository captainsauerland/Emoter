import 'dart:typed_data';
import 'package:emotes_to_stickers/util.dart';
import 'package:flutter/material.dart';
import 'package:emotes_to_stickers/stickerpack.dart';

import 'emote.dart';

class StickerPackViewerLight extends StatefulWidget {
  final Stickerpack stickerpack; //emotes will be outdated
  const StickerPackViewerLight({
    super.key,
    required this.stickerpack,
  });

  @override
  StickerPackViewerLightState createState() => StickerPackViewerLightState();
}

class StickerPackViewerLightState extends State<StickerPackViewerLight> {
  List<Emote> _emotes = [];
  List<GlobalKey<ClickableEmoteTileState>> emoteKeys = [];
  ListNotifier emoteSelectionNotifier = ListNotifier();
  int trayIcon = 0;

  @override
  void initState() {
    super.initState();
    _emotes = widget.stickerpack.emotes;
    trayIcon = widget.stickerpack.trayIcon;

    emoteKeys = List.generate(
        _emotes.length, (_) => GlobalKey<ClickableEmoteTileState>());
    emoteSelectionNotifier.setList(List.filled(_emotes.length, false));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
        child: Scaffold(
      appBar: AppBar(
          title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.stickerpack.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      )),
      body: SafeArea(
          child: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Container(
                  height: 50,
                ),
              ),
              SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 100.0,
                  mainAxisSpacing: 10.0,
                  crossAxisSpacing: 10.0,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return FutureBuilder(
                      future: _emotes[index].fetchEmoteImage(),
                      // Your async function
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else {
                          return ClickableEmoteTile(
                            key: emoteKeys[index],
                            index: index,
                            image: snapshot.requireData,
                            id: _emotes[index].id,
                            name: _emotes[index].name ?? "",
                            username: _emotes[index].ownerUsername ?? "",
                            initialTrayIcon: trayIcon,
                            emoteSelectionNotifier: emoteSelectionNotifier,
                          );
                        }
                      },
                    );
                  },
                  childCount: _emotes.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  height: 100,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          child: ListenableBuilder(
              listenable: emoteSelectionNotifier,
              builder: (BuildContext context, Widget? child) {
                //weiß nicht ob dieser code schrecklich oder gut ist
                if (emoteSelectionNotifier.listItems.isEmpty) {
                  return Text("no emotes");
                }
                int i = 0;
                while (!emoteSelectionNotifier.getFromIndex(i)) {
                  i++;
                  if (i >= emoteSelectionNotifier.listItems.length) {
                    return Text("no emote selected");
                  }
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          FutureBuilder(
                              future: _emotes[i].fetchEmoteImage(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return CircularProgressIndicator();
                                } else if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                } else if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return Icon(Icons.image);
                                } else {
                                  return Image.memory(snapshot.requireData,
                                      width: 50);
                                }
                              }),
                          Container(
                            width: 10,
                          ),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                  _emotes[i].name.toString(),
                                  style: TextStyles.bold,
                                  softWrap: true,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "by: ${_emotes[i].ownerUsername.toString()}",
                                  style: TextStyles.light,
                                  maxLines: 1,
                                )
                              ]))
                        ],
                      ),
                    ),
                  ],
                );
              }),
        ),
      )),
    ));
  }
}

class ClickableEmoteTile extends StatefulWidget {
  final int index;
  final Uint8List image;
  final String id;
  final String name;
  final String username;
  final int initialTrayIcon;
  final ListNotifier emoteSelectionNotifier;

  const ClickableEmoteTile(
      {super.key,
      required this.index,
      required this.image,
      required this.id,
      required this.name,
      required this.username,
      required this.initialTrayIcon,
      required this.emoteSelectionNotifier});

  @override
  ClickableEmoteTileState createState() => ClickableEmoteTileState();
}

class ClickableEmoteTileState extends State<ClickableEmoteTile>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int trayIcon = 0;

  @override
  void initState() {
    super.initState();
    trayIcon = widget.initialTrayIcon;
  }

  void setTrayIcon(int icon) {
    setState(() {
      trayIcon = icon;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
        listenable: widget.emoteSelectionNotifier,
        builder: (BuildContext context, Widget? child) {
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              widget.emoteSelectionNotifier
                  .setAllFalseAndTrueAtIndexIfTrue(widget.index, true);
              //widget.changedClickedStatus(_isClicked, widget.index);
            },
            child: GridTile(
                child: Container(
              decoration: BoxDecoration(
                color: widget.emoteSelectionNotifier.getFromIndex(widget.index)
                    ? colorScheme.tertiary.withAlpha(70)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(children: [
                Align(
                  child: Image.memory(widget.image),
                ),
                widget.emoteSelectionNotifier.getFromIndex(widget.index)
                    ? Image.asset('assets/sign-check.png', width: 22)
                    : Container(),
                (trayIcon == widget.index)
                    ? Align(
                        alignment: Alignment.topRight,
                        child: Image.asset(
                          "assets/tray.png",
                          width: 22,
                        ),
                      )
                    : Container()
              ]),
            )),
          );
        });
  }
}
