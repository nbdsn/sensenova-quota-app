import Foundation

struct Account: Identifiable, Codable {
    let id: UUID
    var username: String
    var apiKey: String
    var lastCheckTime: Date?
    var lastStatus: AccountStatus
    var lastError: String?
    
    init(id: UUID = UUID(), username: String, apiKey: String) {
        self.id = id
        self.username = username
        self.apiKey = apiKey
        self.lastStatus = .untested
    }
    
    var maskedKey: String {
        guard apiKey.count > 8 else { return apiKey }
        let prefix = String(apiKey.prefix(8))
        let suffix = String(apiKey.suffix(4))
        return "\(prefix)...\(suffix)"
    }
}

enum AccountStatus: String, Codable, CustomStringConvertible {
    case untested = "未测试"
    case active = "可用"
    case inactive = "无效"
    case error = "错误"
    
    var description: String { rawValue }
    
    var color: String {
        switch self {
        case .untested: return "gray"
        case .active: return "green"
        case .inactive: return "red"
        case .error: return "orange"
        }
    }
}

class AccountStore: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var isChecking: Bool = false
    
    private let storageKey = "saved_accounts"
    
    init() {
        load()
    }
    
    func addAccount(username: String, apiKey: String) {
        let account = Account(username: username, apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        accounts.append(account)
        save()
    }
    
    func deleteAccount(at offsets: IndexSet) {
        accounts.remove(atOffsets: offsets)
        save()
    }
    
    func deleteAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        save()
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = decoded
        }
    }
    
    @MainActor
    func checkAllAccounts() async {
        isChecking = true
        defer { isChecking = false }
        
        await withTaskGroup(of: (Int, AccountStatus, String?).self) { group in
            for (index, account) in accounts.enumerated() {
                group.addTask {
                    let (status, error) = await SensenovaService.checkKey(account.apiKey)
                    return (index, status, error)
                }
            }
            
            var updatedAccounts = accounts
            for await (index, status, error) in group {
                guard index < updatedAccounts.count else { continue }
                updatedAccounts[index].lastStatus = status
                updatedAccounts[index].lastCheckTime = Date()
                updatedAccounts[index].lastError = error
            }
            
            accounts = updatedAccounts
            save()
        }
    }
    
    var summaryText: String {
        let total = accounts.count
        let active = accounts.filter { $0.lastStatus == .active }.count
        let inactive = accounts.filter { $0.lastStatus == .inactive || $0.lastStatus == .error }.count
        let untested = accounts.filter { $0.lastStatus == .untested }.count
        return "共\(total)个 · ✅\(active) · ❌\(inactive) · ⏳\(untested)"
    }
}
