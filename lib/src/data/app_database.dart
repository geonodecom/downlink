import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

enum DownloadStatus { queued, active, paused, completed, error, removed }

@DataClassName('DownloadEntity')
class DownloadEntries extends Table {
  TextColumn get id => text()();
  TextColumn get gid => text().nullable()();
  TextColumn get url => text()();
  TextColumn get fileName => text().nullable()();
  TextColumn get directory => text()();
  TextColumn get contentUri => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get status => text()();
  IntColumn get queuePosition => integer()();
  IntColumn get totalLength => integer().withDefault(const Constant(0))();
  IntColumn get completedLength => integer().withDefault(const Constant(0))();
  IntColumn get downloadSpeed => integer().withDefault(const Constant(0))();
  IntColumn get uploadSpeed => integer().withDefault(const Constant(0))();
  IntColumn get connections => integer().withDefault(const Constant(0))();
  IntColumn get split => integer().withDefault(const Constant(16))();
  IntColumn get pieceLength => integer().withDefault(const Constant(0))();
  IntColumn get numPieces => integer().withDefault(const Constant(0))();
  TextColumn get bitfield => text().nullable()();
  IntColumn get aria2ErrorCode => integer().nullable()();
  TextColumn get error => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get optionsJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SettingEntity')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [DownloadEntries, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.addColumn(
            downloadEntries,
            downloadEntries.aria2ErrorCode,
          );
        }
        if (from < 3) {
          await migrator.addColumn(downloadEntries, downloadEntries.contentUri);
          await migrator.addColumn(
            downloadEntries,
            downloadEntries.displayName,
          );
        }
        if (from < 4) {
          await migrator.addColumn(
            downloadEntries,
            downloadEntries.uploadSpeed,
          );
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'geonode_download_manager',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}

class GeonodeSettings {
  const GeonodeSettings({
    required this.downloadDirectory,
    required this.maxActiveDownloads,
    required this.defaultSplit,
    required this.aria2Path,
    required this.ytdlpPath,
    required this.ffmpegPath,
    required this.youtubeFormatPreset,
    required this.themeMode,
    this.facebookCookiesPath = '',
    this.facebookCookiesFromBrowser = '',
    this.instagramCookiesPath = '',
    this.instagramCookiesFromBrowser = '',
    this.tiktokCookiesPath = '',
    this.tiktokCookiesFromBrowser = '',
    this.skippedUpdateVersion = '',
    this.lastUpdateCheckAt,
    this.torrentSeedMode = 'stop',
    this.torrentSeedRatio = 1.0,
    this.torrentSeedTimeMinutes = 60,
  });

  final String downloadDirectory;
  final int maxActiveDownloads;
  final int defaultSplit;
  final String aria2Path;
  final String ytdlpPath;
  final String ffmpegPath;
  final String youtubeFormatPreset;
  final String themeMode;
  final String facebookCookiesPath;
  final String facebookCookiesFromBrowser;
  final String instagramCookiesPath;
  final String instagramCookiesFromBrowser;
  final String tiktokCookiesPath;
  final String tiktokCookiesFromBrowser;
  final String skippedUpdateVersion;
  final DateTime? lastUpdateCheckAt;
  final String torrentSeedMode;
  final double torrentSeedRatio;
  final int torrentSeedTimeMinutes;

  GeonodeSettings copyWith({
    String? downloadDirectory,
    int? maxActiveDownloads,
    int? defaultSplit,
    String? aria2Path,
    String? ytdlpPath,
    String? ffmpegPath,
    String? youtubeFormatPreset,
    String? themeMode,
    String? facebookCookiesPath,
    String? facebookCookiesFromBrowser,
    String? instagramCookiesPath,
    String? instagramCookiesFromBrowser,
    String? tiktokCookiesPath,
    String? tiktokCookiesFromBrowser,
    String? skippedUpdateVersion,
    DateTime? lastUpdateCheckAt,
    String? torrentSeedMode,
    double? torrentSeedRatio,
    int? torrentSeedTimeMinutes,
  }) {
    return GeonodeSettings(
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
      maxActiveDownloads: maxActiveDownloads ?? this.maxActiveDownloads,
      defaultSplit: defaultSplit ?? this.defaultSplit,
      aria2Path: aria2Path ?? this.aria2Path,
      ytdlpPath: ytdlpPath ?? this.ytdlpPath,
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      youtubeFormatPreset:
          youtubeFormatPreset ?? this.youtubeFormatPreset,
      themeMode: themeMode ?? this.themeMode,
      facebookCookiesPath:
          facebookCookiesPath ?? this.facebookCookiesPath,
      facebookCookiesFromBrowser:
          facebookCookiesFromBrowser ?? this.facebookCookiesFromBrowser,
      instagramCookiesPath:
          instagramCookiesPath ?? this.instagramCookiesPath,
      instagramCookiesFromBrowser:
          instagramCookiesFromBrowser ?? this.instagramCookiesFromBrowser,
      tiktokCookiesPath: tiktokCookiesPath ?? this.tiktokCookiesPath,
      tiktokCookiesFromBrowser:
          tiktokCookiesFromBrowser ?? this.tiktokCookiesFromBrowser,
      skippedUpdateVersion:
          skippedUpdateVersion ?? this.skippedUpdateVersion,
      lastUpdateCheckAt: lastUpdateCheckAt ?? this.lastUpdateCheckAt,
      torrentSeedMode: torrentSeedMode ?? this.torrentSeedMode,
      torrentSeedRatio: torrentSeedRatio ?? this.torrentSeedRatio,
      torrentSeedTimeMinutes:
          torrentSeedTimeMinutes ?? this.torrentSeedTimeMinutes,
    );
  }
}
