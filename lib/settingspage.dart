import 'dart:io';

import 'package:emotes_to_stickers/database.dart';
import 'package:emotes_to_stickers/preferences.dart';
import 'package:emotes_to_stickers/util.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingsPage extends StatefulWidget {
  final Function(bool) changeTheme;
  final VoidCallback? onDatabaseImported;

  const SettingsPage(
      {super.key, required this.changeTheme, this.onDatabaseImported});

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
    if (!context.mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("Successfully deleted unused cache")));
  }

  Future<void> _showLoadingDialog(BuildContext context, String message,
      Future<void> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Please wait'),
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );

    try {
      await task();
    } finally {
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Future<bool> _showImportConfirmationDialog(BuildContext context) async {
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Override local database?'),
          content: const Text(
              'Importing will replace your current local stickerpack/emote database.\n\n'
              'Only continue if you trust the selected file and have an external backup.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            FilledButton(
              child: const Text('Import and override'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    return shouldImport ?? false;
  }

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      String? exportedPath;

      await _showLoadingDialog(context, 'Exporting local database...', () async {
        final databaseBytes = await DatabaseHelper().exportDatabaseBytes();
        final timestamp = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .replaceAll('.', '-');
        final fileName = 'emotes_database_$timestamp.db';

        exportedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Emoter database',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['db'],
          bytes: databaseBytes,
        );

        // On desktop, file_picker only chooses the destination. Mobile
        // implementations write the supplied bytes themselves.
        if (exportedPath != null && !Platform.isAndroid && !Platform.isIOS) {
          await File(exportedPath!).writeAsBytes(databaseBytes, flush: true);
        }
      });

      if (!context.mounted || exportedPath == null) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Database export saved to: $exportedPath')));
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Database export failed: $e')));
    }
  }

  Future<void> _importDatabase(BuildContext context) async {
    try {
      final pickedFile = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select an exported Emoter database file',
      );

      if (!context.mounted || pickedFile == null) {
        return;
      }

      final selectedPath = pickedFile.files.single.path;
      if (selectedPath == null || selectedPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not read selected file path.')));
        return;
      }

      final shouldImport = await _showImportConfirmationDialog(context);
      if (!context.mounted || !shouldImport) {
        return;
      }

      await _showLoadingDialog(context, 'Importing database...', () async {
        await DatabaseHelper().importDatabaseFromFile(selectedPath);
      });

      widget.onDatabaseImported?.call();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Database import completed successfully.')));
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Database import failed: $e')));
    }
  }

  Future<void> _showDatabaseImportExportDialog(BuildContext parentContext) {
    return showDialog<void>(
      context: parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import/export database file'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Export creates a backup file of all your local stickerpack/emote database data.'),
                const SizedBox(height: 10),
                const Text(
                    'Import replaces your current local database data with the selected file.'),
                const SizedBox(height: 10),
                const Text('Wrong or corrupt files can fail during import.'),
                const SizedBox(height: 10),
                const Text(
                    'Keep an external backup before importing so you can recover if needed.'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Export database'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _exportDatabase(parentContext);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.arrow_downward),
                    label: const Text('Import database'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _importDatabase(parentContext);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                  title: "Import/export database file",
                  subtitle: Text(
                      "Backup your local DB or replace it from an external file"),
                  icon: Icons.import_export,
                  onPressed: () => _showDatabaseImportExportDialog(context)),
              CustomButton(
                  title: "Join the Emoter Discord!",
                  subtitle: Text("please?"),
                  icon: Icons.discord,
                  onPressed: () =>
                      launchUrlString("https://discord.gg/6Wp347G6Na")),
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
                                Text("Thank you for over 1k downloads!\n"),
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
                  subtitle: Text(
                      "use this if exporting packs gives weird error messages"),
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
      {super.key,
      required this.title,
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
