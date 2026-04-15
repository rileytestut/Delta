//
//  AdvancedSettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import OSLog
import QuickLook

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

    @SwiftUI.State
    private var showPreview = false

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
        .sheet(isPresented: $showPreview, onDismiss: cleanupExportedLog) {
            if let url = exportedURL
            {
                QuickLookPreview(url: url)
            }
        }
    }

    private func cleanupExportedLog()
    {
        guard let url = exportedURL else { return }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        exportedURL = nil
    }

    private func exportLog()
    {
        isExporting = true

        Task.detached(priority: .userInitiated)
        {
            // Track the created directory so we can clean it up if anything fails before the sheet takes ownership
            var pendingDirectory: URL?

            do {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let position = store.position(timeIntervalSinceLatestBoot: 0)
                let predicate = NSPredicate(format: "subsystem IN %@", [Logger.deltaSubsystem, Logger.harmonySubsystem])

                let entries = try store.getEntries(at: position, matching: predicate)
                    .compactMap { $0 as? OSLogEntryLog }
                    .map { "[\($0.date.formatted())] [\($0.category)] [\($0.level.localizedName)] \($0.composedMessage)" }

                let outputText = entries.joined(separator: "\n")

                let outputDirectory = FileManager.default.uniqueTemporaryURL()
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                pendingDirectory = outputDirectory

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let outputURL = outputDirectory.appendingPathComponent("Delta-\(formatter.string(from: .now)).log")
                try outputText.write(to: outputURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    exportedURL = outputURL
                    showPreview = true
                    isExporting = false
                }

                pendingDirectory = nil // Ownership handed off to the sheet, which will handle cleanup
            }
            catch
            {
                Logger.main.error("Failed to export logs. \(error.localizedDescription, privacy: .public)")
                
                if let directory = pendingDirectory
                {
                    try? FileManager.default.removeItem(at: directory)
                }
                
                await MainActor.run { isExporting = false }
            }
        }
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable
{
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource
    {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { url as NSURL }
    }
}
