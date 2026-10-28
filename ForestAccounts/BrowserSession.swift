import SwiftUI
import WebKit
import Combine

@MainActor
final class BrowserSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private let account: ChatAccount
    private var observations: [NSKeyValueObservation] = []
    private var started = false
    @Published var progress: Double = 0
    @Published var message = "等待打开官方登录页面"
    @Published var canGoBack = false
    @Published var errorMessage: String?
    @Published var externalURL: URL?

    init(account: ChatAccount) {
        self.account = account
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: account.id)
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = false
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                let value = view.estimatedProgress
                DispatchQueue.main.async { self?.progress = value }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                let value = view.canGoBack
                DispatchQueue.main.async { self?.canGoBack = value }
            }
        ]
    }

    func openIfNeeded() {
        guard !started else { return }
        started = true
        webView.load(URLRequest(url: account.platform.address))
    }

    func reload() {
        errorMessage = nil
        if let url = webView.url, account.platform.contains(url) { webView.reload() }
        else { webView.load(URLRequest(url: account.platform.address)) }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        message = "正在加载 \(account.platform.title) 官方网页…"
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Document load is not proof that the person successfully authenticated.
        message = "页面已加载；请在网页中确认登录状态"
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    private func failed(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        errorMessage = "网页加载失败（错误码 \((error as NSError).code)）。请检查网络，或确认该网站是否支持此 iPhone 内置浏览器。"
        message = "未完成加载，登录数据没有被清除"
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        errorMessage = "网页进程已被系统结束，点击刷新可重新打开；不会自动清空账号登录数据。"
        message = "网页已暂停"
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard action.targetFrame?.isMainFrame != false, let url = action.request.url else {
            decisionHandler(.allow); return
        }
        if url.absoluteString == "about:blank" || account.platform.contains(url) {
            decisionHandler(.allow); return
        }
        if action.navigationType == .linkActivated, url.scheme == "https" {
            externalURL = url
        } else {
            errorMessage = "已停止跳转到平台以外的页面。账号仍保留在当前独立登录空间。"
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard action.targetFrame == nil, let url = action.request.url else { return nil }
        if account.platform.contains(url) { webView.load(action.request) }
        else if action.navigationType == .linkActivated, url.scheme == "https" { externalURL = url }
        return nil
    }
}

@MainActor
final class BrowserPool: ObservableObject {
    private var sessions: [UUID: BrowserSession] = [:]
    func session(for account: ChatAccount) -> BrowserSession {
        if let existing = sessions[account.id] { return existing }
        let session = BrowserSession(account: account)
        sessions[account.id] = session
        return session
    }
}

struct BrowserSurface: UIViewRepresentable {
    let session: BrowserSession
    func makeUIView(context: Context) -> WKWebView { session.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct AccountPage: View {
    let account: ChatAccount
    @ObservedObject var session: BrowserSession
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(session.message).font(.caption).foregroundStyle(.secondary)
                Text("独立登录验证版 · 网站兼容性与登录持久化待真机确认")
                    .font(.caption2).foregroundStyle(.orange)
                if let error = session.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(.thinMaterial)
            if session.progress > 0 && session.progress < 1 {
                ProgressView(value: session.progress).tint(.green)
            }
            BrowserSurface(session: session)
        }
        .navigationTitle(account.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { session.webView.goBack() } label: { Image(systemName: "chevron.backward") }
                    .disabled(!session.canGoBack).accessibilityLabel("网页后退")
                Button { session.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("刷新当前账号网页")
            }
        }
        .confirmationDialog("在系统浏览器打开外部链接？", isPresented: Binding(get: { session.externalURL != nil }, set: { if !$0 { session.externalURL = nil } }), titleVisibility: .visible) {
            if let url = session.externalURL {
                Button("打开 \(url.host ?? "外部网站")") { openURL(url); session.externalURL = nil }
            }
            Button("取消", role: .cancel) { session.externalURL = nil }
        } message: { Text("外部浏览器不共享此账号的独立登录空间。") }
        .onAppear { session.openIfNeeded() }
    }
}
