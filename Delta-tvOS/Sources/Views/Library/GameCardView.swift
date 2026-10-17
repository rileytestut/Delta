import SwiftUI

struct GameCardView: View {
    let game: TVGame
    let onSelect: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Cartridge / Box Art representation
                ZStack {
                    LinearGradient(
                        colors: [cardColor.opacity(0.85), cardColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    VStack(spacing: 8) {
                        Image(systemName: game.system.systemIconName)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(game.system.shortName)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Game Title
                Text(game.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(10)
            .background(isFocused ? Color.white.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .frame(width: 260)
    }
    
    private var cardColor: Color {
        switch game.system {
        case .nes: return Color(red: 0.85, green: 0.2, blue: 0.2)
        case .snes: return Color(red: 0.45, green: 0.3, blue: 0.8)
        case .n64: return Color(red: 0.1, green: 0.65, blue: 0.55)
        }
    }
}
