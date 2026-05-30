//
//  AdvancedSettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import OSLog

struct AdvancedSettingsView: View
{
    @AppStorage(Settings.Name.opensGamesInNewWindow.rawValue)
    private var opensGamesInNewWindow: Bool = false

    @AppStorage(Settings.Name.pauseWhileInactive.rawValue)
    private var pauseWhileInactive: Bool = true

    var body: some View {
        Form {
            if UIApplication.shared.supportsMultipleScenes
            {
                Section {
                    Toggle("Pause While Inactive", isOn: $pauseWhileInactive)
                        .onChange(of: pauseWhileInactive) { _, newValue in
                            Settings.pauseWhileInactive = newValue
                        }

                    Toggle("Open Games in New Window", isOn: $opensGamesInNewWindow)
                        .onChange(of: opensGamesInNewWindow) { _, newValue in
                            Settings.opensGamesInNewWindow = newValue
                        }
                } header: {
                    Text("Multitasking")
                } footer: {
                    Text("Automatically pause games when they are not the active window.")
                }
            }

            Section {
                NavigationLink(destination: AppIconShortcutsViewController.ViewRepresentable().ignoresSafeArea()) {
                    Text("Home Screen Shortcuts")
                }
            }
            
            Section {
                ExportLogRow()
            }
        }
        .tint(.accentColor)
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExportLogRow: View
{
    @SwiftUI.State
    private var isExporting = false

    @SwiftUI.State
    private var exportedURL: URL?

    var body: some View {
        Button {
            exportLog()
        } label: {
            HStack {
                Text("Export Error Log")
                    .foregroundStyle(.primary)
                Spacer()
                if isExporting {
                    ProgressView()
                }
            }
        }
        .disabled(isExporting)
        .quickLookPreview($exportedURL)
        .onChange(of: exportedURL) { oldValue, newValue in
            // Clean up the temp directory when preview is dismissed.
            if newValue == nil, let oldValue
            {
                try? FileManager.default.removeItem(at: oldValue.deletingLastPathComponent())
            }
        }
    }

    private func exportLog()
    {
        isExporting = true

        Task.detached(priority: .userInitiated)
        {
            let outputDirectory = FileManager.default.uniqueTemporaryURL()

            do {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let position = store.position(timeIntervalSinceLatestBoot: 0)
                let predicate = NSPredicate(format: "subsystem IN %@", [Logger.deltaSubsystem, Logger.harmonySubsystem])

                let entries = try store.getEntries(at: position, matching: predicate)
                    .compactMap { $0 as? OSLogEntryLog }
                    .map { "[\($0.date.formatted())] [\($0.category)] [\($0.level.localizedName)] \($0.composedMessage)" }

                let outputText = entries.joined(separator: "\n")

                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let outputURL = outputDirectory.appendingPathComponent("Delta-\(formatter.string(from: .now)).log")
                try outputText.write(to: outputURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    exportedURL = outputURL
                    isExporting = false
                }
            }
            catch
            {
                Logger.main.error("Failed to export logs. \(error.localizedDescription, privacy: .public)")

                // If the directory was never created, try? swallows the "no such file" error.
                try? FileManager.default.removeItem(at: outputDirectory)

                await MainActor.run { isExporting = false }
            }
        }
    }
}
