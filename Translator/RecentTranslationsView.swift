import SwiftUI

struct RecentTranslationsView: View {
    let entries: [TranslationRecord]
    let onSelect: (TranslationRecord) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent translations").font(.subheadline.weight(.medium))
                Spacer()
                if !entries.isEmpty {
                    Button("Clear history", action: onClear)
                        .buttonStyle(.link)
                        .help("Delete all saved translations from this Mac")
                }
            }
            if entries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your last five translations appear here.")
                    Text("English → Portuguese · Other languages → English")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(entries) { entry in
                            Button {
                                onSelect(entry)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.original).lineLimit(1)
                                        Text(entry.translation).lineLimit(1)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.right")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                }
                                .padding(8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Open saved translation")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
