import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/auth/auth_service.dart';
import 'package:music/data/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    LocalDatabase.debugClearActiveSessionOverride = null;
  });

  tearDown(() {
    LocalDatabase.debugClearActiveSessionOverride = null;
    LocalDatabase.setDatabaseForTesting(null);
  });

  test('signOut still clears the in-memory session when the DB is read-only',
      () async {
    LocalDatabase.debugClearActiveSessionOverride = () async {
      throw Exception('attempt to write a readonly database (code 8)');
    };

    final cleared = await AuthService.instance.signOut();

    expect(cleared, isFalse);
    expect(AuthService.instance.currentUser, isNull);
    expect(AuthService.instance.isAppLocked, isFalse);
  });

  test('saveActiveSession repairs a read-only connection and retries', () async {
    final dir = await Directory.systemTemp.createTemp('pulse_ro_test_');
    final dbPath = '${dir.path}${Platform.pathSeparator}pulse_music.db';
    final seed = await databaseFactoryFfi.openDatabase(dbPath);
    await seed.execute(
      'CREATE TABLE user_sessions ('
      'user_id TEXT PRIMARY KEY, saved_at INTEGER NOT NULL)',
    );
    await seed.execute(
      'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await seed.close();

    final readOnly = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(readOnly: true),
    );
    LocalDatabase.setDatabaseForTesting(readOnly);

    await LocalDatabase.instance.saveActiveSession('repair_user');

    expect(await LocalDatabase.instance.getActiveSessionUserId(), 'repair_user');

    await readOnly.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('clearActiveSession repairs a read-only connection and retries',
      () async {
    final dir = await Directory.systemTemp.createTemp('pulse_ro_clear_');
    final dbPath = '${dir.path}${Platform.pathSeparator}pulse_music.db';
    final seed = await databaseFactoryFfi.openDatabase(dbPath);
    await seed.execute(
      'CREATE TABLE user_sessions ('
      'user_id TEXT PRIMARY KEY, saved_at INTEGER NOT NULL)',
    );
    await seed.insert('user_sessions', {
      'user_id': 'repair_user',
      'saved_at': DateTime.now().millisecondsSinceEpoch,
    });
    await seed.execute(
      'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await seed.close();

    final readOnly = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(readOnly: true),
    );
    LocalDatabase.setDatabaseForTesting(readOnly);

    await LocalDatabase.instance.clearActiveSession();

    expect(await LocalDatabase.instance.getActiveSessionUserId(), isNull);

    await readOnly.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });
}
