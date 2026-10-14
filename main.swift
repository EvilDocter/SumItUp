import Cocoa
import Foundation

// MARK: - Constants & Config
let DEFAULT_API_KEY = ""
let DEFAULT_MODEL = "gemini-3.5-flash-lite"
let CONFIG_FILE = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".sumitup_pos.json")

// Load API Key from environment, .gemini_api_key, or .env if present
func getApiKey() -> String {
    if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
        return envKey
    }
    let homeKeyFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gemini_api_key")
    if let content = try? String(contentsOf: homeKeyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
        return content
    }
    let possibleEnvPaths = [
        FileManager.default.currentDirectoryPath + "/.env",
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/SUM-IT-UP/.env").path,
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".env").path
    ]
    for envPath in possibleEnvPaths {
        if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("GEMINI_API_KEY=") {
                    let key = String(trimmed.dropFirst("GEMINI_API_KEY=".count)).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if !key.isEmpty { return key }
                }
            }
        }
    }
    return DEFAULT_API_KEY
}

// MARK: - Markdown Rich Formatter
enum InlineStyle { case regular, bold, code }
struct InlinePart { let text: String; let style: InlineStyle }

func parseInlineMarkdown(_ str: String) -> [InlinePart] {
    var parts: [InlinePart] = []
    let pattern = "(\\*{2}(.+?)\\*{2})|(`(.+?)`)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return [InlinePart(text: str, style: .regular)]
    }
    let ns = str as NSString
    var lastIdx = 0
    let matches = regex.matches(in: str, range: NSRange(location: 0, length: ns.length))
    for m in matches {
        if m.range.location > lastIdx {
            let plain = ns.substring(with: NSRange(location: lastIdx, length: m.range.location - lastIdx))
            parts.append(InlinePart(text: plain, style: .regular))
        }
        if m.range(at: 2).location != NSNotFound {
            let boldText = ns.substring(with: m.range(at: 2))
            parts.append(InlinePart(text: boldText, style: .bold))
        } else if m.range(at: 4).location != NSNotFound {
            let codeText = ns.substring(with: m.range(at: 4))
            parts.append(InlinePart(text: codeText, style: .code))
        }
        lastIdx = m.range.location + m.range.length
    }
    if lastIdx < ns.length {
        let plain = ns.substring(with: NSRange(location: lastIdx, length: ns.length - lastIdx))
        parts.append(InlinePart(text: plain, style: .regular))
    }
    return parts
}

func renderMarkdown(_ text: String) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let lines = text.components(separatedBy: "\n")
    
    let baseFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    let boldFont = NSFont.boldSystemFont(ofSize: 13)
    let headerFont = NSFont.boldSystemFont(ofSize: 14.5)
    let codeFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    
    let textColor = NSColor(white: 0.92, alpha: 1.0)
    let headerColor = NSColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 1.0)
    let bulletColor = NSColor(red: 0.45, green: 0.88, blue: 0.95, alpha: 1.0)
    let codeBgColor = NSColor(white: 0.22, alpha: 0.85)
    let codeTextColor = NSColor(red: 0.95, green: 0.85, blue: 0.58, alpha: 1.0)
    
    for (idx, line) in lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Headers (### Executive Summary, ## Key Points, etc.)
        if trimmed.hasPrefix("### ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("# ") {
            let title = trimmed.replacingOccurrences(of: "^#{1,4}\\s*", with: "", options: .regularExpression)
            let pStyle = NSMutableParagraphStyle()
            pStyle.paragraphSpacingBefore = (idx == 0) ? 2 : 12
            pStyle.paragraphSpacing = 4
            let attrs: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: headerColor,
                .paragraphStyle: pStyle
            ]
            result.append(NSAttributedString(string: title + "\n", attributes: attrs))
        }
        // Bullet Items (* **Title:** Description)
        else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
            let bulletText = trimmed.replacingOccurrences(of: "^[*\\-•]\\s*", with: "", options: .regularExpression)
            let pStyle = NSMutableParagraphStyle()
            pStyle.headIndent = 16
            pStyle.firstLineHeadIndent = 0
            pStyle.paragraphSpacing = 4
            pStyle.lineSpacing = 2
            
            let bulletPrefix = NSAttributedString(string: "  • ", attributes: [
                .font: boldFont,
                .foregroundColor: bulletColor,
                .paragraphStyle: pStyle
            ])
            result.append(bulletPrefix)
            
            appendFormattedInline(bulletText + "\n", to: result, baseFont: baseFont, boldFont: boldFont, codeFont: codeFont, textColor: textColor, codeTextColor: codeTextColor, codeBg: codeBgColor, pStyle: pStyle)
        }
        // Empty Line
        else if trimmed.isEmpty {
            result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
        }
        // Standard Paragraph
        else {
            let pStyle = NSMutableParagraphStyle()
            pStyle.paragraphSpacing = 6
            pStyle.lineSpacing = 3
            appendFormattedInline(line + "\n", to: result, baseFont: baseFont, boldFont: boldFont, codeFont: codeFont, textColor: textColor, codeTextColor: codeTextColor, codeBg: codeBgColor, pStyle: pStyle)
        }
    }
    return result
}

func appendFormattedInline(_ text: String, to attrStr: NSMutableAttributedString, baseFont: NSFont, boldFont: NSFont, codeFont: NSFont, textColor: NSColor, codeTextColor: NSColor, codeBg: NSColor, pStyle: NSParagraphStyle) {
    let parts = parseInlineMarkdown(text)
    for part in parts {
        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .paragraphStyle: pStyle
        ]
        switch part.style {
        case .bold:
            attrs[.font] = boldFont
            attrs[.foregroundColor] = NSColor.white
        case .code:
            attrs[.font] = codeFont
            attrs[.backgroundColor] = codeBg
            attrs[.foregroundColor] = codeTextColor
        case .regular:
            attrs[.font] = baseFont
        }
        attrStr.append(NSAttributedString(string: part.text, attributes: attrs))
    }
}

// MARK: - Browser & Web Extractor
struct PageInfo {
    let title: String
    let url: String
    let text: String
    let source: String
}

class ContentExtractor {
    // Dual AppleScript runner: tries NSAppleScript, falls back to /usr/bin/osascript CLI
    static func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let res = appleScript.executeAndReturnError(&error)
            if error == nil, let val = res.stringValue, !val.isEmpty {
                return val
            }
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                return output
            }
        } catch {}
        return nil
    }
    
    // Identifies the active browser by checking front-to-back Z-order of windows on screen
    static func getActiveBrowserInfo() -> (url: String, title: String, browser: String, directText: String?)? {
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        let running = NSWorkspace.shared.runningApplications.compactMap { $0.localizedName }
        let knownBrowsers = ["Google Chrome", "Safari", "Brave Browser", "Microsoft Edge", "Arc"]
        
        var checkOrder: [String] = []
        
        // 1. If frontmost app is a known browser, prioritize it
        for b in knownBrowsers {
            if frontApp.contains(b) || (b == "Google Chrome" && frontApp.contains("Chrome")) {
                checkOrder.append(b)
            }
        }
        
        // 2. Check topmost browser window on screen using Quartz window list
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for win in windowList {
                if let owner = win[kCGWindowOwnerName as String] as? String,
                   let layer = win[kCGWindowLayer as String] as? Int, layer == 0 {
                    for b in knownBrowsers {
                        if (owner == b || (b == "Google Chrome" && owner.contains("Chrome"))) && !checkOrder.contains(b) {
                            checkOrder.append(b)
                        }
                    }
                }
            }
        }
        
        // 3. Fallback to any running browsers
        for b in knownBrowsers {
            if !checkOrder.contains(b) && running.contains(where: { $0.contains(b) || (b == "Google Chrome" && $0.contains("Chrome")) }) {
                checkOrder.append(b)
            }
        }
        
        // Ensure standard browsers are evaluated
        if !checkOrder.contains("Google Chrome") { checkOrder.append("Google Chrome") }
        if !checkOrder.contains("Safari") { checkOrder.append("Safari") }
        
        for browser in checkOrder {
            // --- SAFARI ---
            if browser == "Safari" {
                let sc = """
                tell application "Safari"
                    if (count of windows) > 0 then
                        set u to URL of current tab of front window
                        set t to name of current tab of front window
                        set b to ""
                        try
                            set b to text of document 1
                        end try
                        return u & "|||" & t & "|||" & b
                    end if
                end tell
                return ""
                """
                if let res = runAppleScript(sc), res.contains("|||") {
                    let parts = res.components(separatedBy: "|||")
                    if parts.count >= 2 {
                        let u = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let t = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let directText = (parts.count >= 3 && parts[2].count > 50) ? parts[2] : nil
                        if !u.isEmpty && !u.hasPrefix("favorites://") && u != "about:blank" {
                            return (u, t.isEmpty ? "Safari Webpage" : t, "Safari", directText)
                        }
                    }
                }
            }
            // --- GOOGLE CHROME ---
            else if browser == "Google Chrome" {
                // Try to get URL and Title
                let sc = """
                tell application "Google Chrome"
                    if (count of windows) > 0 then
                        set u to URL of active tab of front window
                        set t to title of active tab of front window
                        return u & "|||" & t
                    end if
                end tell
                return ""
                """
                if let res = runAppleScript(sc), res.contains("|||") {
                    let parts = res.components(separatedBy: "|||")
                    if parts.count >= 2 {
                        let u = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let t = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !u.isEmpty && !u.hasPrefix("chrome://") && u != "about:blank" {
                            // Attempt direct JS execution in Chrome
                            var jsText: String? = nil
                            let jsSc = """
                            tell application "Google Chrome"
                                try
                                    return execute active tab of front window javascript "document.body.innerText"
                                end try
                            end tell
                            return ""
                            """
                            if let rawJs = runAppleScript(jsSc), rawJs.count > 60 {
                                jsText = rawJs
                            }
                            return (u, t.isEmpty ? "Chrome Webpage" : t, "Chrome", jsText)
                        }
                    }
                }
            }
            // --- BRAVE ---
            else if browser == "Brave Browser" {
                let sc = """
                tell application "Brave Browser"
                    if (count of windows) > 0 then
                        return (URL of active tab of front window) & "|||" & (title of active tab of front window)
                    end if
                end tell
                return ""
                """
                if let res = runAppleScript(sc), res.contains("|||") {
                    let parts = res.components(separatedBy: "|||")
                    if parts.count >= 2, !parts[0].isEmpty, !parts[0].hasPrefix("brave://") {
                        return (parts[0], parts[1], "Brave", nil)
                    }
                }
            }
            // --- EDGE ---
            else if browser == "Microsoft Edge" {
                let sc = """
                tell application "Microsoft Edge"
                    if (count of windows) > 0 then
                        return (URL of active tab of front window) & "|||" & (title of active tab of front window)
                    end if
                end tell
                return ""
                """
                if let res = runAppleScript(sc), res.contains("|||") {
                    let parts = res.components(separatedBy: "|||")
                    if parts.count >= 2, !parts[0].isEmpty, !parts[0].hasPrefix("edge://") {
                        return (parts[0], parts[1], "Edge", nil)
                    }
                }
            }
        }
        return nil
    }
    
    // Fetch webpage text via curl CLI fallback (handles SSL, redirects, and headers robustly)
    static func fetchHTMLViaCurl(url: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = [
            "-sL",
            "--max-time", "6",
            "-H", "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "-H", "Accept-Language: en-US,en;q=0.9",
            url
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    static func extractContent(completion: @escaping (PageInfo?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Try to get active browser page
            if let browserData = getActiveBrowserInfo() {
                let pageURL = browserData.url.trimmingCharacters(in: .whitespacesAndNewlines)
                let pageTitle = browserData.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let browserName = browserData.browser
                
                // If direct DOM text was extracted (Safari or Chrome JS)
                if let direct = browserData.directText, direct.count > 100 {
                    DispatchQueue.main.async {
                        completion(PageInfo(title: pageTitle, url: pageURL, text: direct, source: browserName))
                    }
                    return
                }
                
                // If it's a local file URL
                if pageURL.hasPrefix("file://"), let fileURL = URL(string: pageURL) {
                    if let fileContent = try? String(contentsOf: fileURL, encoding: .utf8) {
                        let text = cleanHTML(fileContent)
                        DispatchQueue.main.async {
                            completion(PageInfo(title: pageTitle.isEmpty ? fileURL.lastPathComponent : pageTitle, url: pageURL, text: text, source: browserName))
                        }
                        return
                    }
                }
                
                // If it's an HTTP/HTTPS URL
                if pageURL.hasPrefix("http://") || pageURL.hasPrefix("https://") {
                    var htmlContent: String = ""
                    
                    // Fetch using curl
                    if let curlHTML = fetchHTMLViaCurl(url: pageURL), !curlHTML.isEmpty {
                        htmlContent = curlHTML
                    }
                    
                    // Fallback to URLSession if curl was empty
                    if htmlContent.isEmpty, let urlObj = URL(string: pageURL) {
                        var request = URLRequest(url: urlObj)
                        request.timeoutInterval = 6
                        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
                        let sem = DispatchSemaphore(value: 0)
                        URLSession.shared.dataTask(with: request) { data, _, _ in
                            defer { sem.signal() }
                            if let data = data, let str = String(data: data, encoding: .utf8) {
                                htmlContent = str
                            }
                        }.resume()
                        _ = sem.wait(timeout: .now() + 6)
                    }
                    
                    var cleaned = cleanHTML(htmlContent)
                    
                    // Handle YouTube or media pages
                    if pageURL.contains("youtube.com") || pageURL.contains("youtu.be") || cleaned.count < 150 {
                        let metaDesc = extractMetaDescription(htmlContent)
                        if !metaDesc.isEmpty {
                            cleaned = "Title: \(pageTitle)\n\nDescription: \(metaDesc)\n\n\(cleaned)"
                        }
                    }
                    
                    // If we successfully got content from the webpage
                    if cleaned.count > 80 {
                        DispatchQueue.main.async {
                            completion(PageInfo(title: pageTitle.isEmpty ? "Webpage" : pageTitle, url: pageURL, text: cleaned, source: browserName))
                        }
                        return
                    }
                    
                    // Webpage was detected, but page is login-walled / private web app (e.g. Gmail, intranet)
                    if pageURL.contains("mail.google.com") || pageURL.contains("docs.google.com") || pageURL.contains("notion.so") || cleaned.count <= 80 {
                        let guidance = """
                        Title: \(pageTitle)
                        URL: \(pageURL)
                        
                        [Notice: This web application is protected by user authentication. To summarize specific emails, documents, or threads, highlight the desired text on screen and press Cmd+C, then click SumItUp!]
                        """
                        DispatchQueue.main.async {
                            completion(PageInfo(title: pageTitle, url: pageURL, text: guidance, source: browserName))
                        }
                        return
                    }
                }
            }
            
            // 2. Fallback to Clipboard ONLY if NO browser webpage was detected at all
            if let clipText = NSPasteboard.general.string(forType: .string), clipText.trimmingCharacters(in: .whitespacesAndNewlines).count > 15 {
                DispatchQueue.main.async {
                    completion(PageInfo(title: "Clipboard Content", url: "", text: clipText, source: "Clipboard"))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    static func extractMetaDescription(_ html: String) -> String {
        let pattern = "<meta\\s+[^>]*(?:name|property)=[\"'](?:description|og:description)[\"'][^>]*content=[\"']([^\"']*)[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let ns = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
            if let first = matches.first, first.numberOfRanges > 1 {
                return ns.substring(with: first.range(at: 1))
            }
        }
        return ""
    }
    
    static func cleanHTML(_ html: String) -> String {
        var cleaned = html.replacingOccurrences(of: "(?s)<(script|style|nav|header|footer|aside|noscript|svg)[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        let words = cleaned.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return words.joined(separator: " ")
    }
}

// MARK: - Gemini Service
class GeminiService {
    static func summarize(title: String, text: String, mode: String, completion: @escaping (Result<String, Error>) -> Void) {
        let key = getApiKey()
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(DEFAULT_MODEL):generateContent?key=\(key)") else {
            completion(.failure(NSError(domain: "SumItUp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])))
            return
        }
        
        var modeGuidance = "Provide an executive summary: 1-2 clear paragraphs capturing the core narrative, followed by 3 key bullet points."
        if mode == "keypoints" {
            modeGuidance = "Format strictly as 5 to 7 bullet points capturing key takeaways and core arguments. Bold the first 2-3 words of each bullet point."
        } else if mode == "eli5" {
            modeGuidance = "Explain this in very simple, plain English as if explaining to a curious beginner. Use an intuitive analogy."
        } else if mode == "deepdive" {
            modeGuidance = "Provide a comprehensive structured breakdown with sections: Context, Core Findings, and Strategic Implications."
        }
        
        let truncated = String(text.prefix(32000))
        let prompt = """
        You are SumItUp, an institutional AI research assistant. Summarize the following content.
        
        Guidelines:
        - \(modeGuidance)
        - Be factual and strictly grounded in the source text.
        - Preserve critical figures, dates, and names.
        
        TITLE: \(title)
        CONTENT:
        \(truncated)
        """
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(NSError(domain: "SumItUp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Serialization error"])))
            return
        }
        request.httpBody = bodyData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "SumItUp", code: 500, userInfo: [NSLocalizedDescriptionKey: "Empty response from Gemini"]))) }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errObj = json["error"] as? [String: Any], let msg = errObj["message"] as? String {
                        DispatchQueue.main.async { completion(.failure(NSError(domain: "Gemini", code: 400, userInfo: [NSLocalizedDescriptionKey: msg]))) }
                        return
                    }
                    if let candidates = json["candidates"] as? [[String: Any]],
                       let first = candidates.first,
                       let content = first["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        let text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
                        DispatchQueue.main.async { completion(.success(text)) }
                        return
                    }
                }
                DispatchQueue.main.async { completion(.failure(NSError(domain: "Gemini", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not parse Gemini response"]))) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}

// MARK: - Floating Bubble View
class BubbleView: NSView {
    var isHovered = false
    
    override func draw(_ rect: NSRect) {
        super.draw(rect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let bounds = self.bounds
        let inset: CGFloat = isHovered ? 2 : 3
        let circleRect = bounds.insetBy(dx: inset, dy: inset)
        
        // Gradient Colors: Indigo to Cyan
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            NSColor(red: 0.31, green: 0.27, blue: 0.90, alpha: 1.0).cgColor,
            NSColor(red: 0.02, green: 0.71, blue: 0.83, alpha: 1.0).cgColor
        ] as CFArray
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
            context.saveGState()
            context.addEllipse(in: circleRect)
            context.clip()
            context.drawLinearGradient(gradient, start: CGPoint(x: circleRect.minX, y: circleRect.maxY), end: CGPoint(x: circleRect.maxX, y: circleRect.minY), options: [])
            context.restoreGState()
        }
        
        // Outer Glowing Ring
        context.saveGState()
        context.setStrokeColor(isHovered ? NSColor.cyan.cgColor : NSColor(white: 1.0, alpha: 0.6).cgColor)
        context.setLineWidth(isHovered ? 3.0 : 2.0)
        context.strokeEllipse(in: circleRect)
        context.restoreGState()
        
        // Center Sparkle Icon (AI Star)
        let cx = bounds.midX
        let cy = bounds.midY
        let path = CGMutablePath()
        let r1: CGFloat = 13
        let r2: CGFloat = 4
        
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4.0 - .pi / 2.0
            let r = (i % 2 == 0) ? r1 : r2
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        
        context.saveGState()
        context.setFillColor(NSColor.white.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
        
        // Small accent sparkle
        let path2 = CGMutablePath()
        let ax = cx + 8
        let ay = cy + 8
        let ar1: CGFloat = 4
        let ar2: CGFloat = 1.5
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4.0 - .pi / 2.0
            let r = (i % 2 == 0) ? ar1 : ar2
            let x = ax + r * cos(angle)
            let y = ay + r * sin(angle)
            if i == 0 { path2.move(to: CGPoint(x: x, y: y)) } else { path2.addLine(to: CGPoint(x: x, y: y)) }
        }
        path2.closeSubpath()
        
        context.saveGState()
        context.setFillColor(NSColor(red: 0.65, green: 0.95, blue: 1.0, alpha: 0.9).cgColor)
        context.addPath(path2)
        context.fillPath()
        context.restoreGState()
    }
}

// MARK: - Floating Bubble Window
class BubbleWindow: NSPanel {
    var initialLocation: NSPoint = .zero
    var didDrag = false
    let bubbleView: BubbleView
    
    init() {
        let size: CGFloat = 56
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        var origin = NSPoint(x: screen.maxX - size - 28, y: screen.minY + 48)
        if let data = try? Data(contentsOf: CONFIG_FILE),
           let pos = try? JSONSerialization.jsonObject(with: data) as? [String: CGFloat],
           let x = pos["x"], let y = pos["y"] {
            origin = NSPoint(x: x, y: y)
        }
        
        let rect = NSRect(origin: origin, size: CGSize(width: size, height: size))
        self.bubbleView = BubbleView(frame: NSRect(origin: .zero, size: rect.size))
        
        super.init(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = true
        self.contentView = bubbleView
        
        let trackingArea = NSTrackingArea(rect: bubbleView.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        bubbleView.addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        bubbleView.isHovered = true
        bubbleView.needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        bubbleView.isHovered = false
        bubbleView.needsDisplay = true
    }
    
    override func mouseDown(with event: NSEvent) {
        initialLocation = event.locationInWindow
        didDrag = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        didDrag = true
        let currentLocation = event.locationInWindow
        var newOrigin = self.frame.origin
        newOrigin.x += (currentLocation.x - initialLocation.x)
        newOrigin.y += (currentLocation.y - initialLocation.y)
        self.setFrameOrigin(newOrigin)
    }
    
    override func mouseUp(with event: NSEvent) {
        if didDrag {
            let pos: [String: CGFloat] = ["x": self.frame.origin.x, "y": self.frame.origin.y]
            if let data = try? JSONSerialization.data(withJSONObject: pos) {
                try? data.write(to: CONFIG_FILE)
            }
        } else {
            AppDelegate.shared.toggleSummary()
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "🌐 Summarize Active Webpage", action: #selector(AppDelegate.shared.triggerSummarize), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "📋 Summarize Clipboard", action: #selector(AppDelegate.shared.triggerClipboard), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "📍 Reset Position to Bottom Right", action: #selector(AppDelegate.shared.resetPosition), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "✕ Quit SumItUp", action: #selector(AppDelegate.shared.quitApp), keyEquivalent: "q"))
        NSMenu.popUpContextMenu(menu, with: event, for: bubbleView)
    }
}

// MARK: - Summary Card Window
class SummaryWindow: NSPanel {
    var titleLabel: NSTextField!
    var metaLabel: NSTextField!
    var textView: NSTextView!
    var copyButton: NSButton!
    var speakButton: NSButton!
    var currentSummary: String = ""
    var currentTitle: String = ""
    var currentMode: String = "overview"
    var lastPageInfo: PageInfo?
    let speechSynth = NSSpeechSynthesizer()
    var isSpeaking = false
    
    init() {
        let width: CGFloat = 460
        let height: CGFloat = 510
        super.init(contentRect: NSRect(x: 200, y: 200, width: width, height: height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = true
        
        // Frosted Glass Effect
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 18
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 1
        visualEffect.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        self.contentView = visualEffect
        
        // Header Container
        let headerView = NSView(frame: NSRect(x: 0, y: height - 54, width: width, height: 54))
        visualEffect.addSubview(headerView)
        
        let brandLabel = NSTextField(labelWithString: "SumItUp AI")
        brandLabel.frame = NSRect(x: 18, y: 16, width: 140, height: 22)
        brandLabel.font = NSFont.boldSystemFont(ofSize: 15)
        brandLabel.textColor = NSColor.cyan
        headerView.addSubview(brandLabel)
        
        let closeBtn = NSButton(title: "✕", target: AppDelegate.shared, action: #selector(AppDelegate.shared.closeSummary))
        closeBtn.frame = NSRect(x: width - 42, y: 14, width: 28, height: 26)
        closeBtn.bezelStyle = .rounded
        closeBtn.isBordered = false
        closeBtn.font = NSFont.boldSystemFont(ofSize: 13)
        headerView.addSubview(closeBtn)
        
        // Mode Segmented Control
        let seg = NSSegmentedControl(labels: ["⚡ Overview", "🎯 Key Points", "👶 ELI5", "🔬 Deep Dive"], trackingMode: .selectOne, target: self, action: #selector(modeChanged(_:)))
        seg.frame = NSRect(x: 18, y: height - 90, width: width - 36, height: 24)
        seg.selectedSegment = 0
        visualEffect.addSubview(seg)
        
        // Metadata Label
        metaLabel = NSTextField(labelWithString: "🔍 Reading active page...")
        metaLabel.frame = NSRect(x: 18, y: height - 118, width: width - 36, height: 20)
        metaLabel.font = NSFont.systemFont(ofSize: 11)
        metaLabel.textColor = NSColor.lightGray
        visualEffect.addSubview(metaLabel)
        
        // Summary Text Area
        let scroll = NSScrollView(frame: NSRect(x: 18, y: 56, width: width - 36, height: height - 182))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        
        textView = NSTextView(frame: scroll.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor(white: 0.12, alpha: 0.85)
        textView.textColor = NSColor.white
        textView.textContainerInset = NSSize(width: 14, height: 12)
        scroll.documentView = textView
        visualEffect.addSubview(scroll)
        
        // Footer Buttons - Wide frames so labels are never truncated
        copyButton = NSButton(title: "📋 Copy", target: self, action: #selector(copyClicked))
        copyButton.frame = NSRect(x: 18, y: 14, width: 88, height: 28)
        copyButton.bezelStyle = .rounded
        visualEffect.addSubview(copyButton)
        
        speakButton = NSButton(title: "🔊 Read Aloud", target: self, action: #selector(speakClicked))
        speakButton.frame = NSRect(x: 114, y: 14, width: 132, height: 28)
        speakButton.bezelStyle = .rounded
        visualEffect.addSubview(speakButton)
        
        let doneBtn = NSButton(title: "Done", target: AppDelegate.shared, action: #selector(AppDelegate.shared.closeSummary))
        doneBtn.frame = NSRect(x: width - 96, y: 14, width: 78, height: 28)
        doneBtn.bezelStyle = .rounded
        visualEffect.addSubview(doneBtn)
        
        titleLabel = brandLabel
    }
    
    @objc func modeChanged(_ sender: NSSegmentedControl) {
        let modes = ["overview", "keypoints", "eli5", "deepdive"]
        currentMode = modes[sender.selectedSegment]
        if let info = lastPageInfo {
            startSummarize(info: info)
        }
    }
    
    func startSummarize(info: PageInfo) {
        lastPageInfo = info
        currentTitle = info.title
        metaLabel.stringValue = "📄 [\(info.source)] \(String(info.title.prefix(38))) (~\(info.text.split(separator: " ").count) words)"
        textView.textStorage?.setAttributedString(renderMarkdown("⏳ *Gemini AI is analyzing and condensing this content...*"))
        
        GeminiService.summarize(title: info.title, text: info.text, mode: currentMode) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let summary):
                self.currentSummary = summary
                self.metaLabel.stringValue = "✅ [\(info.source)] \(String(info.title.prefix(38)))"
                let formatted = renderMarkdown(summary)
                self.textView.textStorage?.setAttributedString(formatted)
                self.textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            case .failure(let err):
                self.textView.textStorage?.setAttributedString(renderMarkdown("⚠️ **Failed to summarize:** \(err.localizedDescription)\n\nTip: Make sure your internet connection is active and your Gemini API key is valid."))
            }
        }
    }
    
    @objc func copyClicked() {
        if !currentSummary.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(currentSummary, forType: .string)
            copyButton.title = "✓ Copied!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.copyButton.title = "📋 Copy"
            }
        }
    }
    
    @objc func speakClicked() {
        if isSpeaking {
            speechSynth.stopSpeaking()
            isSpeaking = false
            speakButton.title = "🔊 Read Aloud"
        } else if !currentSummary.isEmpty {
            let clean = currentSummary.replacingOccurrences(of: "[*#_`]", with: " ", options: .regularExpression)
            speechSynth.startSpeaking(clean)
            isSpeaking = true
            speakButton.title = "⏹ Stop"
            
            // Auto reset button when speech finishes
            DispatchQueue.global().async { [weak self] in
                while self?.speechSynth.isSpeaking == true {
                    Thread.sleep(forTimeInterval: 0.5)
                }
                DispatchQueue.main.async {
                    self?.isSpeaking = false
                    self?.speakButton.title = "🔊 Read Aloud"
                }
            }
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
    var bubbleWindow: BubbleWindow!
    var summaryWindow: SummaryWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        bubbleWindow = BubbleWindow()
        summaryWindow = SummaryWindow()
        bubbleWindow.orderFrontRegardless()
    }
    
    func toggleSummary() {
        if summaryWindow.isVisible {
            closeSummary()
        } else {
            triggerSummarize()
        }
    }
    
    @objc func triggerSummarize() {
        positionSummaryWindow()
        summaryWindow.orderFrontRegardless()
        summaryWindow.metaLabel.stringValue = "🔍 Detecting active browser page..."
        summaryWindow.textView.textStorage?.setAttributedString(renderMarkdown("⏳ *Reading webpage content...*"))
        
        ContentExtractor.extractContent { [weak self] info in
            guard let self = self else { return }
            if let info = info {
                self.summaryWindow.startSummarize(info: info)
            } else {
                self.summaryWindow.metaLabel.stringValue = "⚠️ No active browser or clipboard content"
                let tip = """
                ### No Content Detected
                Could not find an active webpage in Chrome, Safari, Brave, or Edge, and clipboard is currently empty.
                
                **Quick Tips:**
                * Open any article or website in Chrome or Safari.
                * Or highlight any text on your screen and press `Cmd + C` to copy it.
                * Then click the **SumItUp** bubble to summarize!
                """
                self.summaryWindow.textView.textStorage?.setAttributedString(renderMarkdown(tip))
            }
        }
    }
    
    @objc func triggerClipboard() {
        if let clipText = NSPasteboard.general.string(forType: .string), !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            positionSummaryWindow()
            summaryWindow.orderFrontRegardless()
            summaryWindow.startSummarize(info: PageInfo(title: "Clipboard Content", url: "", text: clipText, source: "Clipboard"))
        } else {
            positionSummaryWindow()
            summaryWindow.orderFrontRegardless()
            summaryWindow.metaLabel.stringValue = "⚠️ Clipboard is empty"
            summaryWindow.textView.textStorage?.setAttributedString(renderMarkdown("Your clipboard is currently empty. Copy some text first, then click here!"))
        }
    }
    
    func positionSummaryWindow() {
        let bFrame = bubbleWindow.frame
        let sw = summaryWindow.frame.width
        let sh = summaryWindow.frame.height
        
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var x = bFrame.minX - sw - 14
        if x < screen.minX + 10 { x = bFrame.maxX + 14 }
        
        var y = bFrame.maxY - sh
        if y < screen.minY + 10 { y = screen.minY + 20 }
        
        summaryWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    @objc func closeSummary() {
        summaryWindow.orderOut(nil)
        if summaryWindow.isSpeaking {
            summaryWindow.speechSynth.stopSpeaking()
            summaryWindow.isSpeaking = false
            summaryWindow.speakButton.title = "🔊 Read Aloud"
        }
    }
    
    @objc func resetPosition() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size: CGFloat = 56
        let origin = NSPoint(x: screen.maxX - size - 28, y: screen.minY + 48)
        bubbleWindow.setFrameOrigin(origin)
        let pos: [String: CGFloat] = ["x": origin.x, "y": origin.y]
        if let data = try? JSONSerialization.data(withJSONObject: pos) {
            try? data.write(to: CONFIG_FILE)
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Main Application Entrypoint
let app = NSApplication.shared
let delegate = AppDelegate.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
