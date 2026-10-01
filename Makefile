# Executable name inside the bundle (same for every variant)
APP_NAME = TypeAny

# dev (default) and release are fully isolated: bundle id, input source, data directory,
# preferences and permissions all differ, so both can be installed side by side.
#   make install                 → ~/Library/Input Methods/TypeAnyDev.app  (TypeAny Dev)
#   make install VARIANT=release → ~/Library/Input Methods/TypeAny.app     (TypeAny)
VARIANT ?= dev
ifeq ($(VARIANT),release)
  BUNDLE_NAME = TypeAny
  BUNDLE_ID = com.typeany.inputmethod.TypeAny
  DISPLAY_NAME = TypeAny
else ifeq ($(VARIANT),dev)
  BUNDLE_NAME = TypeAnyDev
  BUNDLE_ID = com.typeany.inputmethod.TypeAnyDev
  DISPLAY_NAME = TypeAny Dev
else
  $(error VARIANT must be dev or release)
endif

BUILD_DIR = .build
RELEASE_BIN = $(BUILD_DIR)/release/$(APP_NAME)
APP_BUNDLE = $(BUILD_DIR)/$(BUNDLE_NAME).app
RIME_DATA = $(BUILD_DIR)/rime-data
# Input methods must live here for macOS to load them
INSTALL_DIR = $(HOME)/Library/Input Methods
INSTALLED_APP = $(INSTALL_DIR)/$(BUNDLE_NAME).app
LEGACY_APP = /Applications/$(APP_NAME).app
# Fills the Info.plist / InfoPlist.strings templates for this variant
SUBST = sed -e 's/__BUNDLE_ID__/$(BUNDLE_ID)/g' -e 's/__DISPLAY_NAME__/$(DISPLAY_NAME)/g' -e 's/__VARIANT__/$(VARIANT)/g'
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
# Code signing identity; "-" = ad-hoc. Use a real cert (e.g. "Apple Development")
# so Accessibility permission survives rebuilds.
SIGN_IDENTITY ?= -

.PHONY: build run install release icons rime-data test test-rime test-spacing clean

PREDICT_DATA = $(BUILD_DIR)/predict/predict.tsv

build: $(RIME_DATA)/build/default.yaml $(PREDICT_DATA)
	swift build -c release
	@echo "Creating app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@mkdir -p "$(APP_BUNDLE)/Contents/SharedSupport"
	@cp "$(RELEASE_BIN)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@$(SUBST) "Sources/TypeAny/Resources/Info.plist" > "$(APP_BUNDLE)/Contents/Info.plist"
	@cp "Sources/TypeAny/Resources/TypeAny.pdf" "Sources/TypeAny/Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/"
	@for lproj in Sources/TypeAny/Resources/*.lproj; do \
		mkdir -p "$(APP_BUNDLE)/Contents/Resources/$$(basename $$lproj)"; \
		$(SUBST) "$$lproj/InfoPlist.strings" > "$(APP_BUNDLE)/Contents/Resources/$$(basename $$lproj)/InfoPlist.strings"; \
	done
	@rsync -a --delete "$(RIME_DATA)/" "$(APP_BUNDLE)/Contents/SharedSupport/rime-data/"
	@cp "$(PREDICT_DATA)" "$(APP_BUNDLE)/Contents/SharedSupport/predict.tsv"
	@codesign --force --sign "$(SIGN_IDENTITY)" "$(APP_BUNDLE)"
	@echo "Build complete: $(APP_BUNDLE) ($(VARIANT))"

# Rime schema + prebuilt dictionaries (re-run when the schema changes)
$(RIME_DATA)/build/default.yaml: scripts/build-rime-data.sh $(wildcard Rime/*.yaml Rime/*.txt)
	./scripts/build-rime-data.sh

rime-data:
	./scripts/build-rime-data.sh

# Next-word prediction table (联想)
$(PREDICT_DATA): scripts/build-predict-data.sh
	./scripts/build-predict-data.sh

test: test-rime test-spacing

# 中英文自动空格 rules (pure Swift, no app needed)
test-spacing:
	@mkdir -p "$(BUILD_DIR)/spacing-test"
	@swiftc Sources/TypeAny/InputMethod/AutoSpacing.swift Tests/autospacing/main.swift -o "$(BUILD_DIR)/spacing-test/run"
	@"$(BUILD_DIR)/spacing-test/run"

# Candidate-order regression tests against the built Rime data
test-rime: $(RIME_DATA)/build/default.yaml
	@mkdir -p "$(BUILD_DIR)/rime-test"
	@clang -ISources/CRime $$(pkg-config --cflags --libs rime) Tests/rime/candidates.c -o "$(BUILD_DIR)/rime-test/candidates"
	@rm -rf "$(BUILD_DIR)/rime-test/user" && mkdir -p "$(BUILD_DIR)/rime-test/user"
	@"$(BUILD_DIR)/rime-test/candidates" "$(RIME_DATA)" "$(BUILD_DIR)/rime-test/user" 2>/dev/null

install: build
	@# Only this variant's processes (input method + onboarding); the other variant keeps running
	@-pkill -f "$(INSTALLED_APP)/Contents/MacOS/"
	@mkdir -p "$(INSTALL_DIR)"
	@rm -rf "$(INSTALLED_APP)"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@"$(INSTALLED_APP)/Contents/MacOS/$(APP_NAME)" --install
	@# Pre-input-method builds lived in /Applications (bundle id com.typeany.app); Spotlight
	@# would launch that stale copy instead of this one, so remove it.
	@if [ "$$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$(LEGACY_APP)/Contents/Info.plist" 2>/dev/null)" = "com.typeany.app" ]; then \
		pkill -f "$(LEGACY_APP)/Contents/MacOS/" || true; \
		rm -rf "$(LEGACY_APP)"; \
		echo "Removed legacy $(LEGACY_APP)"; \
	fi
	@# Refresh LaunchServices so Spotlight shows the new bundle and icon
	@$(LSREGISTER) -f "$(INSTALLED_APP)"
	@echo "Installed $(DISPLAY_NAME) to $(INSTALLED_APP)"

# Sign, notarize and package DMG + ZIP into dist/ (needs APPLE_* env vars, see scripts/release.sh)
release:
	./scripts/release.sh

# Regenerate AppIcon.icns and the menu icon from assets/logo/*.svg (needs brew install librsvg)
icons:
	./scripts/build-icons.sh

run: install
	@open "$(INSTALLED_APP)"

clean:
	swift package clean
	@rm -rf "$(BUILD_DIR)/TypeAny.app" "$(BUILD_DIR)/TypeAnyDev.app" "$(RIME_DATA)" dist
	@echo "Clean complete"
