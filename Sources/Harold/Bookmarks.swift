import SwiftUI

struct Bookmark: Codable, Identifiable {
    var id: URL { url }
    let url: URL
    let title: String
}

@MainActor
final class Bookmarks: ObservableObject {
    @Published private(set) var entries: [Bookmark]

    private let defaults: UserDefaults
    private static let key = "harold.bookmarks"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Bookmark].self, from: data) {
            entries = saved
        } else {
            entries = []
        }
    }

    func contains(_ url: URL) -> Bool {
        entries.contains { $0.url == url }
    }

    func toggle(_ url: URL, title: String?) {
        if contains(url) {
            remove(url)
        } else {
            let name = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            entries.insert(Bookmark(url: url, title: name.isEmpty ? url.host ?? url.absoluteString : name), at: 0)
            save()
        }
    }

    func remove(_ url: URL) {
        entries.removeAll { $0.url == url }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
