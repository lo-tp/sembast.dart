library sembast.database_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  DatabaseFactory factory = ctx.factory;
  String dbPath;

  group('database', () {
    dbPath = ctx.dbPath;

    group('open', () {
      Database db;

      setUp(() async {
        await factory.deleteDatabase(dbPath);
      });

      tearDown(() {
        if (db != null) {
          db.close();
        }
      });

      test('open_no_version', () async {
        var db = await factory.openDatabase(dbPath);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db.close();
      });

      test('open_existing_no_version', () async {
        dbPath = ctx.dbPath;
        try {
          await factory.openDatabase(dbPath, mode: DatabaseMode.existing);
          fail("should fail");
        } on DatabaseException catch (e) {
          expect(e.code, DatabaseException.errDatabaseNotFound);
        }
      });

      test('open_version', () async {
        dbPath = ctx.dbPath;
        var db = await factory.openDatabase(dbPath, version: 1);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db.close();
      });

      test('open_twice_no_close', () async {
        var dbPath = ctx.dbPath;
        var db = await factory.openDatabase(dbPath, version: 1);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        var db2 = await factory.openDatabase(dbPath, version: 1);
        // behavior is unexpected from now...
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db2.close();
      });

      test('open_twice_same_instance', () async {
        var dbPath = ctx.dbPath;
        var futureDb1 = factory.openDatabase(dbPath);
        var futureDb2 = factory.openDatabase(dbPath);
        var db1 = await futureDb1;
        var db2 = await futureDb2;
        var db3 = await factory.openDatabase(dbPath);
        expect(db1, db2);
        expect(db1, db3);
        expect(identical(db1, db3), isTrue);
        await db1.close();
      });
    });

    group('onVersionChanged', () {
      Database db;

      setUp(() {
        return factory.deleteDatabase(dbPath).then((_) {});
      });

      tearDown(() {
        if (db != null) {
          db.close();
        }
      });

      test('open_no_version', () async {
        // save to make sure we've been through
        int _oldVersion;
        int _newVersion;
        void _onVersionChanged(Database db, int oldVersion, int newVersion) {
          expect(db.version, oldVersion);
          _oldVersion = oldVersion;
          _newVersion = newVersion;
        }

        var db = await factory.openDatabase(dbPath,
            onVersionChanged: _onVersionChanged);
        expect(_oldVersion, 0);
        expect(_newVersion, 1);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db.close();
      });

      test('open_version', () async {
        // save to make sure we've been through
        int _oldVersion;
        int _newVersion;
        void _onVersionChanged(Database db, int oldVersion, int newVersion) {
          expect(db.version, oldVersion);
          _oldVersion = oldVersion;
          _newVersion = newVersion;
        }

        var db = await factory.openDatabase(dbPath,
            version: 1, onVersionChanged: _onVersionChanged);

        expect(_oldVersion, 0);
        expect(_newVersion, 1);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db.close();
      });

      test('changes during onVersionChanged', () async {
        var db = await factory.openDatabase(dbPath, version: 1,
            onVersionChanged: (db, _, __) async {
          await db.put('test', 1);
        });
        await db.put('other', 2);

        try {
          expect(await db.get(1), 'test');
          expect(db.version, 1);
          await reOpen(db);
          expect(await db.get(1), 'test');
          expect(db.version, 1);
        } finally {
          await db?.close();
        }
      });
    });
  });
}
