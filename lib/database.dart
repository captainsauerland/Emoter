import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:emotes_to_stickers/emote.dart';
import 'package:emotes_to_stickers/stickerpack.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  static const String _databaseName = 'emotes_database.db';
  static const List<String> _sqliteSidecarSuffixes = [
    '-wal',
    '-shm',
    '-journal'
  ];
  static const Set<String> _requiredTables = {
    'stickerpacks',
    'cashed_emotes',
    'stickerpack_emotes'
  };

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<String> getDatabaseFilePath() async {
    return join(await getDatabasesPath(), _databaseName);
  }

  Future<String> _getPreImportBackupPath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return join(
        documentsDirectory.path, 'emotes_database_pre_import_backup.db');
  }

  Future<void> _closeDatabaseConnection() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> _reopenDatabaseConnection() async {
    _database = await _initDatabase();
  }

  Future<void> _deleteFileIfExists(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _deleteDatabaseWithSidecars(String databasePath) async {
    await _deleteFileIfExists(databasePath);
    for (final sidecarSuffix in _sqliteSidecarSuffixes) {
      await _deleteFileIfExists('$databasePath$sidecarSuffix');
    }
  }

  Future<void> _copyDatabaseWithSidecars(
      String sourceDatabasePath, String destinationDatabasePath) async {
    final sourceFile = File(sourceDatabasePath);

    if (!await sourceFile.exists()) {
      throw Exception('Database file not found: $sourceDatabasePath');
    }

    await Directory(dirname(destinationDatabasePath)).create(recursive: true);
    await _deleteDatabaseWithSidecars(destinationDatabasePath);
    await sourceFile.copy(destinationDatabasePath);

    for (final sidecarSuffix in _sqliteSidecarSuffixes) {
      final sourceSidecar = File('$sourceDatabasePath$sidecarSuffix');
      if (await sourceSidecar.exists()) {
        await sourceSidecar.copy('$destinationDatabasePath$sidecarSuffix');
      }
    }
  }

  Future<void> _validateDatabaseSchema(String databasePath) async {
    final validationDb = await openDatabase(databasePath, readOnly: true);
    try {
      final tables = await validationDb
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tableNames =
          tables.map((row) => row['name']?.toString() ?? '').toSet();

      for (final table in _requiredTables) {
        if (!tableNames.contains(table)) {
          throw Exception(
              'Imported database is missing required table "$table".');
        }
      }
    } finally {
      await validationDb.close();
    }
  }

  Future<Uint8List> exportDatabaseBytes() async {
    await database;
    final databasePath = await getDatabaseFilePath();

    await _closeDatabaseConnection();
    try {
      final sourceDatabase = File(databasePath);
      if (!await sourceDatabase.exists()) {
        throw Exception('Local database file could not be found.');
      }

      return await sourceDatabase.readAsBytes();
    } finally {
      await _reopenDatabaseConnection();
    }
  }

  Future<void> importDatabaseFromFile(String selectedDatabasePath) async {
    final selectedDatabase = File(selectedDatabasePath);
    if (!await selectedDatabase.exists()) {
      throw Exception('Selected file could not be found.');
    }

    await database;

    final databasePath = await getDatabaseFilePath();
    final backupPath = await _getPreImportBackupPath();

    if (selectedDatabase.absolute.path == File(databasePath).absolute.path) {
      throw Exception('Selected file is already the active database file.');
    }

    await _closeDatabaseConnection();

    bool backupCreated = false;
    try {
      await _copyDatabaseWithSidecars(databasePath, backupPath);
      backupCreated = true;

      await _deleteDatabaseWithSidecars(databasePath);
      await selectedDatabase.copy(databasePath);

      for (final sidecarSuffix in _sqliteSidecarSuffixes) {
        final sourceSidecar = File('$selectedDatabasePath$sidecarSuffix');
        if (await sourceSidecar.exists()) {
          await sourceSidecar.copy('$databasePath$sidecarSuffix');
        }
      }

      await _validateDatabaseSchema(databasePath);
    } catch (_) {
      if (backupCreated) {
        await _deleteDatabaseWithSidecars(databasePath);
        await _copyDatabaseWithSidecars(backupPath, databasePath);
      }
      rethrow;
    } finally {
      await _reopenDatabaseConnection();
    }
  }

  Future<Database> _initDatabase() async {
    String path = await getDatabaseFilePath();
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE stickerpacks (
        id TEXT NOT NULL PRIMARY KEY,
        tray_icon   INTEGER DEFAULT 0,
        version   INTEGER DEFAULT 1
      );
    ''');
    await db.execute('''
      CREATE TABLE cashed_emotes (
      id             TEXT NOT NULL
                        PRIMARY KEY,
      name           REAL,
      owner_username TEXT,
      host_url       TEXT,
      stickerpack    TEXT,
      time_at_cash   TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE stickerpack_emotes (
      stickerpack_id TEXT,
      emote_id TEXT,
      PRIMARY KEY (stickerpack_id, emote_id),
      FOREIGN KEY (stickerpack_id) REFERENCES stickerpacks(id),
      FOREIGN KEY (emote_id) REFERENCES cashed_emotes(id)
    );
    ''');
  }

  Emote mapToEmote(Map<String, dynamic> map) {
    return Emote(
        id: map['id'],
        name: map['name'].toString(),
        ownerUsername: map['owner_username'].toString(),
        hostUrl: map['host_url'],
        stickerpack: map['stickerpack'].toString(),
        timeAtCash: map['time_at_cash']
        //image: map['image']
        );
  }

  //Gets the temporary emote. If it doesnt exist, a new emote gets returned
  Future<Emote> saveOrGetEmote(Emote emote) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cashed_emotes',
      where: 'id = ?',
      whereArgs: [emote.id],
    );
    if (maps.isEmpty) {
      await saveEmote(emote);
      return emote;
    } else {
      return mapToEmote(maps.first);
    }
  }

  Future<int> saveEmote(Emote emote) async {
    Database db = await database;
    return await db.insert('cashed_emotes', emote.toJson());
  }

  Future<int> updateEmote(Emote emote) async {
    Database db = await database;
    return await db.update('cashed_emotes', emote.toJson(),
        where: 'id = ?', whereArgs: [emote.id]);
  }

  Future<int> addStickerpack(String name) async {
    Database db = await database;
    if (await doesPackExist(name)) {
      return -1;
    }
    return await db.insert('stickerpacks', {'id': name, 'tray_icon': 0});
  }

  Future<bool> doesPackExist(String name) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('stickerpacks', where: "id = ?", whereArgs: [name]);
    return maps.isNotEmpty;
  }

  Future<int> addEmoteToStickerpack(
      String stickerpackId, String emoteId) async {
    Database db = await database;
    return await db.rawInsert('''
      INSERT OR REPLACE INTO stickerpack_emotes (stickerpack_id, emote_id) 
      VALUES (?, ?);
    ''', [stickerpackId, emoteId]);
  }

  Future<int> deleteEmoteFromStickerpack(
      String stickerpackId, String emoteId) async {
    Database db = await database;
    return await db.rawDelete('''
      DELETE FROM stickerpack_emotes 
      WHERE stickerpack_id = ? AND emote_id = ?;
    ''', [stickerpackId, emoteId]);
  }

  Future<int> changeStickerpackVersion(String id, int version) async {
    Database db = await database;
    return await db.rawUpdate('''
      UPDATE stickerpacks
      SET version = ?
      WHERE id = ?
    ''', [version, id]);
  }

  Future<List<Emote>> getAllEmotesOfStickerpack(String stickerpackId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM stickerpack_emotes NATURAL JOIN cashed_emotes
      WHERE emote_id is id and stickerpack_id is ?
    ''', [stickerpackId]);
    List<Emote> result = [];
    for (Map<String, dynamic> map in maps) {
      result.add(mapToEmote(map));
    }
    return result;
  }

  Future<List<Stickerpack>> getAllStickerpacks() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('stickerpacks');
    List<Stickerpack> result = [];
    for (Map<String, dynamic> map in maps) {
      result.add(Stickerpack(
          name: map['id'],
          emotes: await getAllEmotesOfStickerpack(map['id']),
          trayIcon: map['tray_icon'],
          version: map['version']));
    }
    return result;
  }

  Future<Stickerpack> getStickerpack(String id) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('stickerpacks', where: 'id = "$id"');
    return Stickerpack(
        name: maps[0]['id'],
        emotes: await getAllEmotesOfStickerpack(maps[0]['id']),
        trayIcon: maps[0]['tray_icon'],
        version: maps[0]['version']);
  }

  Future<int> updateStickerpack(String id, int trayIcon) async {
    Database db = await database;
    return await db.rawInsert('''
      INSERT OR REPLACE INTO stickerpacks (id, tray_icon) 
      VALUES (? ,?);
    ''', [id, trayIcon]);
  }

  Future<int> deleteStickerpack(String id) async {
    Database db = await database;
    await db.rawDelete('''
      DELETE FROM stickerpack_emotes 
      WHERE stickerpack_id = ?;
    ''', [id]);
    return await db.rawDelete('''
      DELETE FROM stickerpacks
      WHERE id = ?
    ''', [id]);
  }

  //unused
  Future<int> insertEmote(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('cashed_emotes', row);
  }

  //unused
  Future<List<Map<String, dynamic>>> queryAllEmotes() async {
    Database db = await database;
    return await db.query('cashed_emotes');
  }

  //useless
  Future<int> deleteEmote(int id) async {
    Database db = await database;
    return await db.delete('cashed_emotes', where: 'id = ?', whereArgs: [id]);
  }
}
