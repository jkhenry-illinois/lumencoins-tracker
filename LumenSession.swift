import Foundation

/// Owns the Lumen session cookies and fetches/parses GET /profile.
///
/// Cookies are managed manually (not via URLSession's shared cookie store) so
/// they can be persisted in the Keychain and replayed on each request. Redirects
/// into the `/login` flow are detected and stopped — a redirect to `/login`
/// means the session has expired.
final class LumenSession: NSObject, URLSessionTaskDelegate {
    static let profileURL = URL(string: "https://lumen.ncsa.illinois.edu/profile")!

    private(set) var cookies: [HTTPCookie] = []
    private(set) var hasSession = false

    private var contexts: [Int: TaskContext] = [:]

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    override init() {
        self.cookies = KeychainStore.load()
        self.hasSession = !cookies.isEmpty
        super.init()
    }

    func replaceAll(cookies newCookies: [HTTPCookie]) {
        cookies = newCookies
        persist()
        hasSession = !cookies.isEmpty
    }

    func merge(cookies incoming: [HTTPCookie]) {
        for c in incoming {
            if let i = cookies.firstIndex(where: { $0.name == c.name && $0.domain == c.domain && $0.path == c.path }) {
                cookies[i] = c
            } else {
                cookies.append(c)
            }
        }
        persist()
        hasSession = !cookies.isEmpty
    }

    func clear() {
        cookies = []
        hasSession = false
        KeychainStore.clear()
    }

    private func persist() {
        KeychainStore.save(cookies: cookies)
    }

    private func cookieHeader() -> String {
        cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    func fetchProfile(completion: @escaping (ParseResult) -> Void) {
        var req = URLRequest(url: LumenSession.profileURL)
        req.setValue(cookieHeader(), forHTTPHeaderField: "Cookie")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let ctx = TaskContext()
        let task = urlSession.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self else { return }
            self.contexts.removeValue(forKey: ctx.taskID)

            if ctx.sawLogin { completion(.loggedOut); return }
            if error != nil { completion(.networkError); return }

            guard let http = response as? HTTPURLResponse,
                  let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                completion(.parseError); return
            }

            // Keep the session fresh if the server rotates the cookie.
            let headerFields = (http.allHeaderFields as? [String: String]) ?? [:]
            let setCookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields,
                                                for: http.url ?? LumenSession.profileURL)
            if !setCookies.isEmpty { self.merge(cookies: setCookies) }

            if (http.url?.path ?? "").contains("/login") {
                completion(.loggedOut); return
            }
            completion(CoinParse.parse(html: html))
        }
        ctx.taskID = task.taskIdentifier
        contexts[task.taskIdentifier] = ctx
        task.resume()
    }

    // MARK: URLSessionTaskDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if (request.url?.path ?? "").contains("/login") {
            contexts[task.taskIdentifier]?.sawLogin = true
            completionHandler(nil)  // don't follow into the login redirect chain
            return
        }
        completionHandler(request)
    }

    final class TaskContext {
        var sawLogin = false
        var taskID = 0
    }
}
