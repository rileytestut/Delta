import Foundation
import Network
import Combine

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
                    
                    // Check if headers are received
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
                        let path = parts.count > 1 ? parts[1] : "/"
                        
                        if method == "GET" && path == "/" {
                            self.sendHTMLPage(to: connection)
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
                            
                            if bodyReceivedSoFar >= contentLength {
                                let bodyData = receivedData.subdata(in: bodyStartIndex..<receivedData.count)
                                self.processUpload(headers: lines, body: bodyData, connection: connection)
                            } else {
                                // Wait for remaining body bytes
                                func readRemainingBody() {
                                    let remaining = contentLength - (receivedData.count - bodyStartIndex)
                                    connection.receive(minimumIncompleteLength: 1, maximumLength: max(remaining, 65536)) { moreData, _, isDone, _ in
                                        if let moreData = moreData {
                                            receivedData.append(moreData)
                                        }
                                        if (receivedData.count - bodyStartIndex) >= contentLength || isDone {
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
                } else if isComplete || error != nil {
                    connection.cancel()
                }
            }
        }
        
        readNext()
    }
    
    private func processUpload(headers: [String], body: Data, connection: NWConnection) {
        // Look for multipart boundary
        var boundary: String?
        for line in headers {
            if line.lowercased().contains("boundary=") {
                let parts = line.components(separatedBy: "boundary=")
                if parts.count > 1 {
                    boundary = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "- \r\n\""))
                }
            }
        }
        
        if let boundary = boundary,
           let filename = extractFilename(from: body),
           let fileData = extractFileData(from: body, boundary: boundary) {
            
            let destURL = TVGameManager.shared.romsDirectory.appendingPathComponent(filename)
            try? fileData.write(to: destURL)
            
            DispatchQueue.main.async {
                self.lastUploadedFileName = filename
                TVGameManager.shared.loadGames()
            }
            
            self.sendJSONResponse(to: connection, status: "OK", filename: filename)
        } else {
            self.sendErrorResponse(to: connection, message: "Invalid upload data")
        }
    }
    
    private func extractFilename(from data: Data) -> String? {
        guard let text = String(data: data.prefix(2048), encoding: .isoLatin1) else { return nil }
        if let range = text.range(of: "filename=\"") {
            let rest = text[range.upperBound...]
            if let endRange = rest.range(of: "\"") {
                let name = String(rest[..<endRange.lowerBound])
                return name.replacingOccurrences(of: "/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    private func extractFileData(from data: Data, boundary: String) -> Data? {
        let boundaryData = Data("--\(boundary)".utf8)
        let headerEndData = Data("\r\n\r\n".utf8)
        
        guard let firstBoundaryRange = data.range(of: boundaryData) else { return nil }
        guard let headerEndRange = data.range(of: headerEndData, in: firstBoundaryRange.upperBound..<data.count) else { return nil }
        
        let fileContentStart = headerEndRange.upperBound
        let endBoundaryData = Data("\r\n--\(boundary)".utf8)
        
        if let endBoundaryRange = data.range(of: endBoundaryData, in: fileContentStart..<data.count) {
            return data.subdata(in: fileContentStart..<endBoundaryRange.lowerBound)
        } else {
            return data.subdata(in: fileContentStart..<data.count)
        }
    }
    
    private func sendHTMLPage(to connection: NWConnection) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Delta on Apple TV - ROM Uploader</title>
            <style>
                * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
                body { background: #0f111a; color: #f0f3f6; margin: 0; padding: 40px 20px; display: flex; flex-direction: column; align-items: center; }
                .container { max-width: 600px; width: 100%; background: #1a1e2d; border-radius: 20px; padding: 36px; box-shadow: 0 10px 40px rgba(0,0,0,0.5); border: 1px solid #2a3048; text-align: center; }
                h1 { margin-top: 0; font-size: 28px; font-weight: 700; background: linear-gradient(135deg, #FF5E62, #FF9966); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
                p { color: #8e9bb0; font-size: 15px; margin-bottom: 25px; line-height: 1.5; }
                .drop-zone { border: 2px dashed #434c6e; border-radius: 16px; padding: 40px 20px; background: #141724; cursor: pointer; transition: all 0.2s ease; margin-bottom: 20px; }
                .drop-zone:hover, .drop-zone.dragover { border-color: #FF5E62; background: #1c2032; }
                .icon { font-size: 48px; margin-bottom: 12px; }
                input[type=file] { display: none; }
                .btn { background: linear-gradient(135deg, #FF5E62, #FF9966); color: white; border: none; padding: 12px 28px; border-radius: 30px; font-size: 16px; font-weight: 600; cursor: pointer; transition: transform 0.1s ease; display: inline-block; margin-top: 10px; }
                .btn:active { transform: scale(0.97); }
                .status { margin-top: 20px; font-weight: 500; font-size: 15px; min-height: 24px; color: #4ade80; }
                .supported { margin-top: 30px; font-size: 13px; color: #64748b; border-top: 1px solid #242a40; padding-top: 20px; }
                .badge { display: inline-block; background: #262c42; padding: 4px 10px; border-radius: 8px; margin: 3px; font-family: monospace; font-size: 12px; color: #94a3b8; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Delta for Apple TV</h1>
                <p>Transfer ROMs wirelessly to your Apple TV library.</p>
                
                <div class="drop-zone" id="dropZone" onclick="document.getElementById('fileInput').click()">
                    <div class="icon">🎮</div>
                    <div style="font-size: 18px; font-weight: 600; margin-bottom: 6px;">Choose or Drop ROM Files Here</div>
                    <div style="font-size: 13px; color: #8e9bb0;">Supports NES, SNES, and N64 files</div>
                    <input type="file" id="fileInput" multiple accept=".nes,.smc,.sfc,.fig,.n64,.z64,.v64">
                </div>
                
                <div id="status" class="status"></div>
                
                <div class="supported">
                    <strong>Supported Formats:</strong><br>
                    <span class="badge">.nes</span>
                    <span class="badge">.smc</span>
                    <span class="badge">.sfc</span>
                    <span class="badge">.n64</span>
                    <span class="badge">.z64</span>
                    <span class="badge">.v64</span>
                </div>
            </div>

            <script>
                const fileInput = document.getElementById('fileInput');
                const dropZone = document.getElementById('dropZone');
                const status = document.getElementById('status');

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

                async function uploadFiles(files) {
                    for (let file of files) {
                        status.style.color = '#38bdf8';
                        status.innerText = 'Uploading ' + file.name + '...';
                        
                        let formData = new FormData();
                        formData.append('file', file);
                        
                        try {
                            let resp = await fetch('/upload', { method: 'POST', body: formData });
                            let json = await resp.json();
                            if (json.status === 'OK') {
                                status.style.color = '#4ade80';
                                status.innerText = '✓ ' + file.name + ' uploaded successfully!';
                            } else {
                                status.style.color = '#f87171';
                                status.innerText = '✗ Error: ' + (json.error || 'Failed');
                            }
                        } catch (err) {
                            status.style.color = '#f87171';
                            status.innerText = '✗ Connection error: ' + err.message;
                        }
                    }
                }
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
    
    private func sendJSONResponse(to connection: NWConnection, status: String, filename: String) {
        let json = "{\"status\":\"\(status)\",\"filename\":\"\(filename)\"}"
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(json.utf8.count)\r
        Connection: close\r
        \r
        \(json)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private func sendErrorResponse(to connection: NWConnection, message: String) {
        let json = "{\"status\":\"ERROR\",\"error\":\"\(message)\"}"
        let response = """
        HTTP/1.1 400 Bad Request\r
        Content-Type: application/json\r
        Content-Length: \(json.utf8.count)\r
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
