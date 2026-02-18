import Foundation

enum Constants {
    static let quotaDivisor: Double = 500_000
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"
    static let maxConcurrentRequests = 3
    static let wafCookieCacheDuration: TimeInterval = 30 * 60 // 30 min
    static let alreadyCheckedKeywords = ["已经签到", "已签到", "重复签到", "already checked", "already signed"]

    enum Defaults {
        static let refreshInterval: TimeInterval = 15 * 60 // 15 min
    }
}
