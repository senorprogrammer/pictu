# Pictu Makefile
# Builds and installs the Pictu macOS app

# Configuration
APP_NAME = Pictu
BUILD_DIR = build
APPLICATIONS_DIR = $(HOME)/Applications
XCODE_PROJECT = Pictu.xcodeproj
SCHEME = Pictu
CONFIGURATION = Release

# Linting and analysis tools
SWIFTLINT  ?= $(shell command -v swiftlint 2>/dev/null || echo /opt/homebrew/bin/swiftlint)
SWIFTFORMAT?= $(shell command -v swiftformat 2>/dev/null || echo /opt/homebrew/bin/swiftformat)

# Derived paths
APP_BUNDLE = $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app
INSTALLED_APP = $(APPLICATIONS_DIR)/$(APP_NAME).app

# Default target
.PHONY: all
all: install

# Linting and analysis targets
.PHONY: tools lint format analyze ci

# Build the project
.PHONY: build
build:
	@echo "🔨 Building $(APP_NAME)..."
	@if [ ! -d "$(XCODE_PROJECT)" ]; then \
		echo "❌ Error: Xcode project not found at $(XCODE_PROJECT)"; \
		exit 1; \
	fi
	@xcodebuild -project $(XCODE_PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) \
		build || (echo "❌ Build failed" && exit 1)
	@if [ ! -d "$(APP_BUNDLE)" ]; then \
		echo "❌ Error: App bundle not found at $(APP_BUNDLE)"; \
		exit 1; \
	fi
	@echo "✅ Build complete"

# Install the app to Applications directory
.PHONY: install
install: build
	@echo "📦 Installing $(APP_NAME) to $(APPLICATIONS_DIR)..."
	@mkdir -p $(APPLICATIONS_DIR)
	@if [ -d "$(INSTALLED_APP)" ]; then \
		echo "🔄 Overwriting existing version..."; \
		rm -rf "$(INSTALLED_APP)"; \
	fi
	@cp -R "$(APP_BUNDLE)" "$(INSTALLED_APP)"
	@echo "✅ Installation complete"
	@echo "🚀 Running $(APP_NAME)..."
	@open "$(INSTALLED_APP)"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "✅ Clean complete"

# Uninstall the app
.PHONY: uninstall
uninstall:
	@echo "🗑️  Uninstalling $(APP_NAME)..."
	@rm -rf "$(INSTALLED_APP)"
	@echo "✅ Uninstall complete"

# Install linting and formatting tools
tools:
	@echo "🔧 Installing SwiftLint and SwiftFormat..."
	@brew list swiftlint  >/dev/null 2>&1 || brew install swiftlint
	@brew list swiftformat>/dev/null 2>&1 || brew install swiftformat
	@echo "✅ Tools installation complete"

# Run SwiftLint (strict, fail on warnings)
lint:
	@echo "🔍 Running SwiftLint..."
	@if [ ! -x "$(SWIFTLINT)" ]; then echo "❌ swiftlint not found. Run 'make tools'."; exit 1; fi
	@$(SWIFTLINT) --quiet --strict --reporter xcode
	@echo "✅ Linting complete"

# Run SwiftFormat (in-place)
format:
	@echo "🎨 Formatting code with SwiftFormat..."
	@if [ ! -x "$(SWIFTFORMAT)" ]; then echo "❌ swiftformat not found. Run 'make tools'."; exit 1; fi
	@$(SWIFTFORMAT) .
	@echo "✅ Formatting complete"

# Run Xcode static analyzer
analyze:
	@echo "🔬 Running static analysis..."
	@set -euo pipefail; \
	if [ -f "$(XCODE_PROJECT)" ]; then \
	  xcodebuild -project "$(XCODE_PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" clean build analyze | xcbeautify || true; \
	else \
	  echo "❌ Xcode project not found at $(XCODE_PROJECT)"; \
	  exit 1; \
	fi
	@echo "✅ Analysis complete"

# CI pipeline: lint + analyze
ci: lint analyze
	@echo "✅ CI pipeline complete"

# Show help
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build     - Build the project"
	@echo "  install   - Build, install, and run the app"
	@echo "  clean     - Clean build artifacts"
	@echo "  uninstall - Remove the installed app"
	@echo "  tools     - Install SwiftLint and SwiftFormat"
	@echo "  lint      - Run SwiftLint (strict, fail on warnings)"
	@echo "  format    - Run SwiftFormat (in-place)"
	@echo "  analyze   - Run Xcode static analyzer"
	@echo "  ci        - Run lint + analyze (for CI)"
	@echo "  help      - Show this help message"
