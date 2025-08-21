# YouTube Streaming Implementation Plan

## Technical Architecture

### 1. System Overview
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   NES Emulator │    │  Frame Capture   │    │  Video Encoder  │
│     (60 FPS)   │───▶│   (RGB565→RGB8)  │───▶│   (H.264/AAC)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │  Frame Buffer   │    │   RTMP Client   │
                       │   (Queue)       │    │  (YouTube API)  │
                       └──────────────────┘    └─────────────────┘
```

### 2. Core Components

#### A. Frame Capture System
```swift
protocol FrameCaptureDelegate: AnyObject {
    func didCaptureFrame(_ frame: VideoFrame)
}

class NESFrameCapture {
    private let frameBuffer: CircularBuffer<VideoFrame>
    private let captureQueue: DispatchQueue
    
    func captureFrame(from emulatorBridge: NESEmulatorBridge) {
        // Hook into existing video callback
        // Convert RGB565 to RGB888
        // Add timestamp and metadata
    }
}
```

#### B. Video Encoding Pipeline
```swift
class VideoEncoder {
    private let encodingQueue: DispatchQueue
    private let ffmpegSession: FFmpegKit?
    
    func encodeFrame(_ frame: VideoFrame) async throws -> EncodedPacket {
        // Hardware-accelerated H.264 encoding
        // Maintain 60fps timing
        // Optimize for streaming quality
    }
}
```

#### C. YouTube RTMP Integration
```swift
class YouTubeStreamingClient {
    private let rtmpURL: String
    private let streamKey: String
    private let networkQueue: DispatchQueue
    
    func startStream() async throws {
        // Authenticate with YouTube API
        // Get streaming endpoint
        // Establish RTMP connection
    }
    
    func sendVideoPacket(_ packet: EncodedPacket) async throws {
        // Send H.264 video data
        // Handle network errors
        // Monitor stream health
    }
}
```

## Implementation Details

### Phase 1: Foundation Setup

#### 1.1 Add Dependencies
```ruby
# Podfile
target 'Delta' do
    # Existing pods...
    pod 'FFmpegKit', '~> 6.0'
    pod 'FFmpegKit-Full', '~> 6.0'  # Full codec support
end
```

#### 1.2 Create Streaming Framework
```swift
// Delta/Streaming/StreamingManager.swift
public class StreamingManager: ObservableObject {
    @Published var isStreaming: Bool = false
    @Published var streamStatus: StreamStatus = .idle
    
    private let videoEncoder: VideoEncoder
    private let audioEncoder: AudioEncoder
    private let rtmpClient: RTMPClient
    
    func startStreaming() async throws {
        // Initialize encoders
        // Connect to YouTube
        // Begin frame processing
    }
}
```

#### 1.3 Frame Capture Integration
```swift
// Cores/NESDeltaCore/NESDeltaCore/Bridge/NESEmulatorBridge.swift
extension NESEmulatorBridge {
    private var streamingManager: StreamingManager? {
        return StreamingManager.shared
    }
    
    // Hook into existing video callback
    private func processVideoFrameForStreaming(_ buffer: UnsafePointer<UInt8>) {
        guard let streamingManager = streamingManager,
              streamingManager.isStreaming else { return }
        
        let frame = VideoFrame(
            data: Data(bytes: buffer, count: 256 * 240 * 2), // RGB565
            timestamp: CACurrentMediaTime(),
            format: .rgb565,
            dimensions: CGSize(width: 256, height: 240)
        )
        
        streamingManager.processVideoFrame(frame)
    }
}
```

### Phase 2: Video Encoding

#### 2.1 Video Frame Processing
```swift
// Delta/Streaming/VideoEncoder.swift
class VideoEncoder {
    private let encodingQueue: DispatchQueue
    private let frameBuffer: CircularBuffer<VideoFrame>
    
    func processFrame(_ frame: VideoFrame) async throws {
        // Convert RGB565 to RGB888
        let rgb888Frame = convertToRGB888(frame)
        
        // Upscale to 720p for better streaming quality
        let upscaledFrame = upscaleFrame(rgb888Frame, to: CGSize(width: 1280, height: 720))
        
        // Encode to H.264
        let encodedPacket = try await encodeFrame(upscaledFrame)
        
        // Send to RTMP client
        try await rtmpClient.sendVideoPacket(encodedPacket)
    }
    
    private func convertToRGB888(_ frame: VideoFrame) -> VideoFrame {
        // RGB565 (16-bit) to RGB888 (24-bit) conversion
        // Use Accelerate framework for performance
    }
    
    private func upscaleFrame(_ frame: VideoFrame, to size: CGSize) -> VideoFrame {
        // Use Core Image filters for high-quality upscaling
        // Maintain aspect ratio with letterboxing
    }
}
```

#### 2.2 FFmpeg Integration
```swift
// Delta/Streaming/FFmpegWrapper.swift
class FFmpegWrapper {
    private var ffmpegSession: FFmpegKit?
    
    func initializeEncoder() throws {
        // Configure H.264 encoder settings
        let settings = [
            "preset": "ultrafast",        // Low latency
            "tune": "zerolatency",        // Streaming optimized
            "profile": "baseline",        // Compatibility
            "level": "3.1",              // 720p60 support
            "crf": "23",                 // Quality setting
            "maxrate": "4M",             // Max bitrate
            "bufsize": "8M"              // Buffer size
        ]
        
        ffmpegSession = try createFFmpegSession(with: settings)
    }
    
    func encodeFrame(_ frame: VideoFrame) throws -> Data {
        // Use FFmpegKit for hardware-accelerated encoding
        // Return H.264 packet data
    }
}
```

### Phase 3: YouTube Integration

#### 3.1 YouTube API Authentication
```swift
// Delta/Streaming/YouTubeAPI.swift
class YouTubeAPI {
    private let clientID: String
    private let clientSecret: String
    private var accessToken: String?
    
    func authenticate() async throws -> String {
        // OAuth 2.0 flow for YouTube Data API v3
        // Request streaming permissions
        // Return access token
    }
    
    func createLiveStream(title: String, description: String) async throws -> LiveStream {
        // Create YouTube live stream
        // Get RTMP endpoint and stream key
        // Configure stream settings
    }
}
```

#### 3.2 RTMP Client Implementation
```swift
// Delta/Streaming/RTMPClient.swift
class RTMPClient {
    private let rtmpURL: String
    private let streamKey: String
    private var connection: RTMPConnection?
    
    func connect() async throws {
        // Establish RTMP connection
        // Send handshake packets
        // Configure stream parameters
    }
    
    func sendVideoPacket(_ packet: EncodedPacket) async throws {
        // Send H.264 video data
        // Maintain timing synchronization
        // Handle network errors
    }
    
    func sendAudioPacket(_ packet: EncodedPacket) async throws {
        // Send AAC audio data
        // Sync with video timing
    }
}
```

### Phase 4: User Interface

#### 4.1 Streaming Controls
```swift
// Delta/Streaming/StreamingControlsView.swift
struct StreamingControlsView: View {
    @ObservedObject var streamingManager: StreamingManager
    
    var body: some View {
        VStack {
            // Stream status indicator
            StreamStatusView(status: streamingManager.streamStatus)
            
            // Start/Stop button
            Button(action: toggleStreaming) {
                Text(streamingManager.isStreaming ? "Stop Stream" : "Start Stream")
            }
            
            // Quality settings
            if streamingManager.isStreaming {
                QualitySettingsView()
            }
        }
    }
}
```

#### 4.2 Settings Integration
```swift
// Delta/Settings/Streaming/StreamingSettingsViewController.swift
class StreamingSettingsViewController: UIViewController {
    @IBOutlet weak var youtubeChannelField: UITextField!
    @IBOutlet weak var streamQualitySegmentedControl: UISegmentedControl!
    @IBOutlet weak var enableStreamingSwitch: UISwitch!
    
    func configureStreaming() {
        // YouTube channel configuration
        // Quality preset selection
        // Authentication status
    }
}
```

## Performance Considerations

### 1. Memory Management
- **Frame Buffer Size**: Limit to 2-3 seconds of frames
- **Circular Buffer**: Prevent memory leaks
- **Auto-release**: Clear processed frames immediately

### 2. CPU/GPU Optimization
- **Hardware Encoding**: Use VideoToolbox when available
- **Background Processing**: Move encoding to background queue
- **Quality Scaling**: Adjust encoding quality based on device performance

### 3. Network Optimization
- **Adaptive Bitrate**: Adjust based on network conditions
- **Connection Pooling**: Reuse RTMP connections
- **Error Recovery**: Automatic reconnection on failures

## Testing Strategy

### 1. Unit Tests
- Frame capture accuracy
- Encoding quality validation
- Network error handling

### 2. Integration Tests
- End-to-end streaming pipeline
- Performance benchmarks
- Memory usage monitoring

### 3. User Testing
- Content creator feedback
- Stream quality assessment
- Usability testing

## Deployment Considerations

### 1. App Store Compliance
- **Privacy**: Stream data handling
- **Permissions**: Camera/microphone access
- **Terms**: YouTube API usage compliance

### 2. Performance Monitoring
- **Metrics**: Frame drops, encoding latency
- **Crash Reporting**: Streaming-related issues
- **Analytics**: Usage patterns and quality metrics

### 3. Rollout Strategy
- **Beta Testing**: Limited user group
- **Feature Flags**: Gradual rollout
- **Fallback**: Graceful degradation on errors

---

*This implementation plan will be refined based on testing results and user feedback.*
