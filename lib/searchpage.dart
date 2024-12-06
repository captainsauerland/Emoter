import 'dart:typed_data';

import 'package:emotes_to_stickers/database.dart';
import 'package:emotes_to_stickers/emote.dart';
import 'package:emotes_to_stickers/errorwindow.dart';
import 'package:emotes_to_stickers/stickerpackspage.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:flutter/material.dart';
import 'package:emotes_to_stickers/api_requester.dart';

class SearchPage extends StatefulWidget {
  final VoidCallback triggerStickerpageUpdate;

  const SearchPage({Key? key, required this.triggerStickerpageUpdate}) : super(key: key);

  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  List<Emote> _emotes = [];
  List<GlobalKey<_ClickableEmoteTileState>> emoteKeys = []; //kommunikation mit den tiles
  ValueNotifier<int> numberOfEmotesSelected = ValueNotifier(0);
  String currentPackName = "";
  bool showBackground = true;
  int pages = 1;
  String currentTerm = "";

  updateSearchPage(){
    numberOfEmotesSelected.value++;
    numberOfEmotesSelected.value--;
  }

  //if a tile gets clicked, it calls this method
  void changedClickStatus(bool newStatus, int index) {
    int numberOfEmotesSelectedTemp = 0;
    for (GlobalKey<_ClickableEmoteTileState> emoteKey in emoteKeys) {
      if (emoteKey.currentState != null && emoteKey.currentState!._isClicked) {
        numberOfEmotesSelectedTemp++;
      }
    }

    numberOfEmotesSelected.value = numberOfEmotesSelectedTemp;
  }

  void _searchSubmitted(String search, BuildContext context) async {
    pages = 1;
    currentTerm = search;

    setState(() {
      showBackground = false;
    });
    var seventv = SevenTv();

    try {
      var emotes = await seventv.emoteSearch(
        searchTerm: search,
        limit: 15,
        page: 1,
        caseSensitive: false,
        animated: false,
        exactMatch: false,
        query: "all",
      );

      setState(() {
        emoteKeys = List.generate(emotes.length,
                (_) => GlobalKey<_ClickableEmoteTileState>()); //neue keys
        _emotes = emotes;
        if (_emotes.isEmpty){
          _emotes.add(Emote(id: "", name: "")); //empty emote to signal, that the search is done
        }
      });
    }catch (e){
      String message;
      if (e.toString().startsWith("SocketException")){
        message = "Couldn't connect to 7tv servers. Check you internet connection!";
      }else{
        message = e.toString();
      }
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return CustomDialog(
                message: "Search failed: $message"
            );
          }
      );
    }
  }

  //viel duplicate code
  void _moreClicked() async{
    var seventv = SevenTv();

    pages++;

    try {
      var emotes = await seventv.emoteSearch(
        searchTerm: currentTerm,
        limit: 15,
        page: pages,
        caseSensitive: false,
        animated: false,
        exactMatch: false,
        query: "all",
      );

      setState(() {
        emoteKeys.addAll(List.generate(emotes.length,
                (_) => GlobalKey<_ClickableEmoteTileState>())); //neue keys
        _emotes.addAll(emotes);
      });
    }catch (e){
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return CustomDialog(
                message: "Search failed $e"
            );
          }
      );
    }
  }

  //hier müssen alle emotes die selected sind
  Future<void> addToPack() async {
    for (GlobalKey<_ClickableEmoteTileState> emoteKey in emoteKeys) {
      if (emoteKey.currentState != null && emoteKey.currentState!._isClicked) {
        await DatabaseHelper().addEmoteToStickerpack(
            StickerpackPageState.currentStickerpack!.name,
            emoteKey.currentState!.widget.id);
        emoteKey.currentState?._isClicked = false;
      }
    }
    setState(() {
      numberOfEmotesSelected.value = 0;
    });
    widget.triggerStickerpageUpdate();
  }

  //extrem hacky, aber veranlasst den Knopf neu zu laden
  void currentStickerPackHasChanged() {
    numberOfEmotesSelected.value++;
    numberOfEmotesSelected.value--;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Stack(
        children: [
          (showBackground) ? Column(
            children: [
              Container(height: 170,),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 60.0),
                child: Text(
                  textAlign: TextAlign.center,
                    "Tip: Do an empty search to search for most popular"
                ),
              ),
              Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Image.asset('assets/peepohmm.webp', width: 100,),
              ),
            ],
          ) : Container(),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar(
                      clipBehavior: Clip.none,
                      shape: const StadiumBorder(),
                      scrolledUnderElevation: 0.0,
                      titleSpacing: 0.0,
                      backgroundColor: Colors.transparent,
                      floating: true,
                      title:
                      Column(
                          children: [
                            Container(height: 25),
                            Padding(
                                padding: EdgeInsets.all(25),
                                child: SearchBar(
                                    hintText: 'Search 7tv',
                                    leading: const Icon(Icons.search),
                                    onSubmitted: (String search) => _searchSubmitted(search, context)))
                          ]
                      )
                  ),

                  SliverToBoxAdapter(
                    child: Container(
                      height: 50,
                    ),
                  ),

                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 140.0,
                      mainAxisSpacing: 12.0,
                      crossAxisSpacing: 12.0,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                        return (_emotes.length <= 1 && _emotes.first.id == "") ?
                        Text("No emotes found. Try searching for something else") :
                        FutureBuilder(
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
                                  changedClickedStatus: changedClickStatus);
                            }
                          },
                        );
                      },
                      childCount: _emotes.length,
                    ),
                  ),
                  SliverToBoxAdapter(
                      child: (showBackground) ?
                      Container() :
                      Column(
                        children: [
                          Container(height: 20,),
                          TextButton(
                              onPressed: _moreClicked,
                              child: Text("more")
                          ),
                          Container(height: 70,)
                        ],
                      )
                  )
                ],
              ),
          ),
          Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<int>(
                  valueListenable: numberOfEmotesSelected,
                  builder: (context, value, child) {
                    if (value > 0) {
                      if (StickerpackPageState.currentStickerpack == null){
                        return ElevatedButton(
                            onPressed: () => (),
                            child: Text("please add a stickerpack to add emotes"));
                      }else{
                        return
                          Padding(
                              padding: EdgeInsets.all(10),
                              child: ElevatedButton(
                                  onPressed: addToPack,
                                  child: Text(
                                      'Add to $value stickers current pack "${StickerpackPageState.currentStickerpack!.name}"'))
                          );
                      }
                    } else {
                      return Container();
                    }
                  }))
        ],
      )),
    );
  }
}

class ClickableEmoteTile extends StatefulWidget {
  final int index;
  final Uint8List image;
  final String id;
  final String name;
  final String username;
  final Function(bool, int) changedClickedStatus;

  const ClickableEmoteTile(
      {super.key,
      required this.index,
      required this.image,
      required this.id,
      required this.name,
      required this.username,
      required this.changedClickedStatus});

  @override
  _ClickableEmoteTileState createState() => _ClickableEmoteTileState();
}

class _ClickableEmoteTileState extends State<ClickableEmoteTile>
    with AutomaticKeepAliveClientMixin {
  bool _isClicked = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onLongPress: () {
        setState(() {
          _isClicked = !_isClicked;
          widget.changedClickedStatus(_isClicked, widget.index);
        });
      },
      child: GridTile(
          child: Container(
        decoration: BoxDecoration(
          color: _isClicked ? colorScheme.tertiary.withAlpha(70): Colors.transparent,
          border: Border.all(color: (_isClicked) ? Colors.transparent : colorScheme.tertiary.withAlpha(50), width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.memory(widget.image, height: 60,), //TODO: temp solution
            Text(widget.name,
              style: TextStyles.bold,
              softWrap: true,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,),
            Text(
                widget.username,
                softWrap: true,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.light), //renderflex overflow
          ],
        ),
      )),
    );
  }
}
