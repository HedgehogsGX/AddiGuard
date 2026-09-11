import Foundation

enum PopulationGroup: String, Codable, CaseIterable, Identifiable {
    case general
    case child
    case pregnant
    case chronicCondition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "成人"
        case .child: "儿童"
        case .pregnant: "孕期"
        case .chronicCondition: "慢病"
        }
    }

    var symbol: String {
        switch self {
        case .general: "person"
        case .child: "figure.and.child.holdinghands"
        case .pregnant: "heart.circle"
        case .chronicCondition: "cross.case"
        }
    }
}

struct UserProfile: Codable, Equatable {
    var populationGroup: PopulationGroup = .general
    var allergySensitive = false
    var prefersStricterWarnings = true
}

