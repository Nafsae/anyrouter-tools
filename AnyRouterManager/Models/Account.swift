import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String?
    var apiUser: String
    var provider: String
    var isEnabled: Bool
    var createdAt: Date

    init(name: String, email: String? = nil, apiUser: String, provider: String = "anyrouter", isEnabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.apiUser = apiUser
        self.provider = provider
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }
}
