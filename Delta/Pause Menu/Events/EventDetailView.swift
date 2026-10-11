//
//  EventDetailView.swift
//  Delta
//
//  Created by Natalie Pekker on 9/22/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore

struct EventDetailView: View
{
    var event: Event
    var eventHandler: ((Event) -> Void)?
    
    @Environment(\.dismiss)
    private var dismiss
    
    @State
    private var isDownloadingEvent: Bool = false
    
    @State
    private var downloadError: Error?
    
    @State
    private var isShowingErrorAlert: Bool = false
    
    @State
    private var isShowingConfirmationAlert: Bool = false

    var body: some View {
        List {
            Section {
                EventImage(url: event.imageURL)
            }
            
            Section {
                Text(event.detailedDescription)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear) // Disable inset grouped appearance
            }
            
            Section {
                Button(action: { isShowingConfirmationAlert = true }) {
                    Text("Start Event")
                        .frame(maxWidth: .infinity)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .foregroundStyle(Color(.deltaPurple))
                }
            }
            .alert("Are you sure you'd like to start “\(event.name)”?", isPresented: $isShowingConfirmationAlert) {
                Button("Start DLC", action: startEvent)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will restart the game, and any unsaved changes will be lost.")
            }
        }
        .alert("Unable to Start DLC", isPresented: $isShowingErrorAlert, presenting: downloadError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension EventDetailView
{
    func startEvent()
    {
        Task<Void, Never> {
            do
            {
                try await self.downloadPatch()
                
                self.eventHandler?(self.event)
            }
            catch
            {
                Logger.main.error("Failed to start event \(self.event.id). \(error.localizedDescription, privacy: .public)")
                
                self.downloadError = error
                self.isShowingErrorAlert = true
            }
        }
    }
    
    func downloadPatch() async throws
    {
        self.isDownloadingEvent = true
        defer {
            self.isDownloadingEvent = false
        }
        
        guard let patchURL = self.event.patchURL else { throw EventError.unsupportedGame }
        guard case let filename = patchURL.lastPathComponent, filename.count > 0 else { throw EventError.invalidEvent }
        
        let (fileURL, httpResponse) = try await URLSession.shared.download(from: patchURL)
        if let response = httpResponse as? HTTPURLResponse
        {
            guard response.statusCode != 404 else {
                throw URLError(.fileDoesNotExist, userInfo: [NSURLErrorKey: patchURL])
            }
        }
        
        let destinationURL = try EventManager.patchURL(for: self.event)
        try FileManager.default.copyItem(at: fileURL, to: destinationURL, shouldReplace: true)
        
        do
        {
            try FileManager.default.removeItem(at: fileURL)
        }
        catch
        {
            Logger.main.error("Failed to remove temporary downloaded event patch file at \(fileURL, privacy: .public). \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct EventImage: View
{
    var url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } placeholder: {
            ZStack {
                Color(uiColor: .deltaLightPurple).opacity(0.3)

                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            .aspectRatio(3/2, contentMode: .fit) // GBA screen aspect ratio.
        }
        .listRowInsets(EdgeInsets())
    }
}
