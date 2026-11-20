import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'web_database_sync_stub.dart'
    if (dart.library.js_interop) 'web_database_sync_web.dart' as platform;

/// Restores persistent tables from browser localStorage into [db] on web platforms.
Future<void> restoreWebDatabase(Database db) =>
    platform.restoreWebDatabase(db);

/// Synchronizes [table] (or all tables if omitted) to browser localStorage on web platforms.
Future<void> syncWebDatabase(Database db, {String? table}) =>
    platform.syncWebDatabase(db, table: table);
