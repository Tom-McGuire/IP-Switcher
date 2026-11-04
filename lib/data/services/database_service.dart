import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../domain/models/command_execution_log.dart';
import '../../domain/models/ip_profile_model.dart';

class DatabaseService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
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
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE profiles (
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
            CREATE TABLE execution_logs (
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

          for (final preset in defaultSeedProfiles) {
            await db.insert('profiles', preset.toMap());
          }
        },
      ),
    );
    return db;
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

  Future<void> resetToDefaultProfiles() async {
    final db = await database;
    await db.delete('profiles');
    for (final preset in defaultSeedProfiles) {
      await db.insert('profiles', preset.toMap());
    }
  }

  Future<void> insertExecutionLog(CommandExecutionLog log) async {
    final db = await database;
    await db.insert(
      'execution_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
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
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  static final List<IpProfileModel> defaultSeedProfiles = [
    const IpProfileModel(
      id: 'preset-office-dhcp',
      name: 'Office DHCP',
      category: 'OFFICE',
      isDhcp: true,
      notes: 'Standard corporate/office automatic IPv4 & DNS assignment',
      isFavorite: true,
    ),
    const IpProfileModel(
      id: 'preset-lab-static',
      name: 'Lab Static',
      category: 'LAB',
      isDhcp: false,
      ipAddress: '192.168.1.50',
      subnetMask: '255.255.255.0',
      cidrPrefix: 24,
      defaultGateway: '192.168.1.1',
      primaryDns: '1.1.1.1',
      secondaryDns: '8.8.8.8',
      notes: 'Standard 192.168.1.0/24 bench switches, cameras, and lab gear',
      isFavorite: true,
    ),
    const IpProfileModel(
      id: 'preset-field-default',
      name: 'Field Default',
      category: 'FIELD',
      isDhcp: false,
      ipAddress: '10.0.0.100',
      subnetMask: '255.255.255.0',
      cidrPrefix: 24,
      defaultGateway: '10.0.0.1',
      primaryDns: '10.0.0.1',
      secondaryDns: '8.8.8.8',
      notes: 'Field controller & telemetry rack subnet (10.0.0.0/24)',
      isFavorite: true,
    ),
    const IpProfileModel(
      id: 'preset-vlan-20-test',
      name: 'VLAN 20 Test',
      category: 'VLAN',
      isDhcp: false,
      ipAddress: '172.16.20.50',
      subnetMask: '255.255.255.0',
      cidrPrefix: 24,
      defaultGateway: '172.16.20.1',
      primaryDns: '172.16.20.1',
      vlanId: 20,
      notes: 'Isolated management & voice test trunk on VLAN 20',
      isFavorite: true,
    ),
    const IpProfileModel(
      id: 'preset-artnet-lighting',
      name: 'Art-Net / sACN 2.x.x.x',
      category: 'FIELD',
      isDhcp: false,
      ipAddress: '2.0.0.10',
      subnetMask: '255.0.0.0',
      cidrPrefix: 8,
      defaultGateway: '',
      notes: 'Class A 2.x.x.x/8 entertainment lighting & DMX gateway network (no default gateway)',
      isFavorite: false,
    ),
    const IpProfileModel(
      id: 'preset-mikrotik-rescue',
      name: 'Router Rescue (192.168.88.x)',
      category: 'LAB',
      isDhcp: false,
      ipAddress: '192.168.88.10',
      subnetMask: '255.255.255.0',
      cidrPrefix: 24,
      defaultGateway: '192.168.88.1',
      primaryDns: '192.168.88.1',
      notes: 'Factory default MikroTik RouterOS provisioning subnet',
      isFavorite: false,
    ),
    const IpProfileModel(
      id: 'preset-ubiquiti-fallback',
      name: 'Ubiquiti / AP Fallback',
      category: 'FIELD',
      isDhcp: false,
      ipAddress: '192.168.1.25',
      subnetMask: '255.255.255.0',
      cidrPrefix: 24,
      defaultGateway: '192.168.1.20',
      notes: 'Direct link to unconfigured airMAX / UniFi hardware at 192.168.1.20',
      isFavorite: false,
    ),
    const IpProfileModel(
      id: 'preset-plc-multihome',
      name: 'Industrial PLC Multi-Home',
      category: 'LAB',
      isDhcp: false,
      ipAddress: '192.168.0.250',
      subnetMask: '255.255.255.0',
      cidrPrefix: 24,
      defaultGateway: '192.168.0.1',
      secondaryIps: ['192.168.10.250/24'],
      notes: 'Primary 192.168.0.x PLC subnet + secondary 192.168.10.x HMI alias',
      isFavorite: false,
    ),
  ];
}
