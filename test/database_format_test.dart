library sembast.database_format_test;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_codec_impl.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

Map mapWithoutCodec(Map map) {
  return Map.from(map)..remove('codec');
}

void defineTests(FileSystemTestContext ctx, {SembastCodec codec}) {
  FileSystem fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  String getDbPath() => ctx.outPath + ".db";
  String dbPath;

  Future<String> prepareForDb() async {
    dbPath = getDbPath();
    await factory.deleteDatabase(dbPath);
    return dbPath;
  }

  group('basic format', () {
    setUp(() {
      //return fs.newFile(dbPath).delete().catchError((_) {});
    });

    tearDown(() {});

    test('open_no_version', () async {
      await prepareForDb();
      await factory.openDatabase(dbPath, codec: codec);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 1);
      var expected = <String, dynamic>{"version": 1, "sembast": 1};
      if (codec != null) {
        expected['codec'] = getCodecEncodedSignature(codec);
      }
      expect(json.decode(lines.first), expected);
    });

    test('open_version_2', () async {
      await prepareForDb();
      await factory.openDatabase(dbPath, version: 2, codec: codec);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 1);
      var expected = <String, dynamic>{"version": 2, "sembast": 1};
      if (codec != null) {
        expected['codec'] = getCodecEncodedSignature(codec);
      }
      expect(json.decode(lines.first), expected);
    });

    dynamic decodeRecord(String line) {
      if (codec != null) {
        return codec.codec.decode(line);
      } else {
        return json.decode(line);
      }
    }

    test('1 string record', () async {
      await prepareForDb();
      return factory.openDatabase(dbPath, codec: codec).then((Database db) {
        return db.put("hi", 1);
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 2);
          expect(decodeRecord(lines[1]), {'key': 1, 'value': 'hi'});
        });
      });
    });

    test('1_record_in_2_stores', () async {
      await prepareForDb();
      Database db = await factory.openDatabase(dbPath, codec: codec);
      db.getStore('store1');
      Store store2 = db.getStore('store2');
      await store2.put("hi", 1);
      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 2);
      expect(
          decodeRecord(lines[1]), {'store': 'store2', 'key': 1, 'value': 'hi'});
      await db.close();
    });

    test('twice same record', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath, codec: codec);
      await db.put("hi", 1);
      await db.put("hi", 1);
      var lines = await readContent(fs, dbPath);
      expect(lines.length, 3);
      expect(decodeRecord(lines[1]), {'key': 1, 'value': 'hi'});
      expect(decodeRecord(lines[2]), {'key': 1, 'value': 'hi'});
      await db.close();
    });

    test('1 map record', () async {
      await prepareForDb();
      return factory.openDatabase(dbPath).then((Database db) {
        return db.put({'test': 2}, 1);
      }).then((_) {
        return readContent(fs, dbPath).then((List<String> lines) {
          expect(lines.length, 2);
          expect(json.decode(lines[1]), {
            'key': 1,
            'value': {'test': 2}
          });
        });
      });
    });

    test('1_record_in_open', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath, version: 2,
          onVersionChanged: (db, _, __) async {
        await db.put('hi', 1);
      }, codec: codec);
      try {
        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        var expected = <String, dynamic>{"version": 2, "sembast": 1};
        if (codec != null) {
          expected['codec'] = getCodecEncodedSignature(codec);
        }
        expect(json.decode(lines.first), expected);
        expect(decodeRecord(lines[1]), {'key': 1, 'value': 'hi'});
      } finally {
        await db?.close();
      }
    });

    test('1_record_in_open_transaction', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath, version: 2,
          onVersionChanged: (db, _, __) async {
        await db.transaction((txn) async {
          await txn.put('hi', 1);
        });
      }, codec: codec);
      try {
        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        var expected = <String, dynamic>{"version": 2, "sembast": 1};
        if (codec != null) {
          expected['codec'] = getCodecEncodedSignature(codec);
        }
        expect(json.decode(lines.first), expected);
        expect(decodeRecord(lines[1]), {'key': 1, 'value': 'hi'});
      } finally {
        await db?.close();
      }
    });

    test('open_version_1_then_2_then_compact', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath, codec: codec);
      await db.put('test1');
      await db.close();
      db = await factory.openDatabase(dbPath, version: 2, codec: codec);

      await db.put('test2');
      await db.close();

      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 4);
      var expected = <String, dynamic>{"version": 1, "sembast": 1};
      if (codec != null) {
        expected['codec'] = getCodecEncodedSignature(codec);
      }
      expect(json.decode(lines.first), expected);

      var expectedV2 = <String, dynamic>{"version": 2, "sembast": 1};
      if (codec != null) {
        expectedV2['codec'] = getCodecEncodedSignature(codec);
      }
      expect(json.decode(lines[2]), expectedV2);

      await db.close();

      db = await factory.openDatabase(dbPath, codec: codec);
      expect(await db.get(1), 'test1');
      expect(await db.get(2), 'test2');
      expect((await readContent(fs, dbPath)).length, 4);
      await (db as SembastDatabase).compact();

      lines = await readContent(fs, dbPath);
      expect(lines.length, 3);
      expect(json.decode(lines[0]), expectedV2);

      await db.close();

      db = await factory.openDatabase(dbPath, codec: codec);
      expect(await db.get(1), 'test1');
      expect(await db.get(2), 'test2');
      await db.close();
    });
  });

  group('format_import', () {
    test('open_version_2', () async {
      await prepareForDb();
      await writeContent(fs, dbPath, [
        json.encode({
          "version": 2,
          "sembast": 1,
          'codec': getCodecEncodedSignature(codec)
        })
      ]);
      return factory.openDatabase(dbPath, codec: codec).then((Database db) {
        expect(db.version, 2);
      });
    });
  });

  group("corrupted", () {
    test('corrupted', () async {
      await prepareForDb();
      await writeContent(fs, dbPath, ["corrupted"]);

      Future _deleteFile(String path) {
        return fs.file(path).delete();
      }

      Database db;
      try {
        db = await factory.openDatabase(dbPath,
            codec: codec, mode: DatabaseMode.create);
        fail('should fail');
      } on FormatException catch (_) {
        await _deleteFile(dbPath);
        db = await factory.openDatabase(dbPath, codec: codec);
      }
      expect(db.version, 1);
      await db.close();
    });

    test('corrupted_open_empty', () async {
      await prepareForDb();
      await writeContent(fs, dbPath, ["corrupted"]);
      Database db = await factory.openDatabase(dbPath,
          mode: DatabaseMode.empty, codec: codec);
      expect(db.version, 1);
      await db.close();
    });
  });
}
