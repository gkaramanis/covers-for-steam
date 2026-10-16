import Foundation

/// App types from Steam's appcache/appinfo.vdf, such as Game, Demo, Tool or
/// Application. Reads versions 28 and 29 of its binary format. Any other
/// version, or a file that cannot be read, gives nil, and callers then keep
/// every app.
enum AppInfo {
    static func types(for appIDs: Set<Int>, in url: URL) -> [Int: String]? {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return nil }
        return data.withUnsafeBytes { bytes in
            var reader = Reader(bytes: bytes)
            guard let magic = try? reader.u32(), (try? reader.u32()) != nil else { return nil }

            // Version 29 keys are indices into a string table at the end of
            // the file; version 28 keys are inline strings.
            var keys: [String]?
            var end = bytes.count
            switch magic {
            case 0x0756_4429:
                guard let offset = try? reader.u64(), offset < bytes.count else { return nil }
                end = Int(offset)
                var table = Reader(bytes: bytes, position: end)
                guard let count = try? table.u32(),
                      let strings = try? (0..<count).map({ _ in try table.string() })
                else { return nil }
                keys = strings
            case 0x0756_4428:
                break
            default:
                return nil
            }

            var types: [Int: String] = [:]
            while reader.position + 8 <= end {
                guard let appID = try? reader.u32(), appID != 0, let size = try? reader.u32() else { break }
                let next = reader.position + Int(size)
                if appIDs.contains(Int(appID)) {
                    // Skip info state, last update, access token, SHA-1,
                    // change number and binary SHA-1.
                    var entry = Reader(bytes: bytes, position: reader.position + 60, end: next)
                    if let type = try? entry.commonType(keys: keys) {
                        types[Int(appID)] = type
                    }
                }
                reader.position = next
            }
            return types
        }
    }
}

private struct Reader {
    struct Truncated: Error {}

    let bytes: UnsafeRawBufferPointer
    var position = 0
    var end: Int

    init(bytes: UnsafeRawBufferPointer, position: Int = 0, end: Int? = nil) {
        self.bytes = bytes
        self.position = position
        self.end = min(end ?? bytes.count, bytes.count)
    }

    mutating func skip(_ count: Int) throws {
        guard position + count <= end else { throw Truncated() }
        position += count
    }

    mutating func u8() throws -> UInt8 {
        try skip(1)
        return bytes[position - 1]
    }

    mutating func u32() throws -> UInt32 {
        try skip(4)
        return UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: position - 4, as: UInt32.self))
    }

    mutating func u64() throws -> UInt64 {
        try skip(8)
        return UInt64(littleEndian: bytes.loadUnaligned(fromByteOffset: position - 8, as: UInt64.self))
    }

    mutating func string() throws -> String {
        let start = position
        while try u8() != 0 {}
        return String(decoding: UnsafeRawBufferPointer(rebasing: bytes[start..<position - 1]), as: UTF8.self)
    }

    /// Walks one app's binary KeyValues and returns common/type.
    mutating func commonType(keys: [String]?) throws -> String? {
        var path: [String] = []
        while true {
            let kind = try u8()
            if kind == 8 {
                guard !path.isEmpty else { return nil }
                path.removeLast()
                continue
            }
            let key: String
            if let keys {
                let index = Int(try u32())
                guard index < keys.count else { throw Truncated() }
                key = keys[index]
            } else {
                key = try string()
            }

            switch kind {
            case 0:
                path.append(key)
            case 1:
                let value = try string()
                if key == "type", path.last == "common", path.count <= 2 { return value }
            case 2, 3, 4, 6:
                try skip(4)
            case 7, 10:
                try skip(8)
            default:
                throw Truncated()
            }
        }
    }
}
