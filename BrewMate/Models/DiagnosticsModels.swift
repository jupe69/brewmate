import Foundation

/// Information about Homebrew disk usage
struct DiskUsageInfo {
    let cacheSize: Int64
    let cellarSize: Int64
    let caskroomSize: Int64
    let totalSize: Int64

    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }

    var formattedCellarSize: String {
        ByteCountFormatter.string(fromByteCount: cellarSize, countStyle: .file)
    }

    var formattedCaskroomSize: String {
        ByteCountFormatter.string(fromByteCount: caskroomSize, countStyle: .file)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}
