import Foundation

/// How the covers are shown.
enum DisplayMode: String, CaseIterable {
    case wall
    case origami

    var title: String {
        switch self {
        case .wall: "Wall"
        case .origami: "Origami"
        }
    }

    /// Seconds between changes.
    var interval: TimeInterval {
        switch self {
        case .wall: 3
        case .origami: 5
        }
    }
}
