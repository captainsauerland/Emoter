import 'package:emotes_to_stickers/database.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:emotes_to_stickers/stickerpack.dart';

import 'emote.dart';

class StickerPackViewer extends StatefulWidget {
  final Stickerpack stickerpack; //emotes will be outdated
  final VoidCallback triggerStickerpageUpdate;
  final VoidCallback triggerFeaturedpageUpdate;

  const StickerPackViewer(
      {super.key,
      required this.stickerpack,
      required this.triggerStickerpageUpdate,
      required this.triggerFeaturedpageUpdate});

  @override
  StickerPackViewerState createState() => StickerPackViewerState();
}

class StickerPackViewerState extends State<StickerPackViewer> {
  List<Emote> _emotes = [];
  List<GlobalKey<_ClickableEmoteTileState>> emoteKeys = [];
  ListNotifier emoteSelectionNotifier = ListNotifier();
  int trayIcon = 0;
  bool DEBUG = kDebugMode;

  void emoteSelectionChanged() {
    //passs
  }

  void updateEmotes() {}

  void onDeleteEmoteFromPack(String emoteId, BuildContext context) async {
    await DatabaseHelper()
        .deleteEmoteFromStickerpack(widget.stickerpack.name, emoteId);
    List<Emote> emotesNew = await DatabaseHelper()
        .getAllEmotesOfStickerpack(widget.stickerpack.name);
    setState(() {
      _emotes = emotesNew;
    });
    emoteSelectionNotifier.setList(List.filled(_emotes.length, false));

    if (_emotes.length - 1 <= trayIcon) {
      await onSetTrayIcon(trayIcon - 1);
    }

    widget.triggerStickerpageUpdate();
  }

  void onDeleteWholePlack() async {
    await DatabaseHelper().deleteStickerpack(widget.stickerpack.name);
    widget.triggerStickerpageUpdate();
    widget.triggerFeaturedpageUpdate();
  }

  //index is the icon index
  Future<void> onSetTrayIcon(int index) async {
    trayIcon = index;
    await DatabaseHelper().updateStickerpack(widget.stickerpack.name, trayIcon);

    for (GlobalKey<_ClickableEmoteTileState> key in emoteKeys) {
      key.currentState?.setTrayIcon(trayIcon);
    }
    widget.stickerpack.trayIcon = trayIcon;
  }

  Future<void> _deletePackDialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Do you really want to delete this stickerpack?'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Yes'),
              onPressed: () {
                onDeleteWholePlack();
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _emotes = widget.stickerpack.emotes;
    trayIcon = widget.stickerpack.trayIcon;

    emoteKeys = List.generate(
        _emotes.length, (_) => GlobalKey<_ClickableEmoteTileState>());
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
          (DEBUG)
              ? IconButton(
                  onPressed: () => widget.stickerpack.saveToJson(),
                  icon: Icon(Icons.star),
                  tooltip: "featured pack",
                )
              : Container(),
          IconButton(
            onPressed: () => _deletePackDialogBuilder(context),
            icon: Icon(CupertinoIcons.trash_circle),
            tooltip: "delete stickerpack",
          )
        ],
      )),
      body: SafeArea(
          child: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
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
                    return Text("no selected");
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
                    Row(
                      children: [
                        IconButton(
                            onPressed: () =>
                                addEmoteImageToClipboard(_emotes[i]),
                            icon: Icon(Icons.copy)),
                        IconButton(
                          onPressed: () => onSetTrayIcon(i),
                          icon: Icon(CupertinoIcons.profile_circled),
                          tooltip: "set tray icon",
                        ),
                        IconButton(
                          onPressed: () =>
                              onDeleteEmoteFromPack(_emotes[i].id, context),
                          icon: Icon(CupertinoIcons.trash),
                          tooltip: "delete emote",
                        )
                      ],
                    )
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
  _ClickableEmoteTileState createState() => _ClickableEmoteTileState();
}

class _ClickableEmoteTileState extends State<ClickableEmoteTile>
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
                    ? Image.asset(
                        'assets/sign-check.png',
                        width: 25,
                      )
                    : Container(),
                (trayIcon == widget.index)
                    ? Align(
                        alignment: Alignment.topRight,
                        child: Image.asset(
                          "assets/tray.png",
                          width: 25,
                        ),
                      )
                    : Container()
              ]),
            )),
          );
        });
  }
}
