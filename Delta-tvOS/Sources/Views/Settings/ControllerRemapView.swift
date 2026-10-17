import SwiftUI
import GameController

/// Present this controller directly, so no SwiftUI sheet sits outside the
/// GameController event boundary and interprets a gamepad B press as Back.
final class ControllerRemapViewController: GCEventViewController {
    private let initialSystem: TVSystem
    private var onClose: (() -> Void)?
    private var isClosing = false

    init(initialSystem: TVSystem, onClose: (() -> Void)? = nil) {
        self.initialSystem = initialSystem
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        controllerUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let host = UIHostingController(rootView: ControllerRemapContentView(initialSystem: initialSystem) { [weak self] in
            self?.close()
        })
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDisconnected), name: .GCControllerDidDisconnect, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        controllerUserInteractionEnabled = false
        becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }) {
            if TVControllerMappingManager.shared.listeningAction != nil {
                TVControllerMappingManager.shared.stopListening()
            } else {
                close()
            }
            return
        }
        super.pressesBegan(presses, with: event)
    }

    @objc private func controllerDisconnected() {
        if !GCController.controllers().contains(where: { $0.extendedGamepad != nil }) {
            close()
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func close() {
        guard !isClosing else { return }
        isClosing = true
        TVControllerMappingManager.shared.stopListening()
        dismiss(animated: true) { [self] in
            onClose?()
            onClose = nil
        }
    }
}

private struct ControllerRemapContentView: View {
    @ObservedObject var mappingManager = TVControllerMappingManager.shared
    @State private var selectedSystem: TVSystem
    
    var onDismiss: (() -> Void)? = nil
    
    private var listeningAction: TVConsoleAction? { mappingManager.listeningAction }
    @State private var feedback: String?
    @State private var pulseAnimation = false
    
    init(initialSystem: TVSystem = .n64, onDismiss: (() -> Void)? = nil) {
        _selectedSystem = State(initialValue: initialSystem)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Keep every system reachable as more cores are added.
                ScrollView(.horizontal, showsIndicators: false) {
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
                    .padding(.horizontal, 60)
                    .padding(.vertical, 10)
                }
                .focusSection()
                .padding(.top, 16)
                
                // Instructions / Listening Banner
                if let action = listeningAction {
                    VStack(spacing: 8) {
                        Text(mappingManager.capturedButton.map { "Detected \($0.displayName). Release to save." }
                             ?? "Press a button on your game controller…")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(.yellow)
                            .scaleEffect(pulseAnimation ? 1.05 : 0.98)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
                        
                        Text("Mapping: \(action.displayName)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Button("Cancel") {
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
                        Text("Select an action with the remote, then press a gamepad button")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(feedback ?? "Mappings are saved automatically for: \(selectedSystem.fullName)")
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
                        Text("Restore Defaults")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()

                    Toggle("Haptic Feedback", isOn: $mappingManager.hapticFeedbackEnabled)
                        .toggleStyle(.automatic)
                        .frame(width: 280)
                        .accessibilityHint("A short vibration confirms saved mappings on supported controllers.")

                    RemapDoneButton {
                        self.stopListening()
                        self.onDismiss?()
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 24)
            }
            .navigationTitle("Controller Mapping: \(selectedSystem.shortName)")
            .background(Color.black.ignoresSafeArea())
        }
        .onDisappear {
            self.stopListening()
        }
    }
    
    private func startListening(for action: TVConsoleAction) {
        self.feedback = nil
        mappingManager.startListening(for: action) { button in
            self.feedback = "Saved: \(action.displayName) → \(button.displayName)"
        }
    }

    private func stopListening() {
        mappingManager.stopListening()
    }
}

/// System tab button with contrast handling for focused vs selected states
struct RemapSystemTabButton: View {
    let system: TVSystem
    let isSelected: Bool
    let action: () -> Void
    
    @FocusState private var isFocused: Bool
    
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
        .focused($isFocused)
        .focusEffectDisabled()
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
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(isFocused ? .black : .white)
                
                Spacer()
                
                if isListening {
                    Text("Press a button…")
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
        .focused($isFocused)
        .focusEffectDisabled()
    }
}

/// Done button with focus scaling
struct RemapDoneButton: View {
    let action: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            Text("Done")
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
        .focused($isFocused)
        .focusEffectDisabled()
    }
}
