import Foundation
import Observation

struct TranslationRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let original: String
    let translation: String
    let sourceLanguage: String
    let targetLanguage: String
}

@MainActor @Observable
final class TranslationHistory {
    static let shared = TranslationHistory()
    static let defaultsKey = "recentTranslations"
    private(set) var entries: [TranslationRecord] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
            let saved = try? JSONDecoder().decode([TranslationRecord].self, from: data)
        {
            entries = Array(saved.prefix(5))
        }
    }

    func add(original: String, translation: String, sourceLanguage: String, targetLanguage: String) {
        guard !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        entries.removeAll {
            $0.original == original && $0.sourceLanguage == sourceLanguage && $0.targetLanguage == targetLanguage
        }
        entries.insert(
            TranslationRecord(
                id: UUID(), original: original, translation: translation,
                sourceLanguage: sourceLanguage, targetLanguage: targetLanguage), at: 0)
        entries = Array(entries.prefix(5))
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    func clear() {
        entries = []
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
