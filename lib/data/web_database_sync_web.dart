import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web/web.dart' as web;

/// Web implementation: synchronizes SQLite tables with browser `window.localStorage`
/// so that user accounts, sessions, settings, and imported Spotify playlists survive
/// Chrome desktop tab closures and browser restarts.
const _tablesToSync = [
  'app_settings',
  'users',
  'user_sessions',
  'remembered_accounts',
  'employees',
  'tracks',
  'playlists',
  'playlist_tracks',
  'imported_playlists',
  'imported_songs',
  'imported_playlist_songs',
  'listening_history',
];

String _storageKeyFor(String table) => 'pulse_web_${table}_v1';

/// Restores all persisted tables from browser localStorage into the SQLite database.
Future<void> restoreWebDatabase(Database db) async {
  try {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    } catch (_) {}

    try {
      await db.execute('PRAGMA foreign_keys = OFF');
    } catch (_) {}

    final storage = web.window.localStorage;
    for (final table in _tablesToSync) {
      final key = _storageKeyFor(table);
      final jsonStr = storage.getItem(key);
      if (jsonStr == null || jsonStr.trim().isEmpty) continue;

      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              await db.insert(
                table,
                map,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[WebDatabaseSync] restore table $table error: $e');
      }
    }

    try {
      await db.execute('PRAGMA foreign_keys = ON');
    } catch (_) {}
  } catch (e) {
    debugPrint('[WebDatabaseSync] restoreWebDatabase error: $e');
  }
}

/// Synchronizes one or all SQLite tables to browser localStorage.
Future<void> syncWebDatabase(Database db, {String? table}) async {
  try {
    final storage = web.window.localStorage;
    final targets = table != null ? [table] : _tablesToSync;

    for (final tbl in targets) {
      if (!_tablesToSync.contains(tbl)) continue;
      try {
        final rows = await db.query(tbl);
        final key = _storageKeyFor(tbl);
        storage.setItem(key, jsonEncode(rows));
      } catch (e) {
        debugPrint('[WebDatabaseSync] sync table $tbl error: $e');
      }
    }
  } catch (e) {
    debugPrint('[WebDatabaseSync] syncWebDatabase error: $e');
  }
}
