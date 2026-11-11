import XCTest

@testable import Translator

@MainActor
final class HistoryTests: XCTestCase {
    private func withHistory(_ body: (TranslationHistory, UserDefaults) throws -> Void) rethrows {
        let name = "TranslatorHistoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(TranslationHistory(defaults: defaults), defaults)
    }

    private func add(_ number: Int, to history: TranslationHistory) {
        history.add(
            original: "Source \(number)", translation: "Result \(number)", sourceLanguage: "en", targetLanguage: "pt")
    }

    func testKeepsOnlyFiveNewestTranslations() {
        withHistory { history, _ in
            for number in 1...7 { add(number, to: history) }
            XCTAssertEqual(
                history.entries.map(\.original), ["Source 7", "Source 6", "Source 5", "Source 4", "Source 3"])
        }
    }

    func testHistorySurvivesNewStoreInstance() {
        withHistory { history, defaults in
            add(1, to: history)
            let reloaded = TranslationHistory(defaults: defaults)
            XCTAssertEqual(reloaded.entries, history.entries)
            XCTAssertEqual(reloaded.entries.first?.translation, "Result 1")
            XCTAssertEqual(reloaded.entries.first?.sourceLanguage, "en")
            XCTAssertEqual(reloaded.entries.first?.targetLanguage, "pt")
        }
    }

    func testRepeatedTextMovesToTopAndUpdatesResult() {
        withHistory { history, _ in
            add(1, to: history)
            add(2, to: history)
            history.add(original: "Source 1", translation: "Updated", sourceLanguage: "en", targetLanguage: "pt")
            XCTAssertEqual(history.entries.map(\.original), ["Source 1", "Source 2"])
            XCTAssertEqual(history.entries.first?.translation, "Updated")
        }
    }

    func testDifferentLanguageDirectionsAreSeparateEntries() {
        withHistory { history, _ in
            add(1, to: history)
            history.add(original: "Source 1", translation: "Other", sourceLanguage: "en", targetLanguage: "es")
            XCTAssertEqual(history.entries.count, 2)
        }
    }

    func testClearRemovesStoredHistory() {
        withHistory { history, defaults in
            add(1, to: history)
            history.clear()
            XCTAssertTrue(history.entries.isEmpty)
            XCTAssertTrue(TranslationHistory(defaults: defaults).entries.isEmpty)
            XCTAssertNil(defaults.data(forKey: TranslationHistory.defaultsKey))
        }
    }

    func testEmptyTextOrResultIsNotStored() {
        withHistory { history, defaults in
            history.add(original: " \n", translation: "Result", sourceLanguage: "en", targetLanguage: "pt")
            history.add(original: "Source", translation: " \n", sourceLanguage: "en", targetLanguage: "pt")
            XCTAssertTrue(history.entries.isEmpty)
            XCTAssertNil(defaults.data(forKey: TranslationHistory.defaultsKey))
        }
    }

    func testUnreadableHistoryDoesNotCrashAndNextSuccessReplacesIt() {
        withHistory { _, defaults in
            defaults.set(Data("not JSON".utf8), forKey: TranslationHistory.defaultsKey)
            let history = TranslationHistory(defaults: defaults)
            XCTAssertTrue(history.entries.isEmpty)
            add(1, to: history)
            XCTAssertEqual(TranslationHistory(defaults: defaults).entries.count, 1)
        }
    }
}
