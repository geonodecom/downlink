enum DownloadUrlKind {
  direct,
  youtube,
  youtubePlaylist,
  facebook,
  instagram,
  tiktok,
}

/// Classifies download URLs for routing to direct HTTP or extractors.
class UrlClassifier {
  const UrlClassifier._();

  static const _youtubeHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  };

  static const _facebookHosts = {
    'facebook.com',
    'www.facebook.com',
    'm.facebook.com',
    'web.facebook.com',
    'fb.watch',
    'fb.com',
    'www.fb.com',
  };

  static const _instagramHosts = {
    'instagram.com',
    'www.instagram.com',
    'm.instagram.com',
    'instagr.am',
    'www.instagr.am',
  };

  static const _tiktokHosts = {
    'tiktok.com',
    'www.tiktok.com',
    'm.tiktok.com',
    'vm.tiktok.com',
    'vt.tiktok.com',
  };

  /// Trims and, for bare known hosts, prepends `https://`.
  static String normalizeInputUrl(String raw) {
    var text = raw.trim();
    // Strip zero-width / BOM characters that break Uri host parsing on paste.
    text = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    if (text.isEmpty) return text;

    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      final hostCandidate = text.split('/').first.split('?').first.toLowerCase();
      if (_youtubeHosts.contains(hostCandidate) ||
          hostCandidate.endsWith('.youtube.com') ||
          hostCandidate == 'youtu.be' ||
          _facebookHosts.contains(hostCandidate) ||
          hostCandidate.endsWith('.facebook.com') ||
          hostCandidate == 'fb.watch' ||
          hostCandidate == 'fb.com' ||
          _instagramHosts.contains(hostCandidate) ||
          hostCandidate.endsWith('.instagram.com') ||
          hostCandidate == 'instagr.am' ||
          _tiktokHosts.contains(hostCandidate) ||
          hostCandidate.endsWith('.tiktok.com')) {
        text = 'https://$text';
      }
    }
    return text;
  }

  static DownloadUrlKind classify(String url) {
    final normalized = normalizeInputUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return DownloadUrlKind.direct;
    }

    final host = uri.host.toLowerCase();

    if (_isFacebookHost(host)) {
      return DownloadUrlKind.facebook;
    }

    if (_isInstagramHost(host)) {
      return DownloadUrlKind.instagram;
    }

    if (_isTiktokHost(host) && _looksLikeTiktokVideoUrl(normalized)) {
      return DownloadUrlKind.tiktok;
    }

    if (!_isYoutubeHost(host)) {
      return DownloadUrlKind.direct;
    }

    final videoId = extractYoutubeVideoId(normalized);
    if (videoId != null && videoId.isNotEmpty) {
      return DownloadUrlKind.youtube;
    }

    if (_isPlaylistOnly(uri)) {
      return DownloadUrlKind.youtubePlaylist;
    }

    return DownloadUrlKind.direct;
  }

  static bool isYoutube(String url) => classify(url) == DownloadUrlKind.youtube;

  static bool isYoutubePlaylist(String url) {
    return classify(url) == DownloadUrlKind.youtubePlaylist;
  }

  static bool isFacebook(String url) => classify(url) == DownloadUrlKind.facebook;

  static bool isInstagram(String url) =>
      classify(url) == DownloadUrlKind.instagram;

  static bool isTiktok(String url) => classify(url) == DownloadUrlKind.tiktok;

  /// Extracts an 11-character YouTube video id when present.
  static String? extractYoutubeVideoId(String url) {
    final normalized = normalizeInputUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !_isYoutubeHost(uri.host.toLowerCase())) return null;

    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;

    if (host == 'youtu.be' && segments.isNotEmpty) {
      return _validVideoId(segments.first);
    }

    final path = uri.path.toLowerCase();
    if (path.startsWith('/shorts/') ||
        path.startsWith('/live/') ||
        path.startsWith('/embed/') ||
        path.startsWith('/clip/') ||
        path.startsWith('/v/') ||
        path.startsWith('/e/')) {
      if (segments.length >= 2) {
        return _validVideoId(segments[1]);
      }
    }

    final fromQuery = uri.queryParameters['v'];
    if (fromQuery != null) {
      return _validVideoId(fromQuery);
    }

    return null;
  }

  /// Canonical watch URL when a video id can be extracted; otherwise normalized input.
  static String normalizeYoutubeUrl(String url) {
    final normalized = normalizeInputUrl(url);
    final id = extractYoutubeVideoId(normalized);
    if (id != null) {
      return 'https://www.youtube.com/watch?v=$id';
    }
    return normalized;
  }

  /// Stable https Facebook URL for extractors.
  static String normalizeFacebookUrl(String url) {
    final normalized = normalizeInputUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !_isFacebookHost(uri.host.toLowerCase())) {
      return normalized;
    }

    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;

    if (host == 'fb.watch' && segments.isNotEmpty) {
      final code = segments.first;
      if (code.isNotEmpty) {
        return 'https://fb.watch/$code';
      }
    }

    final path = uri.path;
    final lowerPath = path.toLowerCase();

    // /watch/?v=ID or /watch?v=ID
    final watchId = uri.queryParameters['v'] ?? uri.queryParameters['vd'];
    if (lowerPath.contains('/watch') && watchId != null && watchId.isNotEmpty) {
      return 'https://www.facebook.com/watch/?v=$watchId';
    }

    // /reel/ID or /reels/ID
    final reelMatch = RegExp(r'/reels?/([^/?#]+)', caseSensitive: false)
        .firstMatch(path);
    if (reelMatch != null) {
      return 'https://www.facebook.com/reel/${reelMatch.group(1)}';
    }

    // /videos/ID or /username/videos/ID
    final videosMatch = RegExp(
      r'/videos/(?:[^/]+/)?(\d+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (videosMatch != null) {
      return 'https://www.facebook.com/watch/?v=${videosMatch.group(1)}';
    }

    // Prefer www host for facebook.com variants.
    if (host == 'facebook.com' ||
        host == 'm.facebook.com' ||
        host == 'web.facebook.com' ||
        host == 'fb.com' ||
        host == 'www.fb.com') {
      return uri.replace(scheme: 'https', host: 'www.facebook.com').toString();
    }

    return uri.replace(scheme: 'https').toString();
  }

  /// Stable https Instagram post/reel URL for extractors.
  static String normalizeInstagramUrl(String url) {
    final normalized = normalizeInputUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !_isInstagramHost(uri.host.toLowerCase())) {
      return normalized;
    }

    final path = uri.path;
    final shortcodeMatch = RegExp(
      r'/(?:p|reel|reels|tv)/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (shortcodeMatch != null) {
      final code = shortcodeMatch.group(1)!;
      final kind = shortcodeMatch.group(0)!.toLowerCase().contains('/tv/')
          ? 'tv'
          : shortcodeMatch.group(0)!.toLowerCase().contains('/p/')
              ? 'p'
              : 'reel';
      return 'https://www.instagram.com/$kind/$code/';
    }

    return uri
        .replace(scheme: 'https', host: 'www.instagram.com')
        .toString();
  }

  /// Shortcode from a normalized Instagram URL when present.
  static String? extractInstagramShortcode(String url) {
    final normalized = normalizeInstagramUrl(url);
    final match = RegExp(
      r'/(?:p|reel|reels|tv)/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(Uri.tryParse(normalized)?.path ?? '');
    return match?.group(1);
  }

  /// Stable https TikTok video URL when id (and optional @user) are known.
  static String normalizeTiktokUrl(String url) {
    final normalized = normalizeInputUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !_isTiktokHost(uri.host.toLowerCase())) {
      return normalized;
    }

    final host = uri.host.toLowerCase();
    final id = extractTiktokVideoId(normalized);
    if (id == null || id.isEmpty) {
      return uri.replace(scheme: 'https').toString();
    }

    // Short links: keep vm/vt host so yt-dlp/Android can follow redirects.
    if (host == 'vm.tiktok.com' || host == 'vt.tiktok.com') {
      final path = uri.path.startsWith('/') ? uri.path : '/$id';
      return uri.replace(scheme: 'https', host: host, path: path).toString();
    }

    final path = uri.path;
    final userVideo = RegExp(
      r'/@([^/]+)/video/(\d+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (userVideo != null) {
      return 'https://www.tiktok.com/@${userVideo.group(1)}/video/${userVideo.group(2)}';
    }

    final bareVideo = RegExp(r'/video/(\d+)', caseSensitive: false).firstMatch(path);
    if (bareVideo != null) {
      return 'https://www.tiktok.com/video/${bareVideo.group(1)}';
    }

    return 'https://www.tiktok.com/video/$id';
  }

  /// Numeric video id when present in URL path or short-link segment.
  static String? extractTiktokVideoId(String url) {
    final normalized = normalizeInputUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !_isTiktokHost(uri.host.toLowerCase())) return null;

    final host = uri.host.toLowerCase();
    final path = uri.path;

    final userVideo = RegExp(r'/video/(\d+)', caseSensitive: false).firstMatch(path);
    if (userVideo != null) return userVideo.group(1);

    if (host == 'vm.tiktok.com' || host == 'vt.tiktok.com') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final seg = segments.first;
        if (RegExp(r'^\d+$').hasMatch(seg)) return seg;
        return seg;
      }
    }

    return null;
  }

  static bool _looksLikeTiktokVideoUrl(String url) {
    return extractTiktokVideoId(url) != null;
  }

  static bool _isTiktokHost(String host) {
    return _tiktokHosts.contains(host) || host.endsWith('.tiktok.com');
  }

  static bool _isYoutubeHost(String host) {
    return _youtubeHosts.contains(host) || host.endsWith('.youtube.com');
  }

  static bool _isFacebookHost(String host) {
    return _facebookHosts.contains(host) || host.endsWith('.facebook.com');
  }

  static bool _isInstagramHost(String host) {
    return _instagramHosts.contains(host) ||
        host.endsWith('.instagram.com') ||
        host == 'instagr.am' ||
        host.endsWith('.instagr.am');
  }

  static bool _isPlaylistOnly(Uri uri) {
    // Only /playlist URLs are playlists. watch?v=…&list=… (mix/radio) is a
    // single video — handled earlier when a video id is present.
    final path = uri.path.toLowerCase();
    return path == '/playlist' || path.startsWith('/playlist/');
  }

  static String? _validVideoId(String? value) {
    final id = value?.trim() ?? '';
    if (id.length == 11 && RegExp(r'^[\w-]{11}$').hasMatch(id)) {
      return id;
    }
    // Allow slightly looser ids from path segments (some clip ids vary).
    if (id.isNotEmpty && RegExp(r'^[\w-]{6,}$').hasMatch(id)) {
      return id;
    }
    return null;
  }
}
