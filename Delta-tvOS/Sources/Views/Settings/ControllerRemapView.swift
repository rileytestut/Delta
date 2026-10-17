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
                            .background(selectedSystem == system ? Color.white.opacity(0.25) : Color.clear)
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
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button("Peruuta") {
                            self.stopListening()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .padding(.top, 4)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.12))
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
                
                // Button Actions List
                List {
                    let actions = mappingManager.supportedActions(for: selectedSystem)
                    let categories = Array(Set(actions.map { $0.category })).sorted()
                    
                    ForEach(categories, id: \.self) { category in
                        Section(header: Text(category).font(.system(size: 18, weight: .bold)).foregroundColor(.secondary)) {
                            ForEach(actions.filter { $0.category == category }) { action in
                                Button(action: {
                                    self.startListening(for: action)
                                }) {
                                    HStack {
                                        Text(action.displayName)
                                            .font(.system(size: 20, weight: .semibold))
                                        
                                        Spacer()
                                        
                                        if listeningAction?.id == action.id {
                                            Text("Odota painallusta...")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.yellow)
                                        } else if let mapped = mappingManager.mappedButton(for: action) {
                                            HStack(spacing: 6) {
                                                Text(mapped.displayName)
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 6)
                                                    .background(Color.white.opacity(0.15))
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
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
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red.opacity(0.85))
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
                            .background(Color.white.opacity(0.2))
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
