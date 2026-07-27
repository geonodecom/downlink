import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../tiktok/tiktok_cookies.dart';
import '../../tiktok/tiktok_session.dart';

bool tiktokWebViewLoginSupported() => Platform.isAndroid || Platform.isIOS;

Future<bool?> showTikTokLoginDialog(
  BuildContext context, {
  TikTokSession? session,
}) {
  if (!tiktokWebViewLoginSupported()) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TikTok login'),
        content: const Text(
          'In-app TikTok login is available on Android. '
          'On Windows/Linux, use a cookies.txt file or '
          '"Import from browser" in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => TikTokLoginDialog(
      session: session ?? TikTokSession(),
    ),
  );
}

class TikTokLoginDialog extends StatefulWidget {
  const TikTokLoginDialog({required this.session, super.key});

  final TikTokSession session;

  @override
  State<TikTokLoginDialog> createState() => _TikTokLoginDialogState();
}

class _TikTokLoginDialogState extends State<TikTokLoginDialog> {
  late final WebViewController _controller;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _error = error.description);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.tiktok.com/login'));
  }

  Future<void> _saveSession() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cookies = await _readTikTokCookies();
      if (!tiktokSessionLooksLoggedIn(cookies)) {
        setState(() {
          _saving = false;
          _error =
              'No TikTok session found yet. Log in in the page above, '
              'then tap Save session.';
        });
        return;
      }
      await widget.session.saveCookies(cookies);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<List<TikTokCookie>> _readTikTokCookies() async {
    final manager = WebViewCookieManager();
    final urls = [
      Uri.parse('https://www.tiktok.com'),
      Uri.parse('https://tiktok.com'),
      Uri.parse('https://m.tiktok.com'),
    ];
    final byName = <String, TikTokCookie>{};

    if (manager.platform is AndroidWebViewCookieManager) {
      final android = manager.platform as AndroidWebViewCookieManager;
      for (final url in urls) {
        final list = await android.getCookies(url);
        for (final item in list) {
          if (item.name.isEmpty) continue;
          byName[item.name] = TikTokCookie(
            name: item.name,
            value: item.value,
            domain: _normalizeDomain(item.domain),
            path: item.path.isEmpty ? '/' : item.path,
            isSecure: true,
          );
        }
      }
    }

    return byName.values.toList();
  }

  static String _normalizeDomain(String domain) {
    final host = Uri.tryParse(domain)?.host;
    final value = (host != null && host.isNotEmpty) ? host : domain;
    if (value.startsWith('.')) return value;
    if (value.contains('tiktok.com')) return '.$value';
    return value.isEmpty ? '.tiktok.com' : value;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('Log in to TikTok'),
      content: SizedBox(
        width: size.width < 600 ? size.width * 0.95 : 520,
        height: size.height * 0.65,
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sign in below, then tap Save session. '
                'Your session cookies stay on this device.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveSession,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save session'),
        ),
      ],
    );
  }
}
