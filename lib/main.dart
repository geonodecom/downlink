import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/extension/app_extension_bridge.dart';
import 'src/platform/share_intake.dart';
import 'src/providers.dart';
import 'src/services/diagnostics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'Downlink',
        size: Size(1180, 760),
        minimumSize: Size(920, 620),
        center: true,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(const ProviderScope(child: DownlinkApp()));
}

class DownlinkApp extends ConsumerStatefulWidget {
  const DownlinkApp({super.key});

  @override
  ConsumerState<DownlinkApp> createState() => _DownlinkAppState();
}

class _DownlinkAppState extends ConsumerState<DownlinkApp>
    with TrayListener, WindowListener {
  AppExtensionBridge? _extensionBridge;
  final ShareIntake _shareIntake = ShareIntake();

  bool get _isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      trayManager.addListener(this);
      windowManager.addListener(this);
      unawaited(_setupTray());
    }
    if (Platform.isLinux || Platform.isWindows) {
      unawaited(_startExtensionBridge());
    }
    if (Platform.isAndroid) {
      unawaited(_startShareIntake());
      unawaited(_requestAndroidNotificationPermission());
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    unawaited(_extensionBridge?.stop());
    unawaited(_shareIntake.stop());
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    unawaited(ref.read(downloadServiceProvider).start());
  }

  Future<void> _setupTray() async {
    final icon = Platform.isWindows
        ? 'images/tray-icon.ico'
        : 'images/tray-icon.png';
    await trayManager.setIcon(icon);
    try {
      await trayManager.setToolTip('Downlink');
    } on MissingPluginException {
      // Linux support in tray_manager does not currently implement tooltips.
    }
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'open', label: 'Open Downlink'),
          MenuItem(key: 'add', label: 'Add Download'),
          MenuItem.separator(),
          MenuItem(key: 'pause_all', label: 'Pause All'),
          MenuItem(key: 'resume_all', label: 'Resume All'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _startExtensionBridge() async {
    final bridge = AppExtensionBridge(
      diagnostics: ref.read(diagnosticsLogProvider),
      onShow: _showWindow,
      onCapture: (capture) async {
        ref.read(shellSectionProvider.notifier).select(ShellSection.downloads);
        ref.read(downloadCaptureQueueProvider.notifier).enqueue(capture);
        await _showWindow();
      },
    );
    _extensionBridge = bridge;
    try {
      await bridge.start();
    } catch (error) {
      ref
          .read(diagnosticsLogProvider)
          .error('Extension bridge failed to start: $error');
    }
  }

  Future<void> _startShareIntake() async {
    await _shareIntake.start(
      onCapture: (capture) {
        ref.read(shellSectionProvider.notifier).select(ShellSection.downloads);
        ref.read(downloadCaptureQueueProvider.notifier).enqueue(capture);
      },
    );
  }

  Future<void> _requestAndroidNotificationPermission() async {
    try {
      await const MethodChannel(
        'com.geonode.downlink/engine',
      ).invokeMethod<void>('requestNotificationPermission');
    } catch (_) {
      // Optional on older Android versions.
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    unawaited(_handleTrayMenuItem(menuItem));
  }

  Future<void> _handleTrayMenuItem(MenuItem menuItem) async {
    final service = ref.read(downloadServiceProvider);
    switch (menuItem.key) {
      case 'open':
        await _showWindow();
        break;
      case 'add':
        ref.read(shellSectionProvider.notifier).select(ShellSection.downloads);
        ref.read(addDownloadRequestProvider.notifier).request();
        await _showWindow();
        break;
      case 'pause_all':
        await service.pauseAll();
        break;
      case 'resume_all':
        await service.resumeQueued();
        break;
      case 'quit':
        await service.shutdown();
        await trayManager.destroy();
        await windowManager.destroy();
        break;
    }
  }

  @override
  void onWindowClose() {
    unawaited(windowManager.hide());
  }

  @override
  Widget build(BuildContext context) => const DownlinkMaterialApp();
}
