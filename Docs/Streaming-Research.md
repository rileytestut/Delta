# YouTube Streaming Integration Research for Delta NES Emulator

## Overview
This document outlines the research and implementation plan for adding YouTube streaming support to the NES emulator in Delta. The goal is to enable content creators to stream their NES gameplay directly to YouTube channels with minimal complexity and maximum compatibility.

## Current Architecture Analysis

### NES Emulator Structure
- **NESDeltaCore**: Main NES emulation framework
- **Video Pipeline**: Uses `VideoManager` with support for both OpenGL ES and Metal rendering
- **Frame Rate**: 60 FPS (16.67ms per frame)
- **Resolution**: 256x240 pixels (NES native resolution)
- **Video Format**: RGB565 bitmap format

### Video Rendering Flow
1. **NESEmulatorBridge** receives video frames from emulator core
2. **VideoManager** processes frames through `VideoProcessor`
3. **BitmapProcessor** handles RGB565 format conversion
4. **RenderThread** manages frame rendering timing
5. **GameView** displays processed frames

## Modern Streaming Solutions (2025)

### 1. YouTube Live Streaming API
- **RTMP Endpoint**: YouTube provides RTMP URLs for live streaming
- **H.264/AAC Requirements**: Standard video/audio codec support
- **Resolution Support**: Up to 4K, but 720p recommended for retro games
- **Frame Rate**: 30fps or 60fps supported

### 2. FFmpeg Integration
- **Real-time Encoding**: Hardware-accelerated H.264 encoding
- **Low Latency**: Sub-100ms encoding delay
- **iOS Compatibility**: Available through FFmpegKit for iOS
- **Format Conversion**: RGB565 → H.264 pipeline

### 3. Alternative: WebRTC
- **Browser-based**: Could leverage existing WebKit infrastructure
- **Lower Latency**: Better for real-time interaction
- **Complexity**: More complex setup than RTMP

## Recommended Implementation Approach

### Phase 1: Core Streaming Infrastructure
```
Delta/
├── Streaming/
│   ├── StreamingManager.swift          # Main streaming coordinator
│   ├── VideoEncoder.swift             # H.264 video encoding
│   ├── AudioEncoder.swift             # AAC audio encoding
│   ├── RTMPClient.swift               # YouTube RTMP connection
│   └── StreamingSettings.swift        # Configuration options
```

### Phase 2: NES Integration
```
Cores/NESDeltaCore/
├── NESDeltaCore/
│   ├── Bridge/
│   │   ├── NESEmulatorBridge.swift    # Existing + streaming hooks
│   │   └── NESStreamingBridge.swift   # New streaming interface
│   └── Streaming/
│       ├── NESStreamingManager.swift  # NES-specific streaming
│       └── NESFrameCapture.swift      # Frame capture logic
```

## Technical Implementation Details

### 1. Frame Capture Integration
```swift
// Hook into existing video pipeline
extension NESEmulatorBridge {
    func captureFrameForStreaming(_ frameData: UnsafePointer<UInt8>) {
        guard streamingManager.isStreaming else { return }
        
        // Convert RGB565 to RGB888 for encoding
        let rgb888Data = convertRGB565ToRGB888(frameData)
        streamingManager.processVideoFrame(rgb888Data)
    }
}
```

### 2. Video Encoding Pipeline
```swift
class VideoEncoder {
    private var ffmpegSession: FFmpegKit?
    
    func encodeFrame(_ frameData: Data, timestamp: TimeInterval) {
        // Use FFmpegKit for hardware-accelerated encoding
        // Convert to H.264 with appropriate settings for YouTube
    }
}
```

### 3. YouTube RTMP Integration
```swift
class RTMPClient {
    private var rtmpURL: String
    private var streamKey: String
    
    func connect() async throws {
        // Establish RTMP connection to YouTube
        // Handle authentication and stream setup
    }
    
    func sendVideoPacket(_ packet: Data) async throws {
        // Send H.264 video packets
    }
}
```

## Dependencies and Libraries

### Required Libraries
1. **FFmpegKit**: Video/audio encoding
2. **Network.framework**: RTMP connection handling
3. **CoreMedia**: Frame timing and synchronization

### Podfile Addition
```ruby
target 'Delta' do
    # Existing pods...
    pod 'FFmpegKit', '~> 6.0'
end
```

## Configuration Options

### Streaming Settings
- **Resolution**: 720p (1280x720) upscaled from 256x240
- **Frame Rate**: 60fps (maintains original NES timing)
- **Bitrate**: 2-4 Mbps for good quality
- **Audio**: 44.1kHz, 128kbps AAC

### User Interface
- **Streaming Toggle**: Simple on/off switch in pause menu
- **Channel Setup**: YouTube channel configuration
- **Quality Settings**: Basic quality presets
- **Stream Status**: Live indicator and viewer count

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Set up FFmpegKit integration
- [ ] Create basic video encoding pipeline
- [ ] Implement frame capture from NES emulator

### Phase 2: YouTube Integration (Week 3-4)
- [ ] Implement RTMP client for YouTube
- [ ] Add authentication and stream setup
- [ ] Test basic streaming functionality

### Phase 3: Polish & Testing (Week 5-6)
- [ ] Add user interface controls
- [ ] Implement error handling and recovery
- [ ] Performance optimization and testing

## Challenges and Considerations

### 1. Performance Impact
- **Encoding Overhead**: H.264 encoding adds CPU/GPU load
- **Memory Usage**: Frame buffering for smooth streaming
- **Battery Life**: Streaming significantly increases power consumption

### 2. Network Requirements
- **Upload Speed**: Minimum 5 Mbps for 720p60 streaming
- **Stability**: Consistent connection required for live streaming
- **Fallback**: Handle network interruptions gracefully

### 3. YouTube API Limitations
- **Rate Limits**: API call restrictions
- **Authentication**: OAuth 2.0 flow for channel access
- **Stream Keys**: Secure handling of streaming credentials

## Alternative Approaches

### 1. Local Recording + Upload
- Record gameplay locally in high quality
- Upload to YouTube after completion
- Simpler implementation, no real-time constraints

### 2. Browser-based Streaming
- Leverage existing WebKit infrastructure
- Use WebRTC for streaming
- More complex but potentially lower latency

### 3. Third-party Service Integration
- Integrate with OBS Studio or similar
- Use existing streaming infrastructure
- Less control but proven reliability

## Recommended Next Steps

1. **Research FFmpegKit iOS Integration**: Verify compatibility and performance
2. **Create Proof of Concept**: Basic frame capture and encoding
3. **Test YouTube RTMP**: Validate streaming endpoint connectivity
4. **Performance Benchmarking**: Measure impact on emulation performance
5. **User Experience Design**: Design simple streaming controls

## Resources and References

- [YouTube Live Streaming API Documentation](https://developers.google.com/youtube/v3/live/docs)
- [FFmpegKit iOS Integration](https://github.com/arthenica/ffmpeg-kit)
- [RTMP Protocol Specification](https://www.adobe.com/content/dam/acom/en/devnet/rtmp/pdf/rtmp_specification_1.0.pdf)
- [iOS Video Processing Best Practices](https://developer.apple.com/documentation/avfoundation/media_playback_and_selection)

---

*This document will be updated as research progresses and implementation details are refined.*
