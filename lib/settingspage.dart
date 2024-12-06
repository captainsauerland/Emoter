import 'dart:io';

import 'package:emotes_to_stickers/preferences.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingsPage extends StatefulWidget {
  final Function(bool) changeTheme;

  const SettingsPage({super.key, required this.changeTheme});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  void updateSettings() {
    setState(() {});
  }

  void deleteStickerpacksJSON() async {
    var directory = await getApplicationDocumentsDirectory();
    final file = File("${directory.path}/sticker_packs.json");
    if (kDebugMode) print("${directory.path}/sticker_packs.json");
    if (await file.exists()) {
      file.delete();
    } else {
      if (kDebugMode) print("couldt find stickerpacks json");
    }
  }

  Future<void> onCleanCache(BuildContext context) async {
    await cleanCache();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("Successfully deleted unused cache")));
  }

  onReallyCleanCache(BuildContext context) async {
    await cleanCache(cleanAll: true);
    setState(() {});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("Successfully deleted all unused cache")));
    }
  }

  Future<void> _deleteAllCacheDialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete the whole cache'),
          content: Text(
              "Do you want to delete ALL cached emotes including converted ones"),
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
                onReallyCleanCache(context);
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 22.0),
      child: Column(
        children: [
          Container(
            height: 40,
          ),
          Image.asset(
            'assets/coggers.webp',
            height: 80,
          ),
          Container(
            height: 20,
          ),
          Text("settings", style: TextStyles.big),
          Expanded(
              child: ListView(
            children: <Widget>[
              Container(height: 50),
              (Theme.of(context).brightness == Brightness.light)
                  ? CustomButton(
                      title: "Switch to dark mode",
                      subtitle: Text("Highly recommended"),
                      icon: Icons.nights_stay,
                      onPressed: () => {
                            widget.changeTheme(false),
                            saveThemeBrightness(false)
                          })
                  : CustomButton(
                      title: "Switch to light mode",
                      subtitle: Text("Why would you do that?"),
                      icon: Icons.sunny,
                      onPressed: () => {
                            widget.changeTheme(true),
                            saveThemeBrightness(true)
                          }),
              CustomButton(
                  title: "Clean cache",
                  subtitle: FutureBuilder(
                      future: calculateCacheSize(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text("loading...");
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else {
                          double cacheSize = snapshot.data! / 1000000;
                          return Text("Delete cached images to free up space. "
                              "Current cache size is ${cacheSize.toStringAsFixed(2)} MB");
                        }
                      }),
                  icon: Icons.storage,
                  onLongPressed: () => _deleteAllCacheDialogBuilder(context),
                  onPressed: () => onCleanCache(context)),
              CustomButton(
                title: "Credits",
                subtitle: Text("<3"),
                icon: Icons.people,
                onPressed: () => showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                          title: Text("Credits"),
                          content: IntrinsicHeight(
                            child: Column(
                              children: [
                                Text(
                                    textAlign: TextAlign.center,
                                    "Without these libraries, this project wouldn't have been possible:"),
                                TextButton(
                                  onPressed: () => launchUrlString(
                                      "https://github.com/star-39/whatsapp_stickers_exporter"),
                                  child: Text(
                                      textAlign: TextAlign.center,
                                      "Star-39: whatsapp_stickers_exporter"),
                                ),
                                TextButton(
                                  onPressed: () => launchUrlString(
                                      "https://github.com/UdaraWanasinghe/webp-android"),
                                  child: Text(
                                      textAlign: TextAlign.center,
                                      "UdaraWanasinghe: webp-android"),
                                ),
                                Text(
                                    textAlign: TextAlign.center,
                                    "\n\nThis app was made by Captain Sauerland:"),
                                TextButton(
                                  onPressed: () => launchUrlString(
                                      "https://www.youtube.com/@captainsauerland"),
                                  child: Text("Visit my German Yt Channel"),
                                ),
                              ],
                            ),
                          ));
                    }),
              ),
              CustomButton(
                  title: "Reset stickerpacks.json",
                  subtitle: Text("iykyk"),
                  icon: Icons.bug_report,
                  onPressed: deleteStickerpacksJSON),
              Container(
                height: 20,
              ),
              Align(
                alignment: Alignment.center,
                child: FutureBuilder(
                  future: PackageInfo.fromPlatform(),
                  // Your async function
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text("loading");
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else {
                      return Text(snapshot.requireData.version);
                    }
                  },
                ),
              ),
              Container(
                height: 20,
              ),
            ],
          )),
        ],
      ),
    );
  }
}

//returned ein sliver
class CustomButton extends StatelessWidget {
  final String title;
  final Widget subtitle;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPressed;

  const CustomButton(
      {super.key, required this.title,
      required this.subtitle,
      required this.icon,
      required this.onPressed,
      this.onLongPressed});

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 5,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          onLongPress: onLongPressed,
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: subtitle,
            trailing: Icon(Icons.arrow_forward),
          ),
        ));
  }
}
