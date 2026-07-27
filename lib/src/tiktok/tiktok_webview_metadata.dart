import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Loads a TikTok video page in a short-lived WebView and returns HTML (Android WAF fallback).
Future<String?> fetchTiktokPageHtmlViaWebView(
  BuildContext context, {
  required String pageUrl,
  String cookieHeader = '',
}) async {
  if (!Platform.isAndroid) return null;
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (context) => _TikTokWebViewHtmlPage(
        pageUrl: pageUrl,
        cookieHeader: cookieHeader,
      ),
      fullscreenDialog: true,
    ),
  );
}

class _TikTokWebViewHtmlPage extends StatefulWidget {
  const _TikTokWebViewHtmlPage({
    required this.pageUrl,
    required this.cookieHeader,
  });

  final String pageUrl;
  final String cookieHeader;

  @override
  State<_TikTokWebViewHtmlPage> createState() => _TikTokWebViewHtmlPageState();
}

class _TikTokWebViewHtmlPageState extends State<_TikTokWebViewHtmlPage> {
  late final WebViewController _controller;
  var _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => unawaited(_finish()),
        ),
      );
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _seedCookies();
    if (!mounted) return;
    await _controller.loadRequest(
      Uri.parse(widget.pageUrl),
      headers: {
        'Referer': 'https://www.tiktok.com/',
        if (widget.cookieHeader.trim().isNotEmpty)
          'Cookie': widget.cookieHeader,
      },
    );
    unawaited(
      Future<void>.delayed(const Duration(seconds: 12), () {
        if (!_done && mounted) unawaited(_finish());
      }),
    );
  }

  Future<void> _seedCookies() async {
    if (widget.cookieHeader.trim().isEmpty) return;
    final manager = WebViewCookieManager();
    for (final part in widget.cookieHeader.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final name = trimmed.substring(0, eq).trim();
      final value = trimmed.substring(eq + 1).trim();
      await manager.setCookie(
        WebViewCookie(
          name: name,
          value: value,
          domain: '.tiktok.com',
          path: '/',
        ),
      );
    }
  }

  Future<void> _finish() async {
    if (_done || !mounted) return;
    _done = true;
    try {
      final html = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final text = html.toString();
      if (mounted) {
        Navigator.of(context).pop(
          text.length > 500 ? text : null,
        );
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loading TikTok page…'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
