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
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                        Text(selectedSystem?.fullName ?? "All Systems (\(gameManager.allGames.count) games)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Controller Status Indicator with Flash Transition
                    HStack(spacing: 10) {
                        Image(systemName: hasConnectedController ? "gamecontroller.fill" : "gamecontroller")
                            .foregroundColor(controllerBadgeFlash ? .black : (hasConnectedController ? .green : .yellow))
                        Text(hasConnectedController ? "Controller Connected" : "Connect Gamepad")
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
                
                // System Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        Button(action: { selectedSystem = nil }) {
                            Text("All Games")
                                .font(.system(size: 18, weight: .semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(selectedSystem == nil ? .orange : .gray.opacity(0.3))
                        
                        ForEach(TVSystem.allCases) { system in
                            Button(action: { selectedSystem = system }) {
                                HStack(spacing: 8) {
                                    Image(systemName: system.systemIconName)
                                    Text(system.shortName)
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(selectedSystem == system ? .orange : .gray.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 10)
                }
                
                // Main Games Grid
                if filteredGames.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No Games in Library")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Upload ROM files from your phone or computer:\nOpen \(webServer.serverAddress) in any browser.")
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
                                    self.selectedGame = game
                                }
                            }
                        }
                        .padding(.horizontal, 48)
                        .padding(.vertical, 24)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedGame) { game in
            GameEmulatorView(game: game)
                .ignoresSafeArea()
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
}
