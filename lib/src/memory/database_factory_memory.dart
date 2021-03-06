import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/memory/file_system_memory.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/src/storage.dart';

/// The pure memory factory
final DatabaseFactoryMemory databaseFactoryMemory = DatabaseFactoryMemory._();

/// The memory with a simulated file system factory
final DatabaseFactoryMemoryFs databaseFactoryMemoryFs =
    DatabaseFactoryMemoryFs();

/// In memory implementation
class DatabaseFactoryMemory extends SembastDatabaseFactory
    with DatabaseFactoryMixin {
  // make it private
  DatabaseFactoryMemory._();

  @override
  Future deleteDatabase(String path) {
    if (path != null) {
      _databases.remove(path);
    }
    return Future.value();
  }

  //Database _defaultDatabase;
  Map<String, SembastDatabase> _databases = {};

  @override
  bool get hasStorage => false;

  @override
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper) {
    SembastDatabase db;
    var path = openHelper.path;
    if (path != null) {
      db = _databases[path];
    }

    if (db == null) {
      db = SembastDatabase(openHelper, DatabaseStorageMemory(this, path));
    }
    return db;
  }
}

///
/// Open a new database in memory
///
Future<Database> openMemoryDatabase() {
  return databaseFactoryMemory.openDatabase(null);
}

class DatabaseStorageMemory extends DatabaseStorage {
  final DatabaseFactoryMemory factory;
  @override
  final String path;
  DatabaseStorageMemory(this.factory, this.path);

  @override
  Future<bool> find() {
    return Future.value(factory._databases[path] != null);
  }

  @override
  Future findOrCreate() => Future.value();

  @override
  bool get supported => false;

  @override
  Future delete() => null;

  @override
  Stream<String> readLines() => null;

  @override
  Future appendLines(List<String> lines) => null;

  @override
  DatabaseStorage get tmpStorage => null;

  @override
  Future tmpRecover() => null;
}

/// The simulated fs factory class
class DatabaseFactoryMemoryFs extends DatabaseFactoryFs {
  DatabaseFactoryMemoryFs() : super(memoryFileSystem);
}
