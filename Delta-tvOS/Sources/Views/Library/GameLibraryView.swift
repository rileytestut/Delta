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
    @State private var showControllerRemapper = false
    
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
                        Text(selectedSystem?.fullName ?? "Kaikki järjestelmät (\(gameManager.allGames.count) peliä)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Controller Remapping Tool Button in Header
                    HeaderRemapButton {
                        self.showControllerRemapper = true
                    }
                    
                    // Controller Status Indicator with Flash Transition
                    HStack(spacing: 10) {
                        Image(systemName: hasConnectedController ? "gamecontroller.fill" : "gamecontroller")
                            .foregroundColor(controllerBadgeFlash ? .black : (hasConnectedController ? .green : .yellow))
                        Text(hasConnectedController ? "Ohjain yhdistetty" : "Liitä ohjain")
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
                            title: "Kaikki pelit",
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
                        
                        // Also provide direct button to Remap in the tabs row for effortless remote navigation
                        Button(action: { showControllerRemapper = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "slider.horizontal.3")
                                Text("Aseta napit...")
                            }
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
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
                        
                        Text("Kirjasto on tyhjä")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Siirrä ROM-pelejä tietokoneelta tai puhelimelta:\nAvaa selaimessa osoite \(webServer.serverAddress)")
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
        .sheet(isPresented: $showControllerRemapper) {
            ControllerRemapView(initialSystem: selectedSystem ?? .n64)
        }
        .onAppear {
            self.checkControllers()
            NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { _ in
                self.checkControllers()
            }
            NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { _ in
                self.checkControllers()
            }
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
    
    private func launchGame(_ game: TVGame) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        
        let emuVC = GameEmulatorViewController(game: game)
        emuVC.modalPresentationStyle = .fullScreen
        emuVC.modalTransitionStyle = .crossDissolve
        rootVC.present(emuVC, animated: true)
    }
}

/// Header Remap Button with proper tvOS focus style
struct HeaderRemapButton: View {
    let action: () -> Void
    @Environment(\.isFocused) private var isFocused
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                Text("Määritä ohjain")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(isFocused ? .black : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                isFocused ? Color.white : Color.white.opacity(0.12)
            )
            .clipShape(Capsule())
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

/// System filter button with high-contrast handling for focused and selected states
struct LibrarySystemTabButton: View {
    let title: String
    let iconName: String?
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.isFocused) private var isFocused
    
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
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}
