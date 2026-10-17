import Foundation
import Network
import Combine
import ZIPFoundation

class ROMWebServer: ObservableObject {
    static let shared = ROMWebServer()
    
    @Published var isRunning = false
    @Published var serverAddress: String = "Starting..."
    @Published var lastUploadedFileName: String?
    
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 8080
    
    init() {
        start()
    }
    
    func start() {
        guard listener == nil else { return }
        
        do {
            let parameters = NWParameters.tcp
            let newListener = try NWListener(using: parameters, on: port)
            
            newListener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        let ip = self?.getWiFiAddress() ?? "appletv.local"
                        self?.serverAddress = "http://\(ip):8080"
                        print("[ROMWebServer] Ready at \(self?.serverAddress ?? "")")
                    case .failed(let error):
                        print("[ROMWebServer] Failed: \(error)")
                        self?.isRunning = false
                        self?.serverAddress = "Error starting server"
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            
            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            newListener.start(queue: .main)
            self.listener = newListener
        } catch {
            print("[ROMWebServer] Could not create listener: \(error)")
            self.serverAddress = "Unavailable"
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        
        var receivedData = Data()
        
        func readNext() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let data = data, !data.isEmpty {
                    receivedData.append(data)
                    
                    // Check if headers have arrived
                    if let headerEnd = receivedData.range(of: Data("\r\n\r\n".utf8)) {
                        let headerData = receivedData.subdata(in: 0..<headerEnd.lowerBound)
                        guard let headerString = String(data: headerData, encoding: .utf8) else {
                            connection.cancel()
                            return
                        }
                        
                        let lines = headerString.components(separatedBy: "\r\n")
                        let requestLine = lines.first ?? ""
                        let parts = requestLine.components(separatedBy: " ")
                        let method = parts.first ?? "GET"
                        let fullPath = parts.count > 1 ? parts[1] : "/"
                        let path = fullPath.components(separatedBy: "?").first ?? fullPath
                        
                        if method == "GET" && path == "/" {
                            self.sendHTMLPage(to: connection)
                            return
                        } else if method == "GET" && path == "/api/games" {
                            self.sendGamesList(to: connection)
                            return
                        } else if (method == "POST" || method == "GET") && path == "/api/delete" {
                            self.handleDelete(fullPath: fullPath, body: receivedData.subdata(in: headerEnd.upperBound..<receivedData.count), connection: connection)
                            return
                        } else if method == "POST" && path == "/upload" {
                            // Extract Content-Length
                            var contentLength = 0
                            for line in lines {
                                if line.lowercased().hasPrefix("content-length:") {
                                    let val = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                                    contentLength = Int(val) ?? 0
                                }
                            }
                            
                            let bodyStartIndex = headerEnd.upperBound
                            let bodyReceivedSoFar = receivedData.count - bodyStartIndex
                            
                            if contentLength <= 0 || bodyReceivedSoFar >= contentLength {
                                let bodyData = receivedData.subdata(in: bodyStartIndex..<receivedData.count)
                                self.processUpload(headers: lines, body: bodyData, connection: connection)
                            } else {
                                // Wait for remaining body bytes
                                func readRemainingBody() {
                                    let remaining = contentLength - (receivedData.count - bodyStartIndex)
                                    connection.receive(minimumIncompleteLength: 1, maximumLength: max(remaining, 65536)) { moreData, _, isDone, readErr in
                                        if let moreData = moreData {
                                            receivedData.append(moreData)
                                        }
                                        if (receivedData.count - bodyStartIndex) >= contentLength || isDone || readErr != nil {
                                            let fullBody = receivedData.subdata(in: bodyStartIndex..<receivedData.count)
                                            self.processUpload(headers: lines, body: fullBody, connection: connection)
                                        } else {
                                            readRemainingBody()
                                        }
                                    }
                                }
                                readRemainingBody()
                            }
                            return
                        } else {
                            self.send404(to: connection)
                            return
                        }
                    }
                }
                
                if !isComplete && error == nil {
                    readNext()
                } else {
                    connection.cancel()
                }
            }
        }
        
        readNext()
    }
    
    private func processUpload(headers: [String], body: Data, connection: NWConnection) {
        // Extract boundary without stripping leading hyphens
        var boundary: String?
        for line in headers {
            if let range = line.range(of: "boundary=", options: .caseInsensitive) {
                var rawBoundary = String(line[range.upperBound...])
                if let semi = rawBoundary.range(of: ";") {
                    rawBoundary = String(rawBoundary[..<semi.lowerBound])
                }
                // Trim only quotes and whitespace - preserve leading dashes!
                boundary = rawBoundary.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n\""))
            }
        }
        
        guard let boundary = boundary,
              let filename = extractFilename(from: body),
              let fileData = extractFileData(from: body, boundary: boundary) else {
            self.sendErrorResponse(to: connection, message: "Invalid upload: Could not parse multipart form data.")
            return
        }
        
        let destURL = TVGameManager.shared.romsDirectory.appendingPathComponent(filename)
        
        do {
            try fileData.write(to: destURL, options: .atomic)
            print("[ROMWebServer] Successfully saved file: \(filename) (\(fileData.count) bytes) to \(destURL.path)")
            
            var extractedFiles: [String] = []
            if filename.lowercased().hasSuffix(".zip") {
                print("[ROMWebServer] Automatically extracting zip: \(filename)")
                do {
                    try FileManager.default.unzipItem(at: destURL, to: TVGameManager.shared.romsDirectory)
                    try? FileManager.default.removeItem(at: destURL)
                    extractedFiles.append("Extracted content of \(filename)")
                } catch {
                    print("[ROMWebServer] ZIP extraction error: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.lastUploadedFileName = filename
                TVGameManager.shared.loadGames()
            }
            
            self.sendJSONResponse(to: connection, status: "OK", filename: filename, size: fileData.count)
        } catch {
            print("[ROMWebServer] File write error: \(error)")
            self.sendErrorResponse(to: connection, message: "Failed to write file to storage: \(error.localizedDescription)")
        }
    }
    
    private func extractFilename(from data: Data) -> String? {
        guard let text = String(data: data.prefix(4096), encoding: .isoLatin1) else { return nil }
        if let range = text.range(of: "filename=\"") {
            let rest = text[range.upperBound...]
            if let endRange = rest.range(of: "\"") {
                let name = String(rest[..<endRange.lowerBound])
                let sanitized = name.replacingOccurrences(of: "/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                return sanitized.isEmpty ? nil : sanitized
            }
        }
        return nil
    }
    
    private func extractFileData(from data: Data, boundary: String) -> Data? {
        let boundaryPrefix = Data(("--" + boundary).utf8)
        let headerEndData = Data("\r\n\r\n".utf8)
        
        guard let firstBoundaryRange = data.range(of: boundaryPrefix) else { return nil }
        guard let headerEndRange = data.range(of: headerEndData, in: firstBoundaryRange.upperBound..<data.count) else { return nil }
        
        let fileContentStart = headerEndRange.upperBound
        let endBoundaryPrefix = Data(("\r\n--" + boundary).utf8)
        
        if let endBoundaryRange = data.range(of: endBoundaryPrefix, in: fileContentStart..<data.count) {
            return data.subdata(in: fileContentStart..<endBoundaryRange.lowerBound)
        } else {
            return data.subdata(in: fileContentStart..<data.count)
        }
    }
    
    private func sendGamesList(to connection: NWConnection) {
        let files = TVGameManager.shared.listAllFilesDetails()
        guard let jsonData = try? JSONSerialization.data(withJSONObject: files, options: [.prettyPrinted]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            sendErrorResponse(to: connection, message: "Could not serialize files list")
            return
        }
        
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(jsonString.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(jsonString)
        """
        
        connection.send(content: Data(response.utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func handleDelete(fullPath: String, body: Data, connection: NWConnection) {
        var filenameToDelete: String?
        
        // 1. Try URL parameter ?file=...
        if let queryRange = fullPath.range(of: "?") {
            let query = String(fullPath[queryRange.upperBound...])
            for param in query.components(separatedBy: "&") {
                let kv = param.components(separatedBy: "=")
                if kv.count == 2 && kv[0] == "file" {
                    filenameToDelete = kv[1].removingPercentEncoding
                }
            }
        }
        
        // 2. Try JSON body
        if filenameToDelete == nil, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            filenameToDelete = json["file"] as? String
        }
        
        guard let targetName = filenameToDelete, !targetName.isEmpty else {
            self.sendErrorResponse(to: connection, message: "Missing file parameter")
            return
        }
        
        do {
            try TVGameManager.shared.deleteFile(named: targetName)
            self.sendJSONResponse(to: connection, status: "DELETED", filename: targetName, size: 0)
        } catch {
            self.sendErrorResponse(to: connection, message: "Delete failed: \(error.localizedDescription)")
        }
    }
    
    private func sendHTMLPage(to connection: NWConnection) {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Delta on Apple TV - ROM Manager</title>
            <style>
                :root {
                    --bg: #0c0e17;
                    --card: #151926;
                    --border: #232b40;
                    --accent-start: #ff5e62;
                    --accent-end: #ff9966;
                    --text: #f1f5f9;
                    --text-muted: #8e9bb0;
                    --nes: #ef4444;
                    --snes: #8b5cf6;
                    --n64: #f59e0b;
                    --success: #10b981;
                }
                * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
                body {
                    background: var(--bg);
                    color: var(--text);
                    margin: 0;
                    padding: 30px 16px;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                }
                .wrap { max-width: 820px; width: 100%; }
                header { text-align: center; margin-bottom: 28px; }
                h1 {
                    margin: 0 0 8px;
                    font-size: 32px;
                    font-weight: 800;
                    background: linear-gradient(135deg, var(--accent-start), var(--accent-end));
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                }
                p.sub { color: var(--text-muted); font-size: 15px; margin: 0; }
                
                .card {
                    background: var(--card);
                    border: 1px solid var(--border);
                    border-radius: 18px;
                    padding: 24px;
                    margin-bottom: 24px;
                    box-shadow: 0 8px 30px rgba(0,0,0,0.4);
                }
                
                .drop-zone {
                    border: 2px dashed #3a4463;
                    border-radius: 14px;
                    padding: 36px 20px;
                    background: #111420;
                    cursor: pointer;
                    text-align: center;
                    transition: all 0.2s ease;
                }
                .drop-zone:hover, .drop-zone.dragover {
                    border-color: var(--accent-start);
                    background: #191e30;
                }
                .icon { font-size: 42px; margin-bottom: 10px; }
                .upload-title { font-size: 18px; font-weight: 700; margin-bottom: 6px; }
                .upload-hint { font-size: 13px; color: var(--text-muted); }
                input[type=file] { display: none; }
                
                .status-box {
                    margin-top: 16px;
                    padding: 12px 16px;
                    border-radius: 10px;
                    font-size: 14px;
                    font-weight: 500;
                    display: none;
                }
                
                .section-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 16px;
                }
                .section-title { font-size: 20px; font-weight: 700; }
                
                .btn {
                    background: #232b40;
                    color: var(--text);
                    border: 1px solid #3a4463;
                    padding: 8px 16px;
                    border-radius: 8px;
                    font-size: 13px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: background 0.15s;
                }
                .btn:hover { background: #313c59; }
                .btn-delete {
                    background: #3b161c;
                    border: 1px solid #70252b;
                    color: #fca5a5;
                    padding: 6px 12px;
                    border-radius: 6px;
                    font-size: 12px;
                    cursor: pointer;
                }
                .btn-delete:hover { background: #541c24; }
                
                .files-table {
                    width: 100%;
                    border-collapse: collapse;
                    font-size: 14px;
                }
                .files-table th {
                    text-align: left;
                    color: var(--text-muted);
                    font-size: 12px;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                    padding: 10px 12px;
                    border-bottom: 1px solid var(--border);
                }
                .files-table td {
                    padding: 12px;
                    border-bottom: 1px solid #1a2033;
                    vertical-align: middle;
                }
                .files-table tr:hover { background: #191f30; }
                
                .badge {
                    display: inline-block;
                    padding: 3px 8px;
                    border-radius: 6px;
                    font-size: 11px;
                    font-weight: 700;
                    text-transform: uppercase;
                }
                .badge-nes { background: rgba(239, 68, 68, 0.2); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); }
                .badge-snes { background: rgba(139, 92, 246, 0.2); color: #c084fc; border: 1px solid rgba(139, 92, 246, 0.3); }
                .badge-n64 { background: rgba(245, 158, 11, 0.2); color: #fbbf24; border: 1px solid rgba(245, 158, 11, 0.3); }
                .badge-other { background: #262c42; color: #94a3b8; }
                
                .file-name { font-weight: 600; color: var(--text); }
                .internal-title { font-size: 12px; color: var(--text-muted); margin-top: 2px; }
                .file-size { color: var(--text-muted); font-family: monospace; font-size: 13px; }
                
                .empty-state {
                    text-align: center;
                    padding: 40px 20px;
                    color: var(--text-muted);
                }
            </style>
        </head>
        <body>
            <div class="wrap">
                <header>
                    <h1>Delta for Apple TV</h1>
                    <p class="sub">Wireless Game Library & Storage Manager</p>
                </header>
                
                <!-- Upload Card -->
                <div class="card">
                    <div class="drop-zone" id="dropZone" onclick="document.getElementById('fileInput').click()">
                        <div class="icon">🎮</div>
                        <div class="upload-title">Choose or Drop ROM Files Here</div>
                        <div class="upload-hint">Supports .nes, .smc, .sfc, .n64, .z64, .v64, .zip archives &amp; cover art (.png, .jpg)</div>
                        <input type="file" id="fileInput" multiple accept=".nes,.smc,.sfc,.fig,.n64,.z64,.v64,.zip,.png,.jpg,.jpeg">
                    </div>
                    <div id="statusBox" class="status-box"></div>
                </div>
                
                <!-- Installed Games Card -->
                <div class="card">
                    <div class="section-header">
                        <div class="section-title">Received Games on Apple TV</div>
                        <button class="btn" onclick="fetchGames()">🔄 Refresh List</button>
                    </div>
                    <div id="gamesContainer">Loading library...</div>
                </div>
            </div>

            <script>
                const fileInput = document.getElementById('fileInput');
                const dropZone = document.getElementById('dropZone');
                const statusBox = document.getElementById('statusBox');
                const gamesContainer = document.getElementById('gamesContainer');

                ['dragenter', 'dragover'].forEach(name => {
                    dropZone.addEventListener(name, (e) => { e.preventDefault(); dropZone.classList.add('dragover'); });
                });
                ['dragleave', 'drop'].forEach(name => {
                    dropZone.addEventListener(name, (e) => { e.preventDefault(); dropZone.classList.remove('dragover'); });
                });
                dropZone.addEventListener('drop', (e) => {
                    if (e.dataTransfer.files.length) uploadFiles(e.dataTransfer.files);
                });
                fileInput.addEventListener('change', () => {
                    if (fileInput.files.length) uploadFiles(fileInput.files);
                });

                function showStatus(msg, type) {
                    statusBox.style.display = 'block';
                    statusBox.innerText = msg;
                    if (type === 'progress') {
                        statusBox.style.background = '#1e293b';
                        statusBox.style.color = '#38bdf8';
                        statusBox.style.border = '1px solid #38bdf8';
                    } else if (type === 'success') {
                        statusBox.style.background = '#143828';
                        statusBox.style.color = '#4ade80';
                        statusBox.style.border = '1px solid #22c55e';
                    } else {
                        statusBox.style.background = '#3b161c';
                        statusBox.style.color = '#f87171';
                        statusBox.style.border = '1px solid #ef4444';
                    }
                }

                async function uploadFiles(files) {
                    for (let file of files) {
                        showStatus('Uploading ' + file.name + ' (' + (file.size / 1024 / 1024).toFixed(2) + ' MB)...', 'progress');
                        let formData = new FormData();
                        formData.append('file', file);
                        
                        try {
                            let resp = await fetch('/upload', { method: 'POST', body: formData });
                            let json = await resp.json();
                            if (json.status === 'OK') {
                                showStatus('✓ ' + file.name + ' uploaded successfully! Saved to Apple TV.', 'success');
                                fetchGames();
                            } else {
                                showStatus('✗ Error: ' + (json.error || 'Upload failed'), 'error');
                            }
                        } catch (err) {
                            showStatus('✗ Connection error: ' + err.message, 'error');
                        }
                    }
                }

                async function fetchGames() {
                    try {
                        let resp = await fetch('/api/games');
                        let games = await resp.json();
                        renderGames(games);
                    } catch (err) {
                        gamesContainer.innerHTML = '<div class="empty-state">Failed to load games: ' + err.message + '</div>';
                    }
                }

                function renderGames(games) {
                    if (!games || games.length === 0) {
                        gamesContainer.innerHTML = '<div class="empty-state">No ROM files detected on Apple TV storage.<br>Upload your games above!</div>';
                        return;
                    }

                    let html = '<table class="files-table"><thead><tr>' +
                        '<th>System</th><th>Game / Filename</th><th>Size</th><th>Action</th>' +
                        '</tr></thead><tbody>';

                    for (let g of games) {
                        let badgeClass = 'badge-other';
                        if (g.system === 'NES') badgeClass = 'badge-nes';
                        else if (g.system === 'SNES') badgeClass = 'badge-snes';
                        else if (g.system === 'N64') badgeClass = 'badge-n64';

                        let internalInfo = '';
                        if (g.internalTitle && g.internalTitle !== g.cleanName) {
                            internalInfo = '<div class="internal-title">ROM Header Title: ' + escapeHtml(g.internalTitle) + '</div>';
                        }

                        html += '<tr>' +
                            '<td><span class="badge ' + badgeClass + '">' + escapeHtml(g.system) + '</span></td>' +
                            '<td><div class="file-name">' + escapeHtml(g.cleanName || g.filename) + '</div>' +
                                '<div class="internal-title" style="color:#64748b;">' + escapeHtml(g.filename) + '</div>' +
                                internalInfo +
                            '</td>' +
                            '<td><span class="file-size">' + escapeHtml(g.sizeFormatted) + '</span></td>' +
                            '<td><button class="btn-delete" onclick="deleteGame(\\'' + escapeJs(g.filename) + '\\')">🗑️ Delete</button></td>' +
                            '</tr>';
                    }

                    html += '</tbody></table>';
                    gamesContainer.innerHTML = html;
                }

                async function deleteGame(filename) {
                    if (!confirm('Are you sure you want to delete "' + filename + '" from Apple TV?')) return;
                    try {
                        let resp = await fetch('/api/delete?file=' + encodeURIComponent(filename), { method: 'POST' });
                        let res = await resp.json();
                        if (res.status === 'DELETED') {
                            showStatus('✓ Deleted ' + filename, 'success');
                            fetchGames();
                        } else {
                            showStatus('✗ Delete failed: ' + (res.error || 'Unknown error'), 'error');
                        }
                    } catch (e) {
                        showStatus('✗ Delete error: ' + e.message, 'error');
                    }
                }

                function escapeHtml(str) {
                    if (!str) return '';
                    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
                }
                function escapeJs(str) {
                    if (!str) return '';
                    return String(str).replace(/'/g, "\\\\'");
                }

                // Initial fetch
                fetchGames();
            </script>
        </body>
        </html>
        """
        
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        \(html)
        """
        
        connection.send(content: Data(response.utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func sendJSONResponse(to connection: NWConnection, status: String, filename: String, size: Int) {
        let json = "{\"status\":\"\(status)\",\"filename\":\"\(filename)\",\"size\":\(size)}"
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(json.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(json)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func sendErrorResponse(to connection: NWConnection, message: String) {
        let escaped = message.replacingOccurrences(of: "\"", with: "\\\"")
        let json = "{\"status\":\"ERROR\",\"error\":\"\(escaped)\"}"
        let response = """
        HTTP/1.1 400 Bad Request\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(json.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(json)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func send404(to connection: NWConnection) {
        let notFound = "404 Not Found"
        let response = """
        HTTP/1.1 404 Not Found\r
        Content-Length: \(notFound.utf8.count)\r
        Connection: close\r
        \r
        \(notFound)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            var addr = ptr.pointee.ifa_addr.pointee
            
            // Check for IPv4 and non-loopback
            if addr.sa_family == UInt8(AF_INET) && (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let name = String(cString: hostname)
                    if !name.hasPrefix("127.") {
                        address = name
                        break
                    }
                }
            }
        }
        return address
    }
}
