import Foundation

/// Reads and writes the save file in Application Support. Corrupt files are moved aside
/// (never silently overwritten) and the game starts from a fresh save.
enum SaveManager {
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("vliz_save.json")
    }

    static func load() -> SaveData {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return SaveData() }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SaveData.self, from: data)
        } catch {
            let backup = url.deletingLastPathComponent().appendingPathComponent("vliz_save.corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            print("[SaveManager] Save unreadable, starting fresh: \(error)")
            return SaveData()
        }
    }

    static func save(_ data: SaveData) {
        let url = fileURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: [.atomic])
        } catch {
            print("[SaveManager] Failed to save: \(error)")
        }
    }

    static func erase() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
