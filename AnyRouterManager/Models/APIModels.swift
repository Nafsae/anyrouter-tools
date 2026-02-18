import Foundation

// MARK: - User Info Response

struct UserInfoResponse: Decodable {
    let success: Bool
    let data: UserData?

    struct UserData: Decodable {
        let id: Int?
        let username: String?
        let displayName: String?
        let email: String?
        let quota: Int
        let usedQuota: Int

        enum CodingKeys: String, CodingKey {
            case id, username, email, quota
            case displayName = "display_name"
            case usedQuota = "used_quota"
        }

        var bestName: String? {
            displayName ?? username ?? email
        }
    }
}

// MARK: - Check-In Response

struct CheckInResponse: Decodable {
    let ret: Int?
    let code: Int?
    let success: Bool?
    let msg: String?
    let message: String?

    var isSuccess: Bool {
        ret == 1 || code == 0 || success == true
    }

    var errorMessage: String {
        msg ?? message ?? "Unknown error"
    }

    var isAlreadyCheckedIn: Bool {
        let keywords = ["已经签到", "已签到", "重复签到", "already checked", "already signed"]
        let text = errorMessage.lowercased()
        return keywords.contains(where: { text.contains($0) })
    }
}

// MARK: - Account Runtime State

enum AccountStatus: Equatable {
    case idle
    case refreshing
    case checkingIn
    case success(String?)
    case error(String)
}

@Observable
final class AccountRuntimeState {
    var quota: Double = 0
    var usedQuota: Double = 0
    var balance: Double { quota }
    var totalQuota: Double { quota + usedQuota }
    var status: AccountStatus = .idle
    var lastRefreshDate: Date?
    var lastCheckInDate: Date?

    var statusText: String {
        switch status {
        case .idle: "就绪"
        case .refreshing: "刷新中…"
        case .checkingIn: "签到中…"
        case .success(let msg): msg ?? "成功"
        case .error(let msg): msg
        }
    }

    var isLoading: Bool {
        switch status {
        case .refreshing, .checkingIn: true
        default: false
        }
    }
}
