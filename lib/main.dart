import 'dart:async';

import 'package:emotes_to_stickers/featuredpage.dart';
import 'package:emotes_to_stickers/searchpage.dart';
import 'package:emotes_to_stickers/settingspage.dart';
import 'package:emotes_to_stickers/stickerpackspage.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:emotes_to_stickers/preferences.dart';

StreamController<bool> isLightTheme = StreamController();
String initialBrightness = "";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initialBrightness = await readThemeBrightness();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    bool initialValue =
      (MediaQuery.platformBrightnessOf(context) == Brightness.light);

    if (initialBrightness == 'dark'){
      initialValue = false;
    }else if (initialBrightness == 'light'){
      initialValue = true;
    }

    return StreamBuilder(
        initialData: initialValue,
        stream: isLightTheme.stream,
        builder: (context, snapshot) {
          if (kDebugMode) print("brightness? ${snapshot.requireData}");

          final ColorScheme colorScheme = ColorScheme.fromSeed(
              brightness: (snapshot.requireData) ? Brightness.light : Brightness.dark,
              seedColor: Color(0xFF2B2D42),
              primary: (snapshot.requireData) ?
                  Color(0xFF5A8D3E) :
                  Color(0xFF53DD6C),
              // Color(0xFF5AFF15)
              // Color(0xFF63EA15),
              contrastLevel: 0.8);

          return MaterialApp(
            title: 'Emoter',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: colorScheme,
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  // side: BorderSide(
                  //     color: colorScheme.secondary,
                  //     width: 2), // Outline color and width
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 5,
                  shadowColor: Colors.black
                ),
              ),
            ),
            home: const MyHomePage(),
          );
        });
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static final GlobalKey<SearchPageState> _searchPageKey =
      GlobalKey<SearchPageState>();
  static final GlobalKey<StickerpackPageState> _stickerpackPageKey =
      GlobalKey<StickerpackPageState>();
  static final GlobalKey<FeaturedPageState> _featuredPageKey =
    GlobalKey<FeaturedPageState>();
  static final GlobalKey<SettingsPageState> _settingsPageStateKey =
      GlobalKey<SettingsPageState>();

  // hier werden grade die unterschiedlichen Widgets aufgelistet
  final List<Widget> _widgetOptions = <Widget>[];

  @override
  void initState() {
    super.initState();

    // hier werden grade die unterschiedlichen Widgets aufgelistet
    _widgetOptions.addAll([
      StickerpackPage(
          key: _stickerpackPageKey,
          triggerSearchpageUpdate:
              triggerSearchPageUpdate,
          triggerFeaturedpageUpdate:
              triggerFeaturedPageUpdate,
      ), //key: _stickerpackPageKey,
      SearchPage(
          key: _searchPageKey,
          triggerStickerpageUpdate: triggerStickerPageUpdate),
      FeaturedPage(key: _featuredPageKey, triggerStickerpageUpdate: triggerStickerPageUpdate),
      SettingsPage(key: _settingsPageStateKey, changeTheme: changeTheme,)
    ]);
  }

  //hmm
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 3) {
        _settingsPageStateKey.currentState!.updateSettings();
      }
    });
  }

  //nervig dass das alles static sein muss aber geht nicht anders
  void triggerStickerPageUpdate() {
    _stickerpackPageKey.currentState?.updateStickerpackList();
  }

  void triggerSearchPageUpdate() {
    _searchPageKey.currentState?.updateSearchPage();
  }

  void triggerFeaturedPageUpdate() {
    _featuredPageKey.currentState?.updateCurrentPage();
  }

  void changeTheme(bool isLight){
    isLightTheme.add(isLight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.surface.withAlpha(150),
                spreadRadius: 4,
                blurRadius: 5,
                offset: Offset(0, 3),
              )
            ]
          ),
          alignment: Alignment.bottomLeft,
          child:
            SafeArea(child: Padding(
              padding: EdgeInsets.all(15),
              child: MyAppBarTitle(),
            ),
          )
        ),
      ),
      body: Center(
        child: IndexedStack(
          index: _selectedIndex,
          children: _widgetOptions,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            label: 'Featured',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
