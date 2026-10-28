import SwiftUI

@main
struct ForestAccountsApp: App {
    @StateObject private var accounts = AccountStore()
    @StateObject private var browsers = BrowserPool()
    var body: some Scene {
        WindowGroup { AccountList().environmentObject(accounts).environmentObject(browsers) }
    }
}

struct AccountList: View {
    @EnvironmentObject private var accounts: AccountStore
    @EnvironmentObject private var browsers: BrowserPool
    @State private var selected: ChatAccount.ID?
    @State private var errorMessage: String?
    @State private var renaming: ChatAccount?
    @State private var newName = ""
    @State private var showingInfo = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                Section {
                    Label("iPhone 独立登录验证", systemImage: "leaf.fill").foregroundStyle(.green)
                    Text("目标：WhatsApp 3 个＋Telegram 3 个账号。仅验证登录和隔离，尚未验证 WhatsApp 兼容性；当前不含翻译。")
                        .font(.caption).foregroundStyle(.secondary)
                    if let issue = accounts.storageError { Text(issue).font(.caption).foregroundStyle(.red) }
                }
                ForEach(ChatPlatform.allCases) { platform in
                    Section {
                        ForEach(accounts.forPlatform(platform)) { account in
                            NavigationLink(value: account.id) {
                                HStack {
                                    Image(systemName: platform == .whatsapp ? "phone.bubble.fill" : "paperplane.fill")
                                        .foregroundStyle(platform == .whatsapp ? Color.green : Color.blue)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(account.name).font(.headline)
                                        Text("独立登录空间 · 登录状态请打开查看").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }.padding(.vertical, 5)
                            }.contextMenu {
                                Button("重命名") { renaming = account; newName = account.name }
                            }
                        }
                        Button {
                            do { let account = try accounts.add(platform); selected = account.id }
                            catch { errorMessage = error.localizedDescription }
                        } label: { Label("添加 \(platform.title) 账号", systemImage: "plus.circle.fill") }
                            .disabled(accounts.forPlatform(platform).count >= 3 || accounts.storageError != nil)
                    } header: {
                        Text("\(platform.title) · \(accounts.forPlatform(platform).count)/3")
                    }
                }
                Section {
                    Text("本工程不需要电脑连接服务。网页仍需要联网；切到后台后不保证消息接收和提示音。请通过平台网页自身的菜单退出账号。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("森林翻译")
            .toolbar { Button { showingInfo = true } label: { Image(systemName: "info.circle") } }
        } detail: {
            if let id = selected, let account = accounts.accounts.first(where: { $0.id == id }) {
                AccountPage(account: account, session: browsers.session(for: account)).id(account.id)
            } else {
                ContentUnavailableView("选择或添加账号", systemImage: "person.crop.circle.badge.plus", description: Text("每个平台使用最多 3 个独立登录空间。"))
            }
        }
        .tint(.green)
        .alert("操作未完成", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("知道了") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert("重命名账号", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("名称", text: $newName)
            Button("保存") {
                if let account = renaming {
                    do { try accounts.rename(account, name: newName) }
                    catch { errorMessage = error.localizedDescription }
                }
                renaming = nil
            }
            Button("取消", role: .cancel) { renaming = nil }
        }
        .sheet(isPresented: $showingInfo) {
            NavigationStack {
                List {
                    Section("当前阶段") {
                        Text("这是原生 iOS 17+ 登录验证版，尚未经过 iPhone 实机验证。6 个入口不等于 6 个账号已经登录成功。")
                        Text("每个入口使用独立的持久化 WebKit 数据存储。WhatsApp 是否允许加载、扫码、登录和保持会话，必须分别在真机上验证。")
                    }
                    Section("账号与数据") {
                        Text("账号凭证由平台网页和 iOS WebKit 管理。程序没有复制 Windows 登录数据、导出 Cookie、上传联系人或使用公共服务器。没有注入自动发送或翻译脚本。")
                        Text("仅退出或重开页面不会主动清除登录数据。卸载应用会移除本机应用数据；平台也可能要求重新登录。")
                    }
                    Section("尚未实现") {
                        Text("文字翻译、发送前拦截、语音视频翻译、后台消息推送及正式上架分发。需要先确认两个平台各 3 个账号的登录和切换可靠。")
                    }
                }
                .navigationTitle("登录验证说明").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("完成") { showingInfo = false } }
            }
        }
    }
}
