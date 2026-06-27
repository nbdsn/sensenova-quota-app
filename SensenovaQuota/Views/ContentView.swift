import SwiftUI

struct ContentView: View {
    @StateObject private var store = AccountStore()
    @State private var showAddSheet = false
    @State private var showKeyPopover: Account?
    
    var body: some View {
        NavigationStack {
            List {
                if store.accounts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "key.icloud")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("还没有添加账号")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击右上角 + 添加 SenseNova 账号和 API Key")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                }
                
                ForEach(store.accounts) { account in
                    AccountRow(account: account)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = account.apiKey
                            } label: {
                                Label("复制 Key", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                withAnimation {
                                    store.deleteAccount(account)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            showKeyPopover = account
                        }
                }
                .onDelete { offsets in
                    store.deleteAccount(at: offsets)
                }
                
                if !store.accounts.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            Text(store.summaryText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("SenseNova 余量查询")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        if store.isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Button {
                            Task {
                                await store.checkAllAccounts()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(store.isChecking || store.accounts.isEmpty)
                        
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .refreshable {
                await store.checkAllAccounts()
            }
            .sheet(isPresented: $showAddSheet) {
                AddAccountView { username, key in
                    store.addAccount(username: username, apiKey: key)
                }
            }
            .sheet(item: $showKeyPopover) { account in
                NavigationStack {
                    KeyDetailView(account: account)
                }
            }
        }
    }
}

struct AccountRow: View {
    let account: Account
    
    var statusIcon: String {
        switch account.lastStatus {
        case .untested: return "questionmark.circle"
        case .active: return "checkmark.circle.fill"
        case .inactive: return "xmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }
    
    var statusColor: Color {
        switch account.lastStatus {
        case .untested: return .gray
        case .active: return .green
        case .inactive: return .red
        case .error: return .orange
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundColor(statusColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(account.username)
                    .font(.headline)
                Text(account.maskedKey)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospaced()
                if let time = account.lastCheckTime {
                    Text("上次检测: \(time.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let error = account.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Text(account.lastStatus.description)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 4)
    }
}

struct KeyDetailView: View {
    let account: Account
    @State private var showKey = false
    @State private var copied = false
    
    var body: some View {
        List {
            Section("账号信息") {
                LabeledContent("用户名", value: account.username)
                LabeledContent("状态") {
                    Text(account.lastStatus.description)
                        .foregroundColor(account.lastStatus == .active ? .green : .red)
                }
                if let time = account.lastCheckTime {
                    LabeledContent("上次检测", value: time.formatted(date: .long, time: .standard))
                }
                if let error = account.lastError {
                    LabeledContent("错误信息", value: error)
                }
            }
            
            Section("API Key") {
                HStack {
                    if showKey {
                        Text(account.apiKey)
                            .monospaced()
                            .font(.caption)
                    } else {
                        Text(account.maskedKey)
                            .monospaced()
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                
                Button {
                    showKey.toggle()
                } label: {
                    Label(showKey ? "隐藏 Key" : "显示完整 Key", systemImage: showKey ? "eye.slash" : "eye")
                }
                
                Button {
                    UIPasteboard.general.string = account.apiKey
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "已复制" : "复制 Key", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    // handled by parent dismiss
                } label: {
                    Label("删除此账号", systemImage: "trash")
                }
            }
        }
        .navigationTitle(account.username)
    }
}

#Preview {
    ContentView()
}