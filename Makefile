.PHONY: project build test lint

project:
	xcodegen generate

build: project
	xcodebuild -scheme Translator -configuration Debug -derivedDataPath build build

test: project
	xcodebuild -scheme Translator -destination 'platform=macOS' -derivedDataPath build test
	bash scripts/test-install.sh

lint:
	xcrun swift-format lint --strict --recursive Translator TranslatorTests
	@for file in scripts/*.sh; do bash -n "$$file" || exit $$?; done
