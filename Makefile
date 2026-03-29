APP_NAME = TypeAny
BUILD_DIR = .build
RELEASE_BIN = $(BUILD_DIR)/release/$(APP_NAME)
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR = /Applications

.PHONY: build run install clean

build:
	swift build -c release
	@echo "Creating app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(RELEASE_BIN)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "Sources/TypeAny/Resources/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	@codesign --force --sign - "$(APP_BUNDLE)"
	@echo "Build complete: $(APP_BUNDLE)"

run: build
	@open "$(APP_BUNDLE)"

install: build
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

clean:
	swift package clean
	@rm -rf "$(APP_BUNDLE)"
	@echo "Clean complete"
