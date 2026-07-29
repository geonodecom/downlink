import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'app_update_models.dart';
import 'app_update_service.dart';

enum AppUpdateUiPhase {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  error,
}

class AppUpdateState {
  const AppUpdateState({
    this.phase = AppUpdateUiPhase.idle,
    this.offer,
    this.progress,
    this.localFilePath,
    this.message,
    this.currentVersionLabel,
  });

  final AppUpdateUiPhase phase;
  final UpdateOffer? offer;
  final AppUpdateProgress? progress;
  final String? localFilePath;
  final String? message;
  final String? currentVersionLabel;

  AppUpdateState copyWith({
    AppUpdateUiPhase? phase,
    UpdateOffer? offer,
    AppUpdateProgress? progress,
    String? localFilePath,
    String? message,
    String? currentVersionLabel,
    bool clearOffer = false,
    bool clearProgress = false,
    bool clearLocalFile = false,
    bool clearMessage = false,
  }) {
    return AppUpdateState(
      phase: phase ?? this.phase,
      offer: clearOffer ? null : offer ?? this.offer,
      progress: clearProgress ? null : progress ?? this.progress,
      localFilePath: clearLocalFile ? null : localFilePath ?? this.localFilePath,
      message: clearMessage ? null : message ?? this.message,
      currentVersionLabel:
          currentVersionLabel ?? this.currentVersionLabel,
    );
  }
}

class AppUpdateController extends Notifier<AppUpdateState> {
  @override
  AppUpdateState build() => const AppUpdateState();

  AppUpdateService get _service => ref.read(appUpdateServiceProvider);

  Future<void> loadVersionLabel() async {
    final label = await _service.currentVersionLabel();
    state = state.copyWith(currentVersionLabel: label);
  }

  Future<UpdateOffer?> checkForUpdate({
    bool background = false,
    bool ignoreSkip = false,
  }) async {
    if (!Platform.isAndroid && !Platform.isWindows) {
      state = state.copyWith(
        phase: AppUpdateUiPhase.error,
        message: 'Updates are not available on this platform yet.',
      );
      return null;
    }

    if (background && !await _service.shouldRunBackgroundCheck()) {
      return null;
    }

    state = state.copyWith(
      phase: AppUpdateUiPhase.checking,
      clearMessage: true,
    );

    try {
      final offer = await _service.checkForUpdate(ignoreSkip: ignoreSkip);
      if (offer == null) {
        state = state.copyWith(
          phase: AppUpdateUiPhase.idle,
          clearOffer: true,
          clearMessage: background,
          message: background ? null : 'You are up to date.',
        );
        return null;
      }
      state = state.copyWith(
        phase: AppUpdateUiPhase.available,
        offer: offer,
        clearMessage: true,
      );
      return offer;
    } on AppUpdateException catch (e) {
      state = state.copyWith(phase: AppUpdateUiPhase.error, message: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        phase: AppUpdateUiPhase.error,
        message: 'Could not check for updates: $e',
      );
      return null;
    }
  }

  Future<void> skipOffer() async {
    final offer = state.offer;
    if (offer == null) return;
    await _service.skipVersion(offer.version);
    state = state.copyWith(
      phase: AppUpdateUiPhase.idle,
      clearOffer: true,
      clearProgress: true,
      clearLocalFile: true,
    );
  }

  Future<void> downloadAndApply() async {
    final offer = state.offer;
    if (offer == null) return;

    state = state.copyWith(
      phase: AppUpdateUiPhase.downloading,
      clearMessage: true,
      progress: AppUpdateProgress(received: 0, total: offer.expectedSize),
    );

    try {
      final file = await _service.downloadUpdate(
        offer,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
      state = state.copyWith(
        phase: AppUpdateUiPhase.readyToInstall,
        localFilePath: file.path,
        clearProgress: true,
      );
      await _service.applyUpdate(file);
    } on AppUpdateException catch (e) {
      state = state.copyWith(phase: AppUpdateUiPhase.error, message: e.message);
    } catch (e) {
      state = state.copyWith(
        phase: AppUpdateUiPhase.error,
        message: 'Update failed: $e',
      );
    }
  }
}
