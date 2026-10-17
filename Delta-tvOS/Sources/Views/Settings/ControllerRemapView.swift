import SwiftUI
import GameController

struct ControllerRemapView: View {
    @ObservedObject var mappingManager = TVControllerMappingManager.shared
    @State private var selectedSystem: TVSystem
    @Environment(\.presentationMode) var presentationMode
    
    @State private var listeningAction: TVConsoleAction? = nil
    @State private var pulseAnimation = false
    
    init(initialSystem: TVSystem = .n64) {
        _selectedSystem = State(initialValue: initialSystem)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // System Switcher (NES / SNES / N64)
                HStack(spacing: 16) {
                    ForEach(TVSystem.allCases) { system in
                        Button(action: {
                            self.selectedSystem = system
                            self.stopListening()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: system.systemIconName)
                                Text(system.shortName)
                            }
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(selectedSystem == system ? Color(red: 0.55, green: 0.35, blue: 0.95) : Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 16)
                
                // Instructions / Listening Banner
                if let action = listeningAction {
                    VStack(spacing: 8) {
                        Text("Paina haluamaasi nappia peliohjaimessa...")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(.yellow)
                            .scaleEffect(pulseAnimation ? 1.05 : 0.98)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
                        
                        Text("Määritetään toimintoa: \(action.displayName)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Button("Peruuta") {
                            self.stopListening()
                        }
                        .font(.system(size: 16, weight: .bold))
                        .padding(.top, 4)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(16)
                    .padding(.horizontal, 60)
                    .onAppear {
                        pulseAnimation = true
                    }
                } else {
                    VStack(spacing: 4) {
                        Text("Valitse toiminto kaukosäätimellä ja paina ohjaimen nappia")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Asetukset tallentuvat automaattisesti profiiliin: \(selectedSystem.fullName)")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Button Actions List with High-Contrast Focus Styling
                List {
                    let actions = mappingManager.supportedActions(for: selectedSystem)
                    let categories = Array(Set(actions.map { $0.category })).sorted()
                    
                    ForEach(categories, id: \.self) { category in
                        Section(header: Text(category).font(.system(size: 18, weight: .bold)).foregroundColor(.secondary)) {
                            ForEach(actions.filter { $0.category == category }) { action in
                                ActionRowView(
                                    action: action,
                                    isListening: listeningAction?.id == action.id,
                                    mappedButton: mappingManager.mappedButton(for: action),
                                    onSelect: {
                                        self.startListening(for: action)
                                    }
                                )
                            }
                        }
                    }
                }
                .listStyle(.grouped)
                
                // Bottom Toolbar (Reset / Done)
                HStack(spacing: 32) {
                    Button(action: {
                        mappingManager.resetToDefaults(for: selectedSystem)
                    }) {
                        Text("Palauta oletukset")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: {
                        self.stopListening()
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Valmis")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 36)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.55, green: 0.35, blue: 0.95))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 24)
            }
            .navigationTitle("Ohjaimen Mäppäys: \(selectedSystem.shortName)")
            .background(Color.black.ignoresSafeArea())
        }
        .onDisappear {
            self.stopListening()
        }
    }
    
    private func startListening(for action: TVConsoleAction) {
        self.listeningAction = action
        mappingManager.startListening(for: action) { _ in
            DispatchQueue.main.async {
                self.listeningAction = nil
            }
        }
    }
    
    private func stopListening() {
        self.listeningAction = nil
        mappingManager.stopListening()
    }
}

/// A high-contrast action row item for tvOS focus state
struct ActionRowView: View {
    let action: TVConsoleAction
    let isListening: Bool
    let mappedButton: TVGamepadButton?
    let onSelect: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(action.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isFocused ? .black : .white)
                
                Spacer()
                
                if isListening {
                    Text("Paina nappia nyt...")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(isFocused ? Color(red: 0.8, green: 0.35, blue: 0.0) : .yellow)
                } else if let mapped = mappedButton {
                    Text(mapped.displayName)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(isFocused ? .white : .cyan)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isFocused ? Color.black : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .focused($isFocused)
    }
}
