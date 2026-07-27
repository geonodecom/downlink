import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../instagram/instagram_cookies.dart';
import '../../instagram/instagram_session.dart';

/// Whether in-app WebView cookie capture is supported on this platform.
bool instagramWebViewLoginSupported() =>
    Platform.isAndroid || Platform.isIOS;

Future<bool?> showInstagramLoginDialog(
  BuildContext context, {
  InstagramSession? session,
}) {
  if (!instagramWebViewLoginSupported()) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instagram login'),
        content: const Text(
          'In-app Instagram login is available on Android. '
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
    builder: (context) => InstagramLoginDialog(
      session: session ?? InstagramSession(),
    ),
  );
}

class InstagramLoginDialog extends StatefulWidget {
  const InstagramLoginDialog({required this.session, super.key});

  final InstagramSession session;

  @override
  State<InstagramLoginDialog> createState() => _InstagramLoginDialogState();
}

class _InstagramLoginDialogState extends State<InstagramLoginDialog> {
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
            if (mounted) {
              setState(() => _error = error.description);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.instagram.com/accounts/login/'));
  }

  Future<void> _saveSession() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cookies = await _readInstagramCookies();
      if (!instagramSessionLooksLoggedIn(cookies)) {
        setState(() {
          _saving = false;
          _error =
              'No Instagram session found yet. Log in in the page above, '
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

  Future<List<InstagramCookie>> _readInstagramCookies() async {
    final manager = WebViewCookieManager();
    final urls = [
      Uri.parse('https://www.instagram.com'),
      Uri.parse('https://instagram.com'),
      Uri.parse('https://m.instagram.com'),
    ];
    final byName = <String, InstagramCookie>{};

    if (manager.platform is AndroidWebViewCookieManager) {
      final android = manager.platform as AndroidWebViewCookieManager;
      for (final url in urls) {
        final list = await android.getCookies(url);
        for (final item in list) {
          if (item.name.isEmpty) continue;
          byName[item.name] = InstagramCookie(
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
    if (value.contains('instagram.com') || value.contains('instagr.am')) {
      return '.$value';
    }
    return value.isEmpty ? '.instagram.com' : value;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('Log in to Instagram'),
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
