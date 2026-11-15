//
//  ScreenOrientation.swift
//  Delta
//

import SwiftUI
import UIKit
import OSLog

import DeltaFeatures

enum ScreenOrientation: String, CaseIterable, LocalizedOptionValue
{
    case automatic
    case portrait
    case landscapeLeft
    case landscapeRight

    var localizedDescription: Text {
        switch self
        {
        case .automatic: return Text("Automatic")
        case .portrait: return Text("Portrait")
        case .landscapeLeft: return Text("Landscape Left")
        case .landscapeRight: return Text("Landscape Right")
        }
    }

    var interfaceOrientation: UIInterfaceOrientation? {
        switch self
        {
        case .automatic: return nil
        case .portrait: return .portrait
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        }
    }
}

struct ScreenOrientationOptions
{
    @Option(name: "Orientation", values: ScreenOrientation.allCases)
    var orientation: ScreenOrientation = .automatic
}

@MainActor
extension Feature where Options == ScreenOrientationOptions, Disabled == Bool
{
    func fixedInterfaceOrientation(in windowScene: UIWindowScene?) -> UIInterfaceOrientation?
    {
        guard self.isEnabled, let orientation = self.orientation.interfaceOrientation,
              let windowScene, windowScene.traitCollection.userInterfaceIdiom == .phone,
              windowScene.delegate is SceneDelegate || windowScene.delegate is GameSceneDelegate else { return nil }

        return orientation
    }

    func supportedInterfaceOrientations(for window: UIWindow?) -> UIInterfaceOrientationMask
    {
        let idiom = window?.traitCollection.userInterfaceIdiom ?? UIDevice.current.userInterfaceIdiom
        let defaultOrientations: UIInterfaceOrientationMask = idiom == .pad ? .all : .allButUpsideDown

        guard let window, let scene = window.windowScene,
              let orientation = self.fixedInterfaceOrientation(in: scene),
              let rootViewController = window.rootViewController else { return defaultOrientations }

        let viewController = self.orientationViewController(from: rootViewController)
        guard !self.isSystemPicker(viewController) else { return defaultOrientations }

        return UIInterfaceOrientationMask(rawValue: 1 << orientation.rawValue)
    }

    func updateInterfaceOrientation(in windowScene: UIWindowScene?)
    {
        guard let windowScene, windowScene.traitCollection.userInterfaceIdiom == .phone,
              windowScene.delegate is SceneDelegate || windowScene.delegate is GameSceneDelegate,
              let window = (windowScene.delegate as? UIWindowSceneDelegate)?.window ?? nil,
              let rootViewController = window.rootViewController else { return }

        let viewController = self.orientationViewController(from: rootViewController)
        rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        if let launchViewController = rootViewController as? LaunchViewController
        {
            launchViewController.gameViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        if viewController !== rootViewController
        {
            viewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        guard let orientation = self.fixedInterfaceOrientation(in: windowScene),
              !self.isSystemPicker(viewController) else { return }

        let currentOrientation: UIInterfaceOrientation
        if #available(iOS 26, *)
        {
            currentOrientation = windowScene.effectiveGeometry.interfaceOrientation
        }
        else
        {
            currentOrientation = windowScene.interfaceOrientation
        }
        guard currentOrientation != orientation else { return }

        let orientations = UIInterfaceOrientationMask(rawValue: 1 << orientation.rawValue)
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { error in
            Logger.main.error("Failed to update screen orientation: \(error.localizedDescription, privacy: .public)")
        }
    }
}

@MainActor
private extension Feature where Options == ScreenOrientationOptions, Disabled == Bool
{
    func isSystemPicker(_ viewController: UIViewController) -> Bool
    {
        return viewController is UIImagePickerController || viewController is UIDocumentPickerViewController || viewController is UIDocumentBrowserViewController
    }

    func orientationViewController(from rootViewController: UIViewController) -> UIViewController
    {
        var viewController = rootViewController
        while !self.isSystemPicker(viewController)
        {
            if let presentedViewController = viewController.presentedViewController
            {
                viewController = presentedViewController
            }
            else if let launchViewController = viewController as? LaunchViewController, let gameViewController = launchViewController.gameViewController
            {
                viewController = gameViewController
            }
            else if let navigationController = viewController as? UINavigationController, let visibleViewController = navigationController.visibleViewController
            {
                viewController = visibleViewController
            }
            else if let tabBarController = viewController as? UITabBarController, let selectedViewController = tabBarController.selectedViewController
            {
                viewController = selectedViewController
            }
            else
            {
                break
            }
        }
        return viewController
    }
}
