//
//  AudioObserver.swift
//  Delta
//
//  Created by Caroline Moore on 7/23/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import AVFoundation
import Observation

@available(iOS 27, *)
@MainActor @Observable
class AudioObserver
{
    static let shared = AudioObserver()
    
    private(set) var volume = Double(AVAudioSession.sharedInstance().outputVolume)
    
    @ObservationIgnored
    private var isSessionActive = false
    
    @ObservationIgnored
    private var volumeObservation: NSKeyValueObservation?
    
    @ObservationIgnored
    private var sessionObservations: [NotificationCenter.ObservationToken] = []
    
    private init()
    {
        self.sessionObservations = [
            NotificationCenter.default.addObserver(of: AVAudioSession.sharedInstance(), for: AVAudioSession.DidBecomeActiveMessage.self) { _ in
                self.isSessionActive = true
            },
            NotificationCenter.default.addObserver(of: AVAudioSession.sharedInstance(), for: AVAudioSession.DidBecomeInactiveMessage.self) { _ in
                self.isSessionActive = false
            }
        ]
    }
}

@available(iOS 27, *)
extension AudioObserver
{
    func startMonitoring()
    {
        self.volumeObservation?.invalidate()
        self.volumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume) { session, _ in
            DispatchQueue.main.async {
                self.volume = Double(session.outputVolume)
            }
        }
        
        guard !self.isSessionActive else {
            self.volume = Double(AVAudioSession.sharedInstance().outputVolume)
            return
        }
        
        // Off the main thread because setCategory/setActive can block.
        Task.detached(priority: .userInitiated)
        {
            let session = AVAudioSession.sharedInstance()
            
            do
            {
                try session.setCategory(.ambient)
                try session.setActive(true)
            }
            catch
            {
                Logger.main.error("Failed to activate audio session for volume monitoring. \(error.localizedDescription, privacy: .public)")
            }
            
            let volume = Double(session.outputVolume) // only guaranteed to be accurate once a session is active, so re-read it.
            await MainActor.run { self.volume = volume }
        }
    }
    
    func stopMonitoring()
    {
        self.volumeObservation?.invalidate()
        self.volumeObservation = nil
    }
}
