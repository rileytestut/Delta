import SwiftUI
import GameController
import DeltaCore

struct GameLibraryView: View {
    @EnvironmentObject var gameManager: TVGameManager
    @EnvironmentObject var webServer: ROMWebServer
    
    @State private var selectedSystem: TVSystem? = nil
    @State private var selectedGame: TVGame? = nil
    @State private var hasConnectedController = false
    @State private var controllerBadgeFlash = false
    @State private var showUploadInfo = false
    
    let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 280), spacing: 32)
    ]
    
    var filteredGames: [TVGame] {
        if let system = selectedSystem {
            return gameManager.gamesBySystem[system] ?? []
        }
        return gameManager.allGames
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Header Bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delta")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [Color(red: 0.65, green: 0.35, blue: 0.95), Color(red: 0.35, green: 0.55, blue: 0.95)], startPoint: .leading, endPoint: .trailing)
                            )
                        Text(selectedSystem?.fullName ?? "All Systems (\(gameManager.allGames.count) games)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Controller Remapping Tool Button in Header
                    if hasConnectedController {
                        HeaderRemapButton {
                            self.presentControllerRemapper()
                        }
                    }
                    
                    // Controller Status Indicator with Flash Transition
                    HStack(spacing: 10) {
                        Image(systemName: hasConnectedController ? "gamecontroller.fill" : "gamecontroller")
                            .foregroundColor(controllerBadgeFlash ? .black : (hasConnectedController ? .green : .yellow))
                        Text(hasConnectedController ? "Controller Connected" : "Connect a Controller")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(controllerBadgeFlash ? .black : (hasConnectedController ? .green : .yellow))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        controllerBadgeFlash ? Color.white : (hasConnectedController ? Color.green.opacity(0.18) : Color.white.opacity(0.08))
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(controllerBadgeFlash ? Color.white : (hasConnectedController ? Color.green.opacity(0.6) : Color.clear), lineWidth: 2)
                    )
                    .scaleEffect(controllerBadgeFlash ? 1.12 : 1.0)
                    .shadow(color: controllerBadgeFlash ? Color.white.opacity(0.8) : Color.clear, radius: 12)
                    
                    // Wi-Fi Upload Server Address
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .foregroundColor(.cyan)
                        Text(webServer.serverAddress)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 48)
                .padding(.top, 24)
                .padding(.bottom, 20)
                .focusSection()
                
                // System Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        LibrarySystemTabButton(
                            title: "All Games",
                            iconName: "square.grid.2x2.fill",
                            isSelected: selectedSystem == nil,
                            action: { selectedSystem = nil }
                        )
                        
                        ForEach(TVSystem.allCases) { system in
                            LibrarySystemTabButton(
                                title: system.shortName,
                                iconName: system.systemIconName,
                                isSelected: selectedSystem == system,
                                action: { selectedSystem = system }
                            )
                        }
                        

                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 10)
                }
                .focusSection()
                
                // Main Games Grid
                if filteredGames.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("Your Library Is Empty")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Upload ROMs from your computer or phone:\nOpen this address in your browser: \(webServer.serverAddress)")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 36) {
                            ForEach(filteredGames) { game in
                                GameCardView(game: game) {
                                    self.launchGame(game)
                                }
                            }
                        }
                        .padding(.horizontal, 48)
                        .padding(.vertical, 24)
                    }
                    .focusSection()
                }
            }
        }
        .onAppear {
            self.checkControllers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in
            self.checkControllers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in
            self.checkControllers()
        }
    }
    
    private func checkControllers() {
        let isConnected = GCController.controllers().contains(where: { $0.extendedGamepad != nil })
        if isConnected && !self.hasConnectedController {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                self.controllerBadgeFlash = true
                self.hasConnectedController = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.controllerBadgeFlash = false
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.hasConnectedController = isConnected
            }
        }
    }
    
    private func presentControllerRemapper() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController,
              root.presentedViewController == nil else { return }
        root.present(ControllerRemapViewController(initialSystem: selectedSystem ?? .n64), animated: true)
    }

    private func launchGame(_ game: TVGame) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        
        guard rootVC.presentedViewController == nil else { return }
        let presentGame: (URL?) -> Void = { resumeURL in
            let emuVC = GameEmulatorViewController(game: game, resumeStateURL: resumeURL)
            emuVC.modalPresentationStyle = .fullScreen
            emuVC.modalTransitionStyle = .crossDissolve
            rootVC.present(emuVC, animated: true)
        }
        if let resumeURL = TVGameStateFiles(romURL: game.fileURL).resumeURL {
            let alert = UIAlertController(title: "Resume Game?",
                                          message: "Continue \(game.name) from your last saved position?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Resume Game", style: .default) { _ in presentGame(resumeURL) })
            alert.addAction(UIAlertAction(title: "Start from Beginning", style: .default) { _ in presentGame(nil) })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            rootVC.present(alert, animated: true)
        } else {
            presentGame(nil)
        }
    }
}

/// Header Remap Button with proper tvOS focus style
struct HeaderRemapButton: View {
    let action: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                Text("Controller Mapping")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(isFocused ? .black : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                isFocused ? Color.white : Color.white.opacity(0.12)
            )
            .clipShape(Capsule())
            .scaleEffect(isFocused ? 1.035 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .focusEffectDisabled()
    }
}

/// System filter button with high-contrast handling for focused and selected states
struct LibrarySystemTabButton: View {
    let title: String
    let iconName: String?
    let isSelected: Bool
    let action: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                }
                Text(title)
            }
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(isFocused ? .black : .white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isFocused {
                        Color.white
                    } else if isSelected {
                        Color(red: 0.55, green: 0.35, blue: 0.95)
                    } else {
                        Color.white.opacity(0.12)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected && !isFocused ? Color.white.opacity(0.6) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isFocused ? 1.035 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .focusEffectDisabled()
    }
}
