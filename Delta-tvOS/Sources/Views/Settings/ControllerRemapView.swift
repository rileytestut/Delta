import SwiftUI
import GameController

struct ControllerRemapView: View {
    @ObservedObject var mappingManager = TVControllerMappingManager.shared
    @State private var selectedSystem: TVSystem
    @Environment(\.presentationMode) var presentationMode
    
    var onDismiss: (() -> Void)? = nil
    
    @State private var listeningAction: TVConsoleAction? = nil
    @State private var pulseAnimation = false
    
    init(initialSystem: TVSystem = .n64, onDismiss: (() -> Void)? = nil) {
        _selectedSystem = State(initialValue: initialSystem)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // System Switcher (NES / SNES / N64)
                HStack(spacing: 20) {
                    ForEach(TVSystem.allCases) { system in
                        RemapSystemTabButton(
                            system: system,
                            isSelected: selectedSystem == system,
                            action: {
                                self.selectedSystem = system
                                self.stopListening()
                            }
                        )
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
                
                // Button Actions ScrollView with High-Contrast Focus Styling
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let actions = mappingManager.supportedActions(for: selectedSystem)
                        let categories = Array(Set(actions.map { $0.category })).sorted()
                        
                        ForEach(categories, id: \.self) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 12)
                                    .padding(.leading, 8)
                                
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
                    .padding(.horizontal, 60)
                    .padding(.bottom, 20)
                }
                
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
                    
                    RemapDoneButton {
                        self.stopListening()
                        self.presentationMode.wrappedValue.dismiss()
                        self.onDismiss?()
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 24)
            }
            .navigationTitle("Ohjaimen Mäppäys: \(selectedSystem.shortName)")
            .background(Color.black.ignoresSafeArea())
        }
        .onDisappear {
            self.stopListening()
            self.onDismiss?()
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

/// System tab button with contrast handling for focused vs selected states
struct RemapSystemTabButton: View {
    let system: TVSystem
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.isFocused) private var isFocused
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: system.systemIconName)
                Text(system.shortName)
            }
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(isFocused ? .black : .white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
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

/// A high-contrast action row item for tvOS focus state
struct ActionRowView: View {
    let action: TVConsoleAction
    let isListening: Bool
    let mappedButton: TVGamepadButton?
    let onSelect: () -> Void
    
    @Environment(\.isFocused) private var isFocused
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(action.displayName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(isFocused ? .black : .white)
                
                Spacer()
                
                if isListening {
                    Text("Paina nappia nyt...")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundColor(isFocused ? Color(red: 0.85, green: 0.25, blue: 0.0) : .yellow)
                } else if let mapped = mappedButton {
                    Text(mapped.displayName)
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundColor(isFocused ? .white : .cyan)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            isFocused ? Color(red: 0.45, green: 0.2, blue: 0.85) : Color.white.opacity(0.15)
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                isFocused ? Color.white : Color.white.opacity(0.08)
            )
            .cornerRadius(14)
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

/// Done button with focus scaling
struct RemapDoneButton: View {
    let action: () -> Void
    @Environment(\.isFocused) private var isFocused
    
    var body: some View {
        Button(action: action) {
            Text("Valmis")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isFocused ? .black : .white)
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(isFocused ? Color.white : Color(red: 0.55, green: 0.35, blue: 0.95))
                .cornerRadius(12)
                .scaleEffect(isFocused ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}
