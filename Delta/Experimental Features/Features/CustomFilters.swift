//
//  CustomFilters.swift
//  Delta
//
//  Created by Shane on 10/5/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

import DeltaCore
import DeltaFeatures

// Shaders bundled with Delta (in Shaders/*.cikernel), named after their file names. Every system offers the same shaders.
enum BundledShader: String, CaseIterable
{
    case crt = "CRT"
    case crtCurved = "CRTCurved"
    case originalGameBoy = "OriginalGameBoy"
    case originalGBA = "OriginalGBA"

    var fileURL: URL? {
        return Bundle.main.url(forResource: self.rawValue, withExtension: "cikernel")
    }

    var localizedName: String {
        switch self
        {
        case .crt: return NSLocalizedString("CRT", comment: "")
        case .crtCurved: return NSLocalizedString("CRT (Curved)", comment: "")
        case .originalGameBoy: return NSLocalizedString("Original Game Boy", comment: "")
        case .originalGBA: return NSLocalizedString("Original GBA", comment: "")
        }
    }
}

enum ScreenFilter: Hashable
{
    case off
    case bundled(BundledShader)

    // Path of a shader imported by the user, relative to `ScreenFilter.customFiltersDirectory`.
    case custom(String)

    static var customFiltersDirectory: URL {
        return URL.documentsDirectory.appendingPathComponent("Custom Filters", isDirectory: true)
    }

    var fileURL: URL? {
        switch self
        {
        case .off: return nil
        case .bundled(let shader): return shader.fileURL
        case .custom(let path): return ScreenFilter.customFiltersDirectory.appendingPathComponent(path)
        }
    }

    // Copies the shader at fileURL into the Custom Filters directory (after making sure it compiles), and returns a ScreenFilter that uses it.
    static func importShader(at fileURL: URL) throws -> ScreenFilter
    {
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing
            {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else { throw CustomScreenFilter.Error.unreadable }
        _ = try CustomScreenFilter.kernel(source: source)
        
        let destinationURL = ScreenFilter.customFiltersDirectory.appendingPathComponent(fileURL.lastPathComponent)
        
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try source.write(to: destinationURL, atomically: true, encoding: .utf8)

        return .custom(fileURL.lastPathComponent)
    }
}

extension ScreenFilter: RawRepresentable
{
    private static let customPrefix = "custom:"

    init?(rawValue: String)
    {
        if rawValue == "off"
        {
            self = .off
        }
        else if rawValue.hasPrefix(ScreenFilter.customPrefix)
        {
            self = .custom(String(rawValue.dropFirst(ScreenFilter.customPrefix.count)))
        }
        else if let shader = BundledShader(rawValue: rawValue)
        {
            self = .bundled(shader)
        }
        else
        {
            return nil
        }
    }

    var rawValue: String {
        switch self
        {
        case .off: return "off"
        case .bundled(let shader): return shader.rawValue
        case .custom(let path): return ScreenFilter.customPrefix + path
        }
    }
}

extension ScreenFilter: LocalizedOptionValue
{
    var localizedDescription: Text {
        switch self
        {
        case .off: return Text("Off")
        case .bundled(let shader): return Text(shader.localizedName)
        case .custom(let path): return Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
        }
    }
}

// Picker for a system's filter, which also lets users import their own shader from the Files app.
struct ScreenFilterPicker: View
{
    var name: LocalizedStringKey

    @Binding
    var selection: ScreenFilter

    private enum Item: Hashable
    {
        case filter(ScreenFilter)
        case importCustom
    }

    init(name: LocalizedStringKey, selection: Binding<ScreenFilter>)
    {
        self.name = name
        self._selection = selection
    }

    var body: some View {
        let item = Binding<Item>(get: { .filter(self.selection) }, set: { item in
            switch item
            {
            case .filter(let filter): self.selection = filter
            case .importCustom: self.importCustomFilter()
            }
        })

        Picker(self.name, selection: item) {
            Text("Off").tag(Item.filter(.off))

            ForEach(BundledShader.allCases, id: \.self) { shader in
                Text(shader.localizedName).tag(Item.filter(.bundled(shader)))
            }

            if case .custom = self.selection
            {
                self.selection.localizedDescription.tag(Item.filter(self.selection))
            }

            Text("Custom…").tag(Item.importCustom)
        }
        .pickerStyle(.menu)
        .displayInline()
    }

    private func importCustomFilter()
    {
        // Present document picker with UIKit, since SwiftUI only supports one .fileImporter per screen (and each system has its own picker).
        CustomFilterImporter.shared.importFilter { result in
            switch result
            {
            case .success(let filter): self.selection = filter
            case .failure(let error): CustomFilterImporter.shared.presentAlert(for: error)
            }
        }
    }
}

private class CustomFilterImporter: NSObject, UIDocumentPickerDelegate
{
    static let shared = CustomFilterImporter()

    private var completionHandler: ((Result<ScreenFilter, Error>) -> Void)?

    func importFilter(completionHandler: @escaping (Result<ScreenFilter, Error>) -> Void)
    {
        self.completionHandler = completionHandler

        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .text], asCopy: true)
        documentPicker.delegate = self

        // Wait for the picker's menu to finish dismissing before presenting.
        DispatchQueue.main.async {
            self.topViewController?.present(documentPicker, animated: true)
        }
    }

    func presentAlert(for error: Error)
    {
        let alertController = UIAlertController(title: NSLocalizedString("Unable to Import Filter", comment: ""), error: error)
        self.topViewController?.present(alertController, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        guard let fileURL = urls.first else { return }

        let result = Result { try ScreenFilter.importShader(at: fileURL) }
        self.completionHandler?(result)
        self.completionHandler = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
    {
        self.completionHandler = nil
    }

    private var topViewController: UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var viewController = windowScene?.keyWindow?.rootViewController

        while let presentedViewController = viewController?.presentedViewController
        {
            viewController = presentedViewController
        }

        return viewController
    }
}

struct CustomFiltersOptions
{
    @Option(name: "Nintendo", description: "Screen filter for NES games.", detailView: { ScreenFilterPicker(name: "Nintendo", selection: $0) })
    var nes: ScreenFilter = .bundled(.crt)

    @Option(name: "Super Nintendo", description: "Screen filter for SNES games.", detailView: { ScreenFilterPicker(name: "Super Nintendo", selection: $0) })
    var snes: ScreenFilter = .bundled(.crt)

    @Option(name: "Sega Genesis", description: "Screen filter for Genesis games.", detailView: { ScreenFilterPicker(name: "Sega Genesis", selection: $0) })
    var genesis: ScreenFilter = .bundled(.crt)

    @Option(name: "Nintendo 64", description: "Screen filter for N64 games.", detailView: { ScreenFilterPicker(name: "Nintendo 64", selection: $0) })
    var n64: ScreenFilter = .bundled(.crt)

    @Option(name: "Game Boy Color", description: "Screen filter for Game Boy and Game Boy Color games.", detailView: { ScreenFilterPicker(name: "Game Boy Color", selection: $0) })
    var gbc: ScreenFilter = .bundled(.originalGameBoy)

    @Option(name: "Game Boy Advance", description: "Screen filter for Game Boy Advance games.", detailView: { ScreenFilterPicker(name: "Game Boy Advance", selection: $0) })
    var gba: ScreenFilter = .bundled(.originalGBA)

    @Option(name: "Nintendo DS", description: "Screen filter for Nintendo DS games. Applies to both screens.", detailView: { ScreenFilterPicker(name: "Nintendo DS", selection: $0) })
    var ds: ScreenFilter = .bundled(.originalGBA)
}

extension Feature where Options == CustomFiltersOptions
{
    // Returns the shader to apply to games of gameType, if any.
    func shaderURL(for gameType: GameType) -> URL?
    {
        guard let system = System(gameType: gameType) else { return nil }

        switch system
        {
        case .nes: return self.nes.fileURL
        case .snes: return self.snes.fileURL
        case .genesis: return self.genesis.fileURL
        case .n64: return self.n64.fileURL
        case .gbc: return self.gbc.fileURL
        case .gba: return self.gba.fileURL
        case .ds: return self.ds.fileURL
        }
    }
}
