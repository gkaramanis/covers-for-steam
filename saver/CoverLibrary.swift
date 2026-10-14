import Foundation
import os

/// Finds cover images in Steam's local library cache.
enum CoverLibrary {
    static let log = Logger(subsystem: "local.covers-for-steam", category: "library")

    static var cacheURL: URL {
        // Inside legacyScreenSaver, NSHomeDirectory() is the sandbox container.
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home)
            .appending(path: "Library/Application Support/Steam/appcache/librarycache", directoryHint: .isDirectory)
    }

    /// One cover per app ID. Some covers sit in hashed subfolders, so each
    /// app folder is searched and the largest file wins. Steam saves its
    /// generated covers as PNG under a .jpg name; real covers are JPEG.
    static func coverURLs(includeGenerated: Bool) -> [URL] {
        let fileManager = FileManager.default
        let apps: [URL]
        do {
            apps = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
        } catch {
            log.error("Cannot list \(cacheURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }

        let covers = apps.compactMap { app -> URL? in
            guard Int(app.lastPathComponent) != nil,
                  let files = fileManager.enumerator(at: app, includingPropertiesForKeys: [.fileSizeKey])
            else { return nil }

            var best: (url: URL, size: Int)?
            for case let file as URL in files where file.lastPathComponent == "library_600x900.jpg" {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                if size > best?.size ?? -1 { best = (file, size) }
            }
            guard let url = best?.url, includeGenerated || !isPNG(url) else { return nil }
            return url
        }

        log.notice("Found \(covers.count, privacy: .public) covers in \(apps.count, privacy: .public) app folders")
        return covers
    }

    private static func isPNG(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let signature = (try? handle.read(upToCount: 4)) ?? Data()
        return signature == Data([0x89, 0x50, 0x4E, 0x47])
    }
}
