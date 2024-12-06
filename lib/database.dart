import 'dart:async';
import 'package:emotes_to_stickers/emote.dart';
import 'package:emotes_to_stickers/stickerpack.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'emotes_database.db');
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
        name: map['name'],
        ownerUsername: map['owner_username'],
        hostUrl: map['host_url'],
        stickerpack: map['stickerpack'],
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
