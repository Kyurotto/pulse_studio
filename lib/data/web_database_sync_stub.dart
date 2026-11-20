import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Non-web stub: on native platforms, SQLite writes directly to disk
/// so browser localStorage synchronization is a no-op.
Future<void> restoreWebDatabase(Database db) async {}

Future<void> syncWebDatabase(Database db, {String? table}) async {}
