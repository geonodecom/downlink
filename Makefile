APP_NAME := downlink
BUNDLE_DIR := build/linux/x64/release/bundle
DEBUG_BUNDLE_DIR := build/linux/x64/debug/bundle
INSTALL_DIR := $(HOME)/.local/share/$(APP_NAME)
STATE_DIR := $(or $(XDG_STATE_HOME),$(HOME)/.local/state)/$(APP_NAME)
RUN_LOG := $(STATE_DIR)/run.log
BIN_DIR := $(HOME)/.local/bin
APP_DIR := $(HOME)/.local/share/applications
DESKTOP_TEMPLATE := packaging/downlink.desktop
DESKTOP_FILE := $(APP_DIR)/downlink.desktop
HICOLOR_DIR := $(HOME)/.local/share/icons/hicolor
ICON_DIR := $(HICOLOR_DIR)/256x256/apps
APP_ICON := $(ICON_DIR)/downlink.png
USER_SYSTEMD_DIR := $(HOME)/.config/systemd/user
NATIVE_HOST_NAME := com.geonode.downlink
NATIVE_HOST_BUILD := build/downlink-host
NATIVE_HOST_BUILD_DIR := build/downlink-host-cli
NATIVE_HOST_INSTALLED := $(BIN_DIR)/downlink-host
NATIVE_HOST_TEMPLATE := packaging/$(NATIVE_HOST_NAME).json
NATIVE_HOST_DIRS := \
	$(HOME)/.config/google-chrome/NativeMessagingHosts \
	$(HOME)/.config/chromium/NativeMessagingHosts \
	$(HOME)/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts

DEPS_BIN := build/deps/linux-x64/bin

.PHONY: \
	get codegen analyze test clean \
	fetch-deps check-linux-deps check-not-running \
	build-host build build-debug \
	run debug run-log run-verbose run-release run-bundle run-debug-bundle \
	install install-built install-app install-desktop install-native-host \
	uninstall uninstall-app uninstall-native-host \
	remove-legacy-service refresh-desktop-cache

get:
	flutter pub get

codegen:
	dart run build_runner build

analyze: codegen
	flutter analyze

test: codegen
	flutter test

clean:
	flutter clean

check-linux-deps:
	@tool/check_linux_deps.sh

fetch-deps:
	@chmod +x tool/linux/fetch_deps.sh
	@tool/linux/fetch_deps.sh

copy-deps: fetch-deps
	mkdir -p "$(BUNDLE_DIR)/bin"
	cp -a "$(DEPS_BIN)/." "$(BUNDLE_DIR)/bin/"
	@if [ -f packaging/THIRD_PARTY_NOTICES.md ]; then \
		cp packaging/THIRD_PARTY_NOTICES.md "$(BUNDLE_DIR)/"; \
	fi

check-not-running:
	@if pgrep -x "$(APP_NAME)" >/dev/null; then \
		echo "Downlink is already running. Quit Downlink from the tray before using this target."; \
		echo "Running instances:"; \
		pgrep -ax "$(APP_NAME)"; \
		exit 1; \
	fi

build-host:
	dart build cli -t bin/downlink_host.dart -o "$(NATIVE_HOST_BUILD_DIR)"
	cp "$(NATIVE_HOST_BUILD_DIR)/bundle/bin/downlink_host" "$(NATIVE_HOST_BUILD)"

build: check-linux-deps codegen build-host
	flutter build linux --release
	$(MAKE) copy-deps

build-debug: check-linux-deps codegen
	flutter build linux --debug
	$(MAKE) copy-deps BUNDLE_DIR=$(DEBUG_BUNDLE_DIR)

run: check-linux-deps check-not-running codegen
	flutter run -d linux

debug: run

run-log: check-linux-deps check-not-running codegen
	mkdir -p "$(STATE_DIR)"
	flutter run -d linux 2>&1 | tee "$(RUN_LOG)"

run-verbose: check-linux-deps check-not-running codegen
	flutter run -d linux -v

run-release: check-linux-deps check-not-running codegen
	flutter run -d linux --release

run-bundle: check-not-running build
	"$(BUNDLE_DIR)/$(APP_NAME)"

run-debug-bundle: check-not-running build-debug
	"$(DEBUG_BUNDLE_DIR)/$(APP_NAME)"

install: build install-built

install-built: remove-legacy-service install-app install-desktop install-native-host refresh-desktop-cache

install-app:
	mkdir -p "$(INSTALL_DIR)" "$(BIN_DIR)"
	rm -rf "$(INSTALL_DIR)"
	cp -a "$(BUNDLE_DIR)" "$(INSTALL_DIR)"
	ln -sfn "$(INSTALL_DIR)/$(APP_NAME)" "$(BIN_DIR)/$(APP_NAME)"
	install -m 755 "$(NATIVE_HOST_BUILD)" "$(NATIVE_HOST_INSTALLED)"

install-desktop:
	mkdir -p "$(APP_DIR)" "$(ICON_DIR)"
	sed "s|^Exec=.*|Exec=$(BIN_DIR)/$(APP_NAME)|" "$(DESKTOP_TEMPLATE)" > "$(DESKTOP_FILE)"
	chmod 755 "$(DESKTOP_FILE)"
	gio set "$(DESKTOP_FILE)" metadata::trusted true >/dev/null 2>&1 || true
	cp images/appicon.png "$(APP_ICON)"

install-native-host:
	@for dir in $(NATIVE_HOST_DIRS); do \
		mkdir -p "$$dir"; \
		sed "s|DOWNLINK_HOST_PATH|$(NATIVE_HOST_INSTALLED)|" "$(NATIVE_HOST_TEMPLATE)" > "$$dir/$(NATIVE_HOST_NAME).json"; \
	done

uninstall: remove-legacy-service uninstall-app uninstall-native-host refresh-desktop-cache

uninstall-app:
	rm -rf "$(INSTALL_DIR)"
	rm -f "$(BIN_DIR)/$(APP_NAME)"
	rm -f "$(NATIVE_HOST_INSTALLED)"
	rm -f "$(DESKTOP_FILE)"
	rm -f "$(APP_ICON)"

uninstall-native-host:
	@for dir in $(NATIVE_HOST_DIRS); do \
		rm -f "$$dir/$(NATIVE_HOST_NAME).json"; \
	done

remove-legacy-service:
	@if [ -f "$(USER_SYSTEMD_DIR)/bolt.service" ]; then \
		echo "Removing legacy Bolt user service"; \
		systemctl --user disable --now bolt.service >/dev/null 2>&1 || true; \
		rm -f "$(USER_SYSTEMD_DIR)/bolt.service"; \
		systemctl --user daemon-reload >/dev/null 2>&1 || true; \
	fi

refresh-desktop-cache:
	update-desktop-database "$(APP_DIR)" >/dev/null 2>&1 || true
	gtk-update-icon-cache "$(HICOLOR_DIR)" >/dev/null 2>&1 || true
