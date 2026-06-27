import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testResult: AccountStatus?
    @State private var testError: String?
    
    let onSave: (String, String) -> Void
    
    var canSave: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty &&
        apiKey.count > 20
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("账号信息") {
                    TextField("用户名", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .monospaced()
                }
                
                if !apiKey.isEmpty {
                    Section("Key 预览") {
                        HStack {
                            Text(apiKey.prefix(12) + "...")
                                .monospaced()
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(apiKey.count) 字符")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button {
                        Task {
                            await testKey()
                        }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isTesting ? "检测中..." : "检测 Key 可用性")
                        }
                    }
                    .disabled(apiKey.isEmpty || isTesting)
                    
                    if let result = testResult {
                        HStack {
                            Image(systemName: result == .active ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result == .active ? .green : .red)
                            Text(result == .active ? "Key 可用 ✅" : "Key 无效 ❌")
                            if let error = testError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        let name = username.trimmingCharacters(in: .whitespaces)
                        let key = apiKey.trimmingCharacters(in: .whitespaces)
                        onSave(name, key)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("保存账号")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                    .foregroundColor(canSave ? .accentColor : .gray)
                }
            }
            .navigationTitle("添加账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    func testKey() async {
        isTesting = true
        testResult = nil
        testError = nil
        
        let (status, error) = await SensenovaService.checkKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        
        testResult = status
        testError = error
        isTesting = false
    }
}