import Foundation
import SwiftData

enum AnyRouterSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Account.self] }

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
}

enum AnyRouterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AnyRouterSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

typealias Account = AnyRouterSchemaV1.Account
