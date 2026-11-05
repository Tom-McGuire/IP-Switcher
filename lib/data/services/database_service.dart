import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../domain/models/command_execution_log.dart';
import '../../domain/models/ip_profile_model.dart';
import '../../domain/models/profile_category_model.dart';
import 'demo_profile_generator.dart';

class DatabaseService {
  final String? overridePath;
  Database? _db;
  Future<Database>? _dbInitFuture;

  DatabaseService({this.overridePath});

  /// Exact 8 preset IDs that were auto-seeded in v0.5.0 (DB version 1).
  /// Upgrading from v1 deletes ONLY these 8 IDs and preserves any user-created presets.
  static const List<String> legacySeededIds = [
    'preset-office-dhcp',
    'preset-lab-static',
    'preset-field-default',
    'preset-vlan-20-test',
    'preset-artnet-lighting',
    'preset-mikrotik-rescue',
    'preset-ubiquiti-fallback',
    'preset-plc-multihome',
  ];

  Future<Database> get database async {
    if (_db != null) return _db!;
    _dbInitFuture ??= _initDatabase(overridePath: overridePath);
    _db = await _dbInitFuture!;
    return _db!;
  }

  Future<Database> _initDatabase({String? overridePath}) async {
    sqfliteFfiInit();
    final dbFactory = databaseFactoryFfi;

    String dbPath;
    if (overridePath != null) {
      dbPath = overridePath;
    } else {
      Directory dir;
      try {
        dir = await getApplicationSupportDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      dbPath = p.join(dir.path, 'ip_setter_profiles.db');
    }

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedDefaultCategoriesIfNeeded(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            final placeholders =
                List.filled(legacySeededIds.length, '?').join(',');
            await db.delete(
              'profiles',
              where: 'id IN ($placeholders)',
              whereArgs: legacySeededIds,
            );
          }
          if (oldVersion < 3) {
            await _createCategoriesTable(db);
            await _seedDefaultCategoriesIfNeeded(db);
          }
        },
      ),
    );
    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS profiles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        is_dhcp INTEGER NOT NULL,
        ip_address TEXT,
        subnet_mask TEXT,
        cidr_prefix INTEGER,
        default_gateway TEXT,
        primary_dns TEXT,
        secondary_dns TEXT,
        secondary_ips TEXT,
        preferred_interface TEXT,
        vlan_id INTEGER,
        mtu INTEGER,
        notes TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        last_applied_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS execution_logs (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        profile_name TEXT NOT NULL,
        interface_name TEXT NOT NULL,
        platform_name TEXT NOT NULL,
        commands TEXT NOT NULL,
        exit_code INTEGER NOT NULL,
        stdout TEXT NOT NULL,
        stderr TEXT NOT NULL,
        gateway_reachable INTEGER,
        gateway_latency_ms REAL,
        is_dry_run INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createCategoriesTable(db);
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color_hex INTEGER NOT NULL,
        is_visible INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _seedDefaultCategoriesIfNeeded(Database db) async {
    final existing = await db.query('categories', limit: 1);
    if (existing.isNotEmpty) return;

    final batch = db.batch();
    for (final cat in ProfileCategoryModel.defaultCategories) {
      batch.insert(
        'categories',
        cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ProfileCategoryModel>> getAllCategories() async {
    final db = await database;
    final rows = await db.query('categories');
    return rows.map(ProfileCategoryModel.fromMap).toList();
  }

  Future<void> upsertCategory(ProfileCategoryModel category) async {
    final db = await database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> renameCategoryInProfiles(String oldName, String newName) async {
    final db = await database;
    await db.update(
      'profiles',
      {'category': newName},
      where: 'UPPER(category) = ?',
      whereArgs: [oldName.toUpperCase()],
    );
  }

  Future<List<IpProfileModel>> getAllProfiles() async {
    final db = await database;
    final rows = await db.query(
      'profiles',
      orderBy: 'is_favorite DESC, name ASC',
    );
    return rows.map(IpProfileModel.fromMap).toList();
  }

  Future<void> upsertProfile(IpProfileModel profile) async {
    final db = await database;
    await db.insert(
      'profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProfile(String id) async {
    final db = await database;
    await db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllProfiles() async {
    final db = await database;
    await db.delete('profiles');
  }

  Future<void> loadDemoProfiles() async {
    final db = await database;
    final batch = db.batch();
    for (final preset in DemoProfileGenerator.demoProfiles) {
      batch.insert(
        'profiles',
        preset.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertExecutionLog(CommandExecutionLog log, {int maxLogs = 200}) async {
    final db = await database;
    await db.insert(
      'execution_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.rawDelete(
      '''
      DELETE FROM execution_logs
      WHERE id NOT IN (
        SELECT id FROM execution_logs
        ORDER BY timestamp DESC
        LIMIT ?
      )
      ''',
      [maxLogs],
    );
  }

  Future<List<CommandExecutionLog>> getExecutionLogs({int limit = 200}) async {
    final db = await database;
    final rows = await db.query(
      'execution_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(CommandExecutionLog.fromMap).toList();
  }

  Future<void> clearExecutionLogs() async {
    final db = await database;
    await db.delete('execution_logs');
  }

  Future<void> close() async {
    _dbInitFuture = null;
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
