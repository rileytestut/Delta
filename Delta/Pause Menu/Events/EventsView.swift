//
//  EventsView.swift
//  Delta
//
//  Created by Natalie Pekker on 9/22/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore

import Roxas

struct EventsView: View
{
    var game: Game
    var eventHandler: ((Event) -> Void)?
    
    @SwiftUI.State
    private var events: [Event]?

    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    // No rows, just the footer as an intro above the events.
                } footer: {
                    Text("DLC unlocks certain features that are not normally in the game, and can only be completed once per save file.")
                }
                
                if let events
                {
                    ForEach(events) { event in
                        EventRow(event: event)
                    }
                }
            }
            .navigationLinkIndicatorVisibility(.hidden)
            .navigationTitle("DLC")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event, eventHandler: eventHandler)
            }
            .overlay {
                if let events
                {
                    if events.isEmpty
                    {
                        ContentUnavailableView("No DLC", systemImage: "arrow.down.circle.dotted", description: Text("There is no DLC currently available for this game. Please check back again later.").font(.body))
                    }
                }
                else
                {
                    ProgressView()
                }
            }
            .toolbar {
                if #available(iOS 26, *)
                {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
                else
                {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(RSTSystemLocalizedString("Done")) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            do
            {
                var events = try await EventManager.shared.fetchEvents(for: game)
                
                #if !BETA
                if !PurchaseManager.shared.isActivePatron
                {
                    events = events.filter { !$0.isPatronEvent }
                }
                #endif
                
                self.events = events
            }
            catch
            {
                Logger.main.error("Failed to fetch events for game \(game.name, privacy: .public) (\(game.identifier, privacy: .public)). \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

private struct EventRow: View
{
    var event: Event

    var body: some View {
        Section {
            NavigationLink(value: event) {
                EventImage(url: event.imageURL)
            }
            .listRowInsets(EdgeInsets())
        } header: {
            Text(event.name)
        } footer: {
            Text(event.summary)
        }
    }
}
