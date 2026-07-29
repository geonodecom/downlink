import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/download_repository.dart';
import '../../extension/download_capture.dart';
import '../../facebook/facebook_metadata_client.dart';
import '../../facebook/facebook_models.dart';
import '../../facebook/facebook_session.dart';
import '../../instagram/instagram_metadata_client.dart';
import '../../instagram/instagram_models.dart';
import '../../instagram/instagram_session.dart';
import '../../providers.dart';
import '../../services/download_service.dart';
import '../../services/url_classifier.dart';
import '../../tiktok/tiktok_metadata_client.dart';
import '../../tiktok/tiktok_models.dart';
import '../../tiktok/tiktok_session.dart';
import '../../tiktok/tiktok_webview_metadata.dart';
import '../../torrent/torrent_models.dart';
import '../../ytdlp/youtube_metadata_client.dart';
import '../../ytdlp/ytdlp_client.dart';
import '../../ytdlp/ytdlp_models.dart';
import '../../ytdlp/ytdlp_paths.dart';
import '../../ytdlp/youtube_tools_message.dart';
import 'youtube_format_dialog.dart';
import 'youtube_playlist_dialog.dart';

Future<void> showAddDownloadDialog(
  BuildContext context, {
  DownloadCapture? capture,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AddDownloadDialog(capture: capture),
  );
}

class AddDownloadDialog extends ConsumerStatefulWidget {
  const AddDownloadDialog({this.capture, super.key});

  final DownloadCapture? capture;

  @override
  ConsumerState<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends ConsumerState<AddDownloadDialog> {
  final _url = TextEditingController();
  final _fileName = TextEditingController();
  final _directory = TextEditingController();
  var _split = 16;
  var _startImmediately = true;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  @override
  void dispose() {
    _url.dispose();
    _fileName.dispose();
    _directory.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    _directory.text = settings.downloadDirectory;
    _split = settings.defaultSplit;
    final capture = widget.capture;
    if (capture != null) {
      _url.text = capture.url;
      _fileName.text = capture.filename;
      if (mounted) setState(() {});
      return;
    }

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim();
    if (text != null) {
      if (text.toLowerCase().startsWith('magnet:?')) {
        _url.text = text;
      } else {
        final normalized = UrlClassifier.normalizeInputUrl(text);
        if (normalized.startsWith('http://') ||
            normalized.startsWith('https://')) {
          _url.text = normalized;
        }
      }
    }
    if (mounted) setState(() {});
  }

  DownloadUrlKind get _urlKind {
    return UrlClassifier.classify(_url.text.trim());
  }

  bool get _isYoutubeFlow {
    final kind = _urlKind;
    return kind == DownloadUrlKind.youtube ||
        kind == DownloadUrlKind.youtubePlaylist;
  }

  bool get _isFacebookFlow => _urlKind == DownloadUrlKind.facebook;

  bool get _isInstagramFlow => _urlKind == DownloadUrlKind.instagram;

  bool get _isTikTokFlow => _urlKind == DownloadUrlKind.tiktok;

  bool get _isMagnetFlow => _urlKind == DownloadUrlKind.magnet;

  bool get _isTorrentFlow => _urlKind == DownloadUrlKind.torrent;

  bool get _isTorrentLikeFlow => _isMagnetFlow || _isTorrentFlow;

  bool get _isExtractorFlow =>
      _isYoutubeFlow ||
      _isFacebookFlow ||
      _isInstagramFlow ||
      _isTikTokFlow;

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final kind = _urlKind;
    return AlertDialog(
      title: const Text('Add Download'),
      content: SizedBox(
        width: narrow ? null : 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _url,
                enabled: !_submitting,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _isTorrentFlow ? 'Torrent / magnet' : 'URL',
                  hintText:
                      'https://…, magnet:?, YouTube, Facebook, Instagram, TikTok, or .torrent',
                  suffixIcon: IconButton(
                    tooltip: 'Browse .torrent file',
                    onPressed: _submitting ? null : _pickTorrentFile,
                    icon: const Icon(Icons.folder_open),
                  ),
                ),
              ),
              if (widget.capture != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _captureLabel(widget.capture!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _fileName,
                enabled: !_submitting && !_isExtractorFlow && !_isTorrentLikeFlow,
                decoration: InputDecoration(
                  labelText: 'Filename override',
                  hintText: _isExtractorFlow
                      ? 'Set after choosing format'
                      : _isTorrentLikeFlow
                          ? 'Uses torrent name'
                          : 'Optional',
                ),
              ),
              const SizedBox(height: 12),
              if (isAndroid)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _androidHelpText(),
                    style: const TextStyle(fontSize: 12),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _directory,
                            enabled: !_submitting,
                            decoration:
                                const InputDecoration(labelText: 'Save to'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _submitting ? null : _pickDirectory,
                          child: const Text('Browse'),
                        ),
                      ],
                    ),
                    if (_isFacebookFlow) ...[
                      const SizedBox(height: 8),
                      Text(
                        Platform.isAndroid
                            ? 'Public videos work without login. '
                                'Private/friends-only need Facebook login in Settings.'
                            : 'Public videos work without cookies. '
                                'Private/friends-only need cookies.txt or '
                                'browser import in Settings → Facebook.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (_isInstagramFlow) ...[
                      const SizedBox(height: 8),
                      Text(
                        Platform.isAndroid
                            ? 'Public posts/reels usually work without login. '
                                'Private need Instagram login in Settings.'
                            : 'Public posts/reels work without cookies when yt-dlp allows it. '
                                'Private need cookies.txt or browser import '
                                'in Settings → Instagram.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (_isTikTokFlow) ...[
                      const SizedBox(height: 8),
                      Text(
                        Platform.isAndroid
                            ? 'Public TikTok videos usually work without login. '
                                'Private need TikTok login in Settings. '
                                'If extraction fails with "universal data", '
                                'update yt-dlp to nightly.'
                            : 'Public videos work without cookies when yt-dlp allows it. '
                                'Private need cookies.txt or browser import '
                                'in Settings → TikTok. '
                                'If you see "universal data for rehydration", '
                                'run yt-dlp --update-to nightly and restart.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              if (!_isExtractorFlow && !_isTorrentLikeFlow) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _split,
                        decoration:
                            const InputDecoration(labelText: 'Connections'),
                        items: const [1, 4, 8, 16, 24, 32]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.toString()),
                              ),
                            )
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _split = value ?? 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start now'),
                        value: _startImmediately,
                        onChanged: _submitting
                            ? null
                            : (value) =>
                                  setState(() => _startImmediately = value),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                if (_isTorrentLikeFlow) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Downloads all files in the torrent. '
                      'Seeding is controlled in Settings → Torrents.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start now'),
                  value: _startImmediately,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _startImmediately = value),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  switch (kind) {
                    DownloadUrlKind.youtube => 'Choose format',
                    DownloadUrlKind.youtubePlaylist => 'Queue playlist',
                    DownloadUrlKind.facebook => 'Choose format',
                    DownloadUrlKind.instagram => 'Choose format',
                    DownloadUrlKind.tiktok => 'Choose format',
                    DownloadUrlKind.magnet => 'Add magnet',
                    DownloadUrlKind.torrent => 'Add torrent',
                    DownloadUrlKind.direct => 'Add',
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pickDirectory() async {
    final path = await getDirectoryPath(initialDirectory: _directory.text);
    if (path != null) _directory.text = path;
  }

  Future<void> _pickTorrentFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'torrent',
          extensions: ['torrent'],
        ),
      ],
    );
    if (file == null) return;
    setState(() {
      _url.text = file.path;
      _fileName.text = p.basenameWithoutExtension(file.path);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final raw = _url.text.trim();
    if (raw.toLowerCase().startsWith('magnet:?')) {
      await _submitTorrent(raw, isMagnet: true);
      return;
    }

    final kind = UrlClassifier.classify(raw);
    if (kind == DownloadUrlKind.torrent) {
      await _submitTorrent(raw, isMagnet: false);
      return;
    }

    final url = UrlClassifier.normalizeInputUrl(raw);
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(
        () => _error =
            'Geonode supports HTTP, HTTPS, magnet links, .torrent files, '
            'YouTube, Facebook, Instagram, and TikTok.',
      );
      return;
    }

    final urlKind = UrlClassifier.classify(url);
    if (urlKind == DownloadUrlKind.youtube) {
      await _submitYoutube(UrlClassifier.normalizeYoutubeUrl(url));
      return;
    }
    if (urlKind == DownloadUrlKind.youtubePlaylist) {
      await _submitYoutubePlaylist(url);
      return;
    }
    if (urlKind == DownloadUrlKind.facebook) {
      await _submitFacebook(UrlClassifier.normalizeFacebookUrl(url));
      return;
    }
    if (urlKind == DownloadUrlKind.instagram) {
      await _submitInstagram(UrlClassifier.normalizeInstagramUrl(url));
      return;
    }
    if (urlKind == DownloadUrlKind.tiktok) {
      await _submitTikTok(UrlClassifier.normalizeTiktokUrl(url));
      return;
    }
    if (urlKind == DownloadUrlKind.torrent) {
      await _submitTorrent(url, isMagnet: false);
      return;
    }

    await _submitDirect(url);
  }

  Future<void> _submitTorrent(String source, {required bool isMagnet}) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final settings = await ref.read(downloadRepositoryProvider).getSettings();
      final options = TorrentDownloadOptions(
        kind: isMagnet
            ? TorrentDownloadOptions.kindMagnet
            : TorrentDownloadOptions.kindTorrent,
        torrentPath: isMagnet ? '' : source,
        seedMode: TorrentSeedMode.parse(settings.torrentSeedMode),
        seedRatio: settings.torrentSeedRatio,
        seedTimeMinutes: settings.torrentSeedTimeMinutes,
      );

      final displayName = isMagnet
          ? (UrlClassifier.magnetDisplayName(source) ?? 'Magnet download')
          : p.basenameWithoutExtension(source);

      await ref.read(downloadServiceProvider).addDownload(
            NewDownload(
              url: source,
              directory: _directory.text.trim().isEmpty
                  ? settings.downloadDirectory
                  : _directory.text.trim(),
              fileName: displayName,
              split: 1,
              startImmediately: _startImmediately,
              source: 'manual',
              options: options.toJson(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } on DownloadAlreadyExistsException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _androidHelpText() {
    if (_isMagnetFlow || _isTorrentFlow) {
      return 'Torrents and magnets download all files. '
          'Seeding is controlled in Settings → Torrents.';
    }
    if (_isYoutubeFlow) {
      return 'YouTube videos are extracted and saved to Downloads.';
    }
    if (_isFacebookFlow) {
      return 'Facebook videos save to Downloads. '
          'Private/friends-only need Facebook login in Settings.';
    }
    if (_isInstagramFlow) {
      return 'Instagram posts/reels save to Downloads. '
          'Private videos need Instagram login in Settings.';
    }
    if (_isTikTokFlow) {
      return 'TikTok videos save to Downloads. '
          'Private videos need TikTok login in Settings.';
    }
    return 'Files are saved to the system Downloads folder.';
  }

  Future<YoutubeMetadataClient> _youtubeClient() async {
    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    return createYoutubeMetadataClient(
      ytdlpOverride: settings.ytdlpPath,
      ffmpegOverride: settings.ffmpegPath,
      facebookCookieArgs: FacebookCookieArgs(
        cookiesPath: settings.facebookCookiesPath,
        fromBrowser: settings.facebookCookiesFromBrowser,
      ),
      facebookSession: ref.read(facebookSessionProvider),
      instagramCookieArgs: InstagramCookieArgs(
        cookiesPath: settings.instagramCookiesPath,
        fromBrowser: settings.instagramCookiesFromBrowser,
      ),
      instagramSession: ref.read(instagramSessionProvider),
      tiktokCookieArgs: TikTokCookieArgs(
        cookiesPath: settings.tiktokCookiesPath,
        fromBrowser: settings.tiktokCookiesFromBrowser,
      ),
      tiktokSession: ref.read(tiktokSessionProvider),
    );
  }

  Future<bool> _ensureYoutubeTools(YoutubeMetadataClient client) async {
    if (await client.checkHealth()) return true;
    if (!mounted) return false;
    setState(() {
      _error = '';
      _submitting = false;
    });
    final message = await youtubeToolsUnavailableMessage();
    if (mounted) setState(() => _error = message);
    return false;
  }

  Future<void> _submitYoutube(String url) async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    final client = await _youtubeClient();
    if (!await _ensureYoutubeTools(client)) return;

    YtdlpVideoInfo info;
    try {
      info = await client.fetchInfo(url);
    } on YtdlpException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _submitting = false;
        });
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _submitting = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final preset = presetFromStorage(settings.youtubeFormatPreset);
    final selection = await showYoutubeFormatDialog(
      context,
      info: info,
      initialFormatId: info.defaultFormatId(preset),
    );
    if (selection == null || !mounted) return;

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      final directory = await resolveYtdlpDownloadDirectory(
        Platform.isAndroid ? 'Downloads' : _directory.text.trim(),
      );
      final options = YoutubeDownloadOptions(
        formatId: selection.formatId,
        title: selection.title,
        ext: selection.ext,
      );
      await ref.read(downloadServiceProvider).addDownload(
            NewDownload(
              url: url,
              directory: directory,
              fileName: selection.fileName,
              split: 1,
              startImmediately: _startImmediately,
              metadata: DownloadMetadata(
                fileName: selection.fileName,
                totalLength: 0,
              ),
              headers: widget.capture?.headers ?? const {},
              source: _youtubeSource(),
              options: options.toJson(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _submitting = false;
        });
      }
    }
  }

  Future<void> _submitYoutubePlaylist(String url) async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    final client = await _youtubeClient();
    if (!await _ensureYoutubeTools(client)) return;

    YtdlpPlaylistInfo playlist;
    try {
      playlist = await client.fetchPlaylist(url);
    } on YtdlpException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _submitting = false;
        });
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _submitting = false;
        });
      }
      return;
    }

    YtdlpVideoInfo sampleInfo;
    try {
      sampleInfo = await client.fetchInfo(playlist.entries.first.url);
    } on YtdlpException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _submitting = false;
        });
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _submitting = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final preset = presetFromStorage(settings.youtubeFormatPreset);
    final selection = await showYoutubePlaylistDialog(
      context,
      playlist: playlist,
      sampleInfo: sampleInfo,
      initialFormatId: sampleInfo.defaultFormatId(preset),
    );
    if (selection == null || !mounted) return;

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      final directory = await resolveYtdlpDownloadDirectory(
        Platform.isAndroid ? 'Downloads' : _directory.text.trim(),
      );
      final service = ref.read(downloadServiceProvider);
      var added = 0;
      var skipped = 0;

      for (final entry in playlist.entries) {
        final watchUrl = entry.url.isNotEmpty
            ? entry.url
            : 'https://www.youtube.com/watch?v=${entry.id}';
        final options = YoutubeDownloadOptions(
          formatId: selection.formatId,
          title: entry.title,
          ext: selection.ext,
        );
        final fileName = options.sanitizedFileName;
        try {
          await service.addDownload(
            NewDownload(
              url: watchUrl,
              directory: directory,
              fileName: fileName,
              split: 1,
              startImmediately: _startImmediately,
              metadata: DownloadMetadata(fileName: fileName, totalLength: 0),
              headers: widget.capture?.headers ?? const {},
              source: 'youtube_playlist',
              options: options.toJson(),
            ),
          );
          added++;
        } on DownloadAlreadyExistsException {
          skipped++;
        }
      }

      if (!mounted) return;
      if (added == 0 && skipped > 0) {
        setState(() {
          _error = 'All videos from this playlist are already in the queue.';
          _submitting = false;
        });
        return;
      }
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _submitting = false;
        });
      }
    }
  }

  Future<void> _submitFacebook(String url) async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    late final YtdlpVideoInfo info;
    late final Map<String, String> progressiveUrls;

    if (Platform.isAndroid) {
      final cookieHeader =
          await ref.read(facebookSessionProvider).cookieHeader();
      final client = FacebookMetadataClient(cookieHeader: cookieHeader);
      try {
        final result = await client.fetchInfo(url);
        info = result.info;
        progressiveUrls = result.progressiveUrls;
      } on YtdlpException catch (error) {
        if (mounted) {
          setState(() {
            _error = error.message;
            _submitting = false;
          });
        }
        return;
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _submitting = false;
          });
        }
        return;
      } finally {
        client.close();
      }
    } else {
      final client = await _youtubeClient();
      if (!await _ensureYoutubeTools(client)) return;
      progressiveUrls = const {};
      try {
        info = await client.fetchInfo(url);
      } on YtdlpException catch (error) {
        if (mounted) {
          setState(() {
            _error = _friendlyFacebookDesktopError(error.message);
            _submitting = false;
          });
        }
        return;
      } on FormatException catch (error) {
        if (mounted) {
          setState(() {
            _error =
                'Could not read yt-dlp output for this Facebook video '
                '(encoding error). Try again, or update yt-dlp. ($error)';
            _submitting = false;
          });
        }
        return;
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _submitting = false;
          });
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final preset = presetFromStorage(settings.youtubeFormatPreset);
    final selection = await showYoutubeFormatDialog(
      context,
      info: info,
      initialFormatId: info.defaultFormatId(preset),
      dialogTitle: 'Choose Facebook format',
    );
    if (selection == null || !mounted) return;

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      final directory = await resolveYtdlpDownloadDirectory(
        Platform.isAndroid ? 'Downloads' : _directory.text.trim(),
      );
      final directUrl = progressiveUrls[selection.formatId] ?? '';
      if (Platform.isAndroid && directUrl.isEmpty) {
        throw StateError('Selected Facebook format has no progressive URL.');
      }
      final options = FacebookDownloadOptions(
        formatId: selection.formatId,
        title: selection.title,
        ext: selection.ext,
        directUrl: directUrl,
      );
      final fileName = _facebookFileName(
        selection.fileName,
        videoId: info.id,
        ext: selection.ext,
      );
      await ref.read(downloadServiceProvider).addDownload(
            NewDownload(
              url: url,
              directory: directory,
              fileName: fileName,
              split: Platform.isAndroid ? _split : 1,
              startImmediately: _startImmediately,
              metadata: DownloadMetadata(
                fileName: fileName,
                totalLength: 0,
              ),
              headers: widget.capture?.headers ?? const {},
              source: _facebookSource(),
              options: options.toJson(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _submitting = false;
        });
      }
    }
  }

  /// Avoids collapsing many logged-in Facebook titles to the same Facebook.mp4.
  String _facebookFileName(
    String preferred, {
    required String videoId,
    required String ext,
  }) {
    final cleanedExt = ext.startsWith('.') ? ext.substring(1) : ext;
    final safeExt = cleanedExt.isEmpty ? 'mp4' : cleanedExt;
    var base = preferred.trim();
    if (base.toLowerCase().endsWith('.$safeExt')) {
      base = base.substring(0, base.length - safeExt.length - 1);
    }
    if (base.isEmpty || base.toLowerCase() == 'facebook') {
      base = videoId.isNotEmpty ? 'facebook_$videoId' : 'facebook_video';
    } else if (videoId.isNotEmpty && !base.contains(videoId)) {
      base = '${base}_$videoId';
    }
    return '$base.$safeExt';
  }

  String _friendlyFacebookDesktopError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('login') ||
        lower.contains('cookie') ||
        lower.contains('private') ||
        lower.contains('unavailable')) {
      return 'Could not extract this Facebook video. '
          'For private/friends-only videos, open Settings → Facebook and set '
          'cookies.txt or import from browser. Details: $message';
    }
    return message;
  }

  Future<void> _submitInstagram(String url) async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    late final YtdlpVideoInfo info;
    late final Map<String, String> progressiveUrls;

    if (Platform.isAndroid) {
      final cookieHeader =
          await ref.read(instagramSessionProvider).cookieHeader();
      final client = InstagramMetadataClient(cookieHeader: cookieHeader);
      try {
        final result = await client.fetchInfo(url);
        info = result.info;
        progressiveUrls = result.progressiveUrls;
      } on YtdlpException catch (error) {
        if (mounted) {
          setState(() {
            _error = error.message;
            _submitting = false;
          });
        }
        return;
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _submitting = false;
          });
        }
        return;
      } finally {
        client.close();
      }
    } else {
      final client = await _youtubeClient();
      if (!await _ensureYoutubeTools(client)) return;
      progressiveUrls = const {};
      try {
        info = await client.fetchInfo(url);
      } on YtdlpException catch (error) {
        if (mounted) {
          setState(() {
            _error = _friendlyInstagramDesktopError(error.message);
            _submitting = false;
          });
        }
        return;
      } on FormatException catch (error) {
        if (mounted) {
          setState(() {
            _error =
                'Could not read yt-dlp output for this Instagram video '
                '(encoding error). Try again, or update yt-dlp. ($error)';
            _submitting = false;
          });
        }
        return;
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _submitting = false;
          });
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final preset = presetFromStorage(settings.youtubeFormatPreset);
    final selection = await showYoutubeFormatDialog(
      context,
      info: info,
      initialFormatId: info.defaultFormatId(preset),
      dialogTitle: 'Choose Instagram format',
    );
    if (selection == null || !mounted) return;

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      final directory = await resolveYtdlpDownloadDirectory(
        Platform.isAndroid ? 'Downloads' : _directory.text.trim(),
      );
      final directUrl = progressiveUrls[selection.formatId] ?? '';
      if (Platform.isAndroid && directUrl.isEmpty) {
        throw StateError('Selected Instagram format has no progressive URL.');
      }
      final shortcode =
          UrlClassifier.extractInstagramShortcode(url) ?? info.id;
      final options = InstagramDownloadOptions(
        formatId: selection.formatId,
        title: selection.title,
        ext: selection.ext,
        directUrl: directUrl,
      );
      final fileName = _instagramFileName(
        selection.fileName,
        shortcode: shortcode,
        ext: selection.ext,
      );
      await ref.read(downloadServiceProvider).addDownload(
            NewDownload(
              url: url,
              directory: directory,
              fileName: fileName,
              split: Platform.isAndroid ? _split : 1,
              startImmediately: _startImmediately,
              metadata: DownloadMetadata(
                fileName: fileName,
                totalLength: 0,
              ),
              headers: widget.capture?.headers ?? const {},
              source: _instagramSource(),
              options: options.toJson(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _submitting = false;
        });
      }
    }
  }

  /// Avoids collapsing many Instagram titles to the same Instagram.mp4.
  String _instagramFileName(
    String preferred, {
    required String shortcode,
    required String ext,
  }) {
    final cleanedExt = ext.startsWith('.') ? ext.substring(1) : ext;
    final safeExt = cleanedExt.isEmpty ? 'mp4' : cleanedExt;
    var base = preferred.trim();
    if (base.toLowerCase().endsWith('.$safeExt')) {
      base = base.substring(0, base.length - safeExt.length - 1);
    }
    if (base.isEmpty ||
        base.toLowerCase() == 'instagram' ||
        base.toLowerCase() == 'video by instagram') {
      base = shortcode.isNotEmpty ? 'instagram_$shortcode' : 'instagram_video';
    } else if (shortcode.isNotEmpty && !base.contains(shortcode)) {
      base = '${base}_$shortcode';
    }
    return '$base.$safeExt';
  }

  String _friendlyInstagramDesktopError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('login') ||
        lower.contains('cookie') ||
        lower.contains('private') ||
        lower.contains('unavailable')) {
      return 'Could not extract this Instagram video. '
          'For private videos, open Settings → Instagram and set '
          'cookies.txt or import from browser. Details: $message';
    }
    return message;
  }

  Future<void> _submitTikTok(String url) async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    late final YtdlpVideoInfo info;
    late final Map<String, String> progressiveUrls;
    var cdnCookieHeader = '';

    if (Platform.isAndroid) {
      final cookieHeader =
          await ref.read(tiktokSessionProvider).cookieHeader();
      final client = TikTokMetadataClient(
        cookieHeader: cookieHeader,
        webViewHtmlFetcher: (pageUrl) => fetchTiktokPageHtmlViaWebView(
          context,
          pageUrl: pageUrl,
          cookieHeader: cookieHeader,
        ),
      );
      try {
        final result = await client.fetchInfo(url);
        info = result.info;
        progressiveUrls = result.progressiveUrls;
        cdnCookieHeader = result.cdnCookieHeader;
      } on YtdlpException catch (error) {
        if (mounted) {
          setState(() {
            _error = error.message;
            _submitting = false;
          });
        }
        return;
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _submitting = false;
          });
        }
        return;
      } finally {
        client.close();
      }
    } else {
      final client = await _youtubeClient();
      if (!await _ensureYoutubeTools(client)) return;
      progressiveUrls = const {};
      try {
        info = await client.fetchInfo(url);
      } on YtdlpException catch (error) {
        if (mounted) {
          setState(() {
            _error = _friendlyTikTokDesktopError(error.message);
            _submitting = false;
          });
        }
        return;
      } on FormatException catch (error) {
        if (mounted) {
          setState(() {
            _error =
                'Could not read yt-dlp output for this TikTok video '
                '(encoding error). Try again, or update yt-dlp. ($error)';
            _submitting = false;
          });
        }
        return;
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _submitting = false;
          });
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final preset = presetFromStorage(settings.youtubeFormatPreset);
    final selection = await showYoutubeFormatDialog(
      context,
      info: info,
      initialFormatId: info.defaultFormatId(preset),
      dialogTitle: 'Choose TikTok format',
    );
    if (selection == null || !mounted) return;

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      final directory = await resolveYtdlpDownloadDirectory(
        Platform.isAndroid ? 'Downloads' : _directory.text.trim(),
      );
      final directUrl = progressiveUrls[selection.formatId] ?? '';
      if (Platform.isAndroid && directUrl.isEmpty) {
        throw StateError('Selected TikTok format has no progressive URL.');
      }
      final videoId = UrlClassifier.extractTiktokVideoId(url) ?? info.id;
      final options = TikTokDownloadOptions(
        formatId: selection.formatId,
        title: selection.title,
        ext: selection.ext,
        directUrl: directUrl,
        cookieHeader: cdnCookieHeader,
      );
      final fileName = _tiktokFileName(
        selection.fileName,
        videoId: videoId,
        ext: selection.ext,
      );
      await ref.read(downloadServiceProvider).addDownload(
            NewDownload(
              url: url,
              directory: directory,
              fileName: fileName,
              split: 1,
              startImmediately: _startImmediately,
              metadata: DownloadMetadata(
                fileName: fileName,
                totalLength: 0,
              ),
              headers: widget.capture?.headers ?? const {},
              source: _tiktokSource(),
              options: options.toJson(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _submitting = false;
        });
      }
    }
  }

  String _tiktokFileName(
    String preferred, {
    required String videoId,
    required String ext,
  }) {
    final cleanedExt = ext.startsWith('.') ? ext.substring(1) : ext;
    final safeExt = cleanedExt.isEmpty ? 'mp4' : cleanedExt;
    var base = preferred.trim();
    // Strip any existing extension before rebuilding.
    final existingExt = p.extension(base);
    if (existingExt.isNotEmpty) {
      base = p.basenameWithoutExtension(base);
    }
    if (base.isEmpty ||
        base.toLowerCase() == 'tiktok' ||
        base.toLowerCase() == 'video by tiktok' ||
        (videoId.isNotEmpty && base == videoId)) {
      base = videoId.isNotEmpty ? 'tiktok_$videoId' : 'tiktok_video';
    } else if (videoId.isNotEmpty && !base.contains(videoId)) {
      base = '${base}_$videoId';
    }
    return '$base.$safeExt';
  }

  String _friendlyTikTokDesktopError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('universal data') ||
        lower.contains('rehydration') ||
        lower.contains('webpage video data') ||
        lower.contains('js challenge') ||
        lower.contains('tls') ||
        lower.contains('ssl')) {
      return 'TikTok’s page challenge blocked this attempt (common and often temporary). '
          'Tap Choose format again. Use a recent nightly yt-dlp '
          '(Settings → yt-dlp override, or run tool/windows/fetch_deps.ps1). '
          'If it keeps failing, open the video in a browser, export cookies.txt, '
          'and set it in Settings → TikTok — or clear TikTok cookie import if set.';
    }
    if (lower.contains('login') ||
        lower.contains('cookie') ||
        lower.contains('private') ||
        lower.contains('waf') ||
        lower.contains('unavailable')) {
      return 'Could not extract this TikTok video. '
          'For private videos or TikTok security checks, open Settings → TikTok '
          'and set cookies.txt or import from browser, and keep yt-dlp updated '
          '(prefer nightly). Details: $message';
    }
    return message;
  }

  Future<void> _submitDirect(String url) async {
    final directory = Platform.isAndroid
        ? (_directory.text.trim().isEmpty ? 'Downloads' : _directory.text.trim())
        : _directory.text.trim();
    if (directory.isEmpty) {
      setState(() => _error = 'Choose a download directory.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(downloadServiceProvider).addDownload(
            NewDownload(
              url: url,
              directory: directory,
              fileName: _fileName.text.trim(),
              split: _split,
              startImmediately: _startImmediately,
              headers: widget.capture?.headers ?? const {},
              source: widget.capture == null ? 'manual' : 'browser_extension',
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _submitting = false;
        });
      }
    }
  }

  String _youtubeSource() {
    if (widget.capture == null) return 'youtube';
    return widget.capture!.source == 'browser_extension'
        ? 'youtube_extension'
        : 'youtube_share';
  }

  String _facebookSource() {
    if (widget.capture == null) return 'facebook';
    return widget.capture!.source == 'browser_extension'
        ? 'facebook_extension'
        : 'facebook_share';
  }

  String _instagramSource() {
    if (widget.capture == null) return 'instagram';
    return widget.capture!.source == 'browser_extension'
        ? 'instagram_extension'
        : 'instagram_share';
  }

  String _tiktokSource() {
    if (widget.capture == null) return 'tiktok';
    return widget.capture!.source == 'browser_extension'
        ? 'tiktok_extension'
        : 'tiktok_share';
  }

  String _captureLabel(DownloadCapture capture) {
    final source = capture.sourcePageUrl;
    if (source.isEmpty) return 'From browser extension';
    return 'From browser extension - $source';
  }
}
