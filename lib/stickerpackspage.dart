import 'package:emotes_to_stickers/errorwindow.dart';
import 'package:emotes_to_stickers/loadingwindow.dart';
import 'package:emotes_to_stickers/send_to_wa.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:emotes_to_stickers/stickerpack.dart';
import 'package:emotes_to_stickers/stickerpackviewer.dart';
import 'package:flutter/services.dart';
import 'package:emotes_to_stickers/imagerow.dart';

import 'database.dart';

class StickerpackPage extends StatefulWidget {
  final VoidCallback triggerSearchpageUpdate;
  final VoidCallback triggerFeaturedpageUpdate;

  StickerpackPage(
      {Key? key,
      required this.triggerSearchpageUpdate,
      required this.triggerFeaturedpageUpdate})
      : super(key: key);

  @override
  StickerpackPageState createState() => StickerpackPageState();
}

class StickerpackPageState extends State<StickerpackPage> {
  final TextEditingController _textFieldController = TextEditingController();

  List<Stickerpack> stickerPacks = [];
  ListNotifier packsSelectionNotifier = ListNotifier();

  static Stickerpack? currentStickerpack;

  bool startup = true;

  GlobalKey<LoadingDialogState> loadingDialogKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    updateStickerpackList();
  }

  updateStickerpackList() async {
    List<Stickerpack> stickerPacksNew =
        await DatabaseHelper().getAllStickerpacks();

    if (stickerPacksNew.isNotEmpty) {
      if (startup) {
        currentStickerpack = stickerPacksNew.first;
        startup = false;
      }

      setState(() {
        stickerPacks = stickerPacksNew;
      });

      //selected should stay selected
      int trueIndex = 0;
      for (int i = 0; i < packsSelectionNotifier.listItems.length; i++) {
        if (packsSelectionNotifier.getFromIndex(i)) {
          trueIndex = i;
          break;
        }
      }

      if (trueIndex >= stickerPacks.length) {
        trueIndex = stickerPacks.length - 1;
      }

      packsSelectionNotifier
          .setList(List.filled(stickerPacksNew.length, false));
      packsSelectionNotifier.listItems[trueIndex] = true;

      //old set state

      currentStickerpack = stickerPacks[trueIndex]; //currentStickerpack is old
    } else {
      setState(() {
        stickerPacks = stickerPacksNew;
      });
    }
  }

  addStickerpack(String name, BuildContext context) async {
    if (await DatabaseHelper().doesPackExist(name)) {
      (context.mounted)
          ? showDialog(
              context: context,
              builder: (BuildContext context) {
                return CustomDialog(message: "name must be unique");
              })
          : Container();
      return;
    }
    await DatabaseHelper().addStickerpack(name);
    await updateStickerpackList();
    currentStickerpack = stickerPacks.last;
    widget.triggerSearchpageUpdate();
  }

  addCurrentPackToWhatsApp(BuildContext context) async {
    int emotesCount = currentStickerpack!.emotes.length;
    if (emotesCount < 3) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return CustomDialog(
                message:
                    "${currentStickerpack!.name} has only $emotesCount emotes, it needs at least 3");
          });
    } else if (emotesCount > 30) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return CustomDialog(
                message:
                    "${currentStickerpack!.name} has $emotesCount emotes, it must not have more than 30");
          });
    } else {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return LoadingDialog(key: loadingDialogKey);
          });

      sendStickerPackToWhatsApp(
          currentStickerpack!, onProgess, onAddToWhatsAppDone);
    }
  }

  onProgess(double newProgress) {
    if (newProgress == 1) {
      loadingDialogKey.currentState?.closeDialog();
    }
    loadingDialogKey.currentState?.setValue(newProgress);
  }

  onAddToWhatsAppDone(String returnValue) async {
    if (returnValue.isNotEmpty) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            if (returnValue.startsWith("already_added")) {
              return CustomDialog(
                message: "Successfully updated pack",
              );
            }
            return CustomDialog(message: returnValue);
          });
    } else {
      int newVersion = currentStickerpack!.version + 1;
      await DatabaseHelper()
          .changeStickerpackVersion(currentStickerpack!.name, newVersion);
      updateStickerpackList();
    }
  }

  Future<void> _createStickerpackDialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create new Stickerpack'),
          content: TextField(
            maxLength: 64,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            controller: _textFieldController,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(
                  RegExp("^[a-zA-Z0-9_\\-\\. ]+\$"))
            ],
            decoration: InputDecoration(hintText: "Name"),
          ),
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
              child: const Text('Create'),
              onPressed: () {
                addStickerpack(_textFieldController.text, context);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomScrollView(slivers: <Widget>[
          SliverToBoxAdapter(
              child: Container(
                  alignment: Alignment.center,
                  height: 200,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 30,
                    ),
                  ))),
          (stickerPacks.isEmpty)
              ? SliverToBoxAdapter(
                  child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text('where stickerpacks'),
                      Container(
                        height: 20,
                      ),
                      Image.asset(
                        'assets/where.webp',
                        width: 160,
                      )
                    ],
                  ),
                ))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                  final pack = stickerPacks[index];
                  return Card(
                    child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return StickerPackViewer(
                                stickerpack: pack,
                                triggerStickerpageUpdate: updateStickerpackList,
                                triggerFeaturedpageUpdate:
                                    widget.triggerFeaturedpageUpdate,
                              );
                            }),
                        child: ListTile(
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    pack.name,
                                    style: TextStyles.bold,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                  ),
                                ),
                                Text("  ${pack.emotes.length}/30",
                                    style: (pack.emotes.length > 30)
                                        ? TextStyle(color: Colors.red)
                                        : TextStyle()),
                              ],
                            ),
                            //Text('${pack.emotes.length} emotes'),
                            subtitle: FutureBuilder(
                                future: Future.value(
                                    stickerPacks[index].emotes), //temporary
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                        child: CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    return Center(
                                        child:
                                            Text('Error: ${snapshot.error}'));
                                  } else {
                                    return ImageRow(
                                        emotes: snapshot.requireData);
                                  }
                                }),
                            leading: ListenableBuilder(
                                listenable: packsSelectionNotifier,
                                builder: (BuildContext context, Widget? child) {
                                  return Transform.scale(
                                      scale: 1.3,
                                      child: IconButton(
                                        icon: (packsSelectionNotifier
                                                .getFromIndex(index))
                                            ? Icon(
                                                Icons.radio_button_on,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              )
                                            : Icon(
                                                Icons.radio_button_off,
                                              ),
                                        onPressed: () => {
                                          packsSelectionNotifier
                                              .setAllFalseAndTrueAtIndexIfTrue(
                                                  index, true),
                                          currentStickerpack =
                                              stickerPacks[index],
                                          widget.triggerSearchpageUpdate()
                                        }, // }
                                      ));
                                }))),
                  );
                }, childCount: stickerPacks.length)),
          SliverToBoxAdapter(
            child: Container(
              height: 90,
              alignment: Alignment.center,
              child: Image.asset(
                'assets/ppl.webp',
                width: 40,
                opacity: const AlwaysStoppedAnimation(.5),
              ),
            ),
          )
        ]),
        Align(
            alignment: Alignment.bottomRight,
            child: Padding(
                padding: EdgeInsets.all(22.0),
                child: FloatingActionButton(
                  onPressed: () => _createStickerpackDialogBuilder(context),
                  tooltip: 'Add pack',
                  child: const Icon(Icons.add),
                ))),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: (currentStickerpack == null)
                ? Container()
                : ElevatedButton(
                    onPressed: () => {addCurrentPackToWhatsApp(context)},
                    child: const Text('Send to WhatsApp'),
                  ),
          ),
        )
      ],
    );
  }
}
