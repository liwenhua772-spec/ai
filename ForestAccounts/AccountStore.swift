import Foundation
import Combine

enum ChatPlatform: String, Codable, CaseIterable, Identifiable {
    case whatsapp, telegram
    var id: String { rawValue }
    var title: String { self == .whatsapp ? "WhatsApp" : "Telegram" }
    var address: URL {
        URL(string: self == .whatsapp ? "https://web.whatsapp.com/" : "https://web.telegram.org/k/")!
    }
    func contains(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        let domain = self == .whatsapp ? "whatsapp.com" : "telegram.org"
        return host == domain || host.hasSuffix("." + domain)
    }
}

struct ChatAccount: Identifiable, Codable, Equatable {
    // This UUID is also the persistent WebKit profile identifier. Never regenerate on a switch.
    let id: UUID
    let platform: ChatPlatform
    var name: String
}

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [ChatAccount] = []
    @Published private(set) var storageError: String?
    private let file: URL

    init() {
        file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ForestTranslateIOS", isDirectory: true)
            .appendingPathComponent("accounts.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let loaded = try JSONDecoder().decode([ChatAccount].self, from: Data(contentsOf: file))
            guard Set(loaded.map(\.id)).count == loaded.count,
                  ChatPlatform.allCases.allSatisfy({ platform in loaded.filter { $0.platform == platform }.count <= 3 }) else {
                throw AccountError.invalidStorage
            }
            accounts = loaded
        } catch {
            // Preserve a damaged registry rather than lose the profile IDs and orphan existing logins.
            storageError = "账号目录读取失败。原文件已保留，已停止新增账号，请先恢复目录。"
        }
    }

    func forPlatform(_ platform: ChatPlatform) -> [ChatAccount] {
        accounts.filter { $0.platform == platform }
    }

    func add(_ platform: ChatPlatform) throws -> ChatAccount {
        guard storageError == nil else { throw AccountError.storageUnavailable }
        guard forPlatform(platform).count < 3 else { throw AccountError.limit }
        let number = (1...3).first { candidate in !forPlatform(platform).contains { $0.name == "\(platform.title) \(candidate)" } } ?? 3
        let account = ChatAccount(id: UUID(), platform: platform, name: "\(platform.title) \(number)")
        let next = accounts + [account]
        try persist(next)
        accounts = next
        return account
    }

    func rename(_ account: ChatAccount, name: String) throws {
        guard storageError == nil else { throw AccountError.storageUnavailable }
        let value = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !value.isEmpty else { throw AccountError.emptyName }
        var next = accounts
        guard let index = next.firstIndex(where: { $0.id == account.id }) else { throw AccountError.invalidStorage }
        next[index].name = value
        try persist(next)
        accounts = next
    }

    private func persist(_ next: [ChatAccount]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoded = try JSONEncoder().encode(next)
        try encoded.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

enum AccountError: LocalizedError {
    case limit, emptyName, invalidStorage, storageUnavailable
    var errorDescription: String? {
        switch self {
        case .limit: return "每个平台最多保留 3 个独立账号入口。"
        case .emptyName: return "请输入账号名称。"
        case .invalidStorage: return "账号目录格式异常。"
        case .storageUnavailable: return "账号目录暂不可用，原登录数据没有被清除。"
        }
    }
}
