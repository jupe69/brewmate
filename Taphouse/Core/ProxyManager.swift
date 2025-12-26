import Foundation

/// Manages system proxy detection and configuration
final class ProxyManager: Sendable {
    static let shared = ProxyManager()

    private init() {}

    /// Gets proxy environment variables from macOS system settings
    /// Returns a dictionary with HTTP_PROXY, HTTPS_PROXY, ALL_PROXY, NO_PROXY if configured
    func getProxyEnvironment() -> [String: String] {
        var proxyEnv: [String: String] = [:]

        // Read system proxy settings via scutil
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        process.arguments = ["--proxy"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return proxyEnv
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return proxyEnv
        }

        // Parse the plist-style output
        let settings = parseProxySettings(output)

        // Build HTTP proxy URL
        if let httpEnabled = settings["HTTPEnable"], httpEnabled == "1",
           let httpHost = settings["HTTPProxy"],
           let httpPort = settings["HTTPPort"] {
            let proxyURL = "http://\(httpHost):\(httpPort)"
            proxyEnv["HTTP_PROXY"] = proxyURL
            proxyEnv["http_proxy"] = proxyURL
        }

        // Build HTTPS proxy URL
        if let httpsEnabled = settings["HTTPSEnable"], httpsEnabled == "1",
           let httpsHost = settings["HTTPSProxy"],
           let httpsPort = settings["HTTPSPort"] {
            let proxyURL = "http://\(httpsHost):\(httpsPort)"
            proxyEnv["HTTPS_PROXY"] = proxyURL
            proxyEnv["https_proxy"] = proxyURL
        }

        // Build SOCKS proxy URL
        if let socksEnabled = settings["SOCKSEnable"], socksEnabled == "1",
           let socksHost = settings["SOCKSProxy"],
           let socksPort = settings["SOCKSPort"] {
            let proxyURL = "socks5://\(socksHost):\(socksPort)"
            proxyEnv["ALL_PROXY"] = proxyURL
            proxyEnv["all_proxy"] = proxyURL
        }

        // Build NO_PROXY from exceptions list
        if let exceptions = parseExceptionsList(output) {
            let noProxy = exceptions.joined(separator: ",")
            proxyEnv["NO_PROXY"] = noProxy
            proxyEnv["no_proxy"] = noProxy
        }

        return proxyEnv
    }

    /// Parses the scutil --proxy output into a dictionary
    private func parseProxySettings(_ output: String) -> [String: String] {
        var settings: [String: String] = [:]
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match patterns like "HTTPEnable : 1" or "HTTPProxy : proxy.example.com"
            if let colonRange = trimmed.range(of: " : ") {
                let key = String(trimmed[..<colonRange.lowerBound])
                let value = String(trimmed[colonRange.upperBound...])
                settings[key] = value
            }
        }

        return settings
    }

    /// Parses the ExceptionsList array from scutil output
    private func parseExceptionsList(_ output: String) -> [String]? {
        var exceptions: [String] = []
        var inExceptionsList = false

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("ExceptionsList") {
                inExceptionsList = true
                continue
            }

            if inExceptionsList {
                if trimmed == "}" {
                    break
                }
                // Parse lines like "0 : *.local"
                if let colonRange = trimmed.range(of: " : ") {
                    let value = String(trimmed[colonRange.upperBound...])
                    exceptions.append(value)
                }
            }
        }

        return exceptions.isEmpty ? nil : exceptions
    }
}
