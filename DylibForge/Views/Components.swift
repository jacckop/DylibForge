import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
    }
}

struct PrimaryGradientButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [.cyan.opacity(0.9), .blue.opacity(0.85), .purple.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct FilterChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(isSelected ? .white.opacity(0.22) : .white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(isSelected ? .white.opacity(0.34) : .white.opacity(0.12), lineWidth: 1))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.cyan)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct EmptyStateView: View {
    let importAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.16))
                        .frame(width: 90, height: 90)
                    Image(systemName: "hammer.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.cyan)
                }

                VStack(spacing: 8) {
                    Text("استورد ملف dylib وابدأ الفحص")
                        .font(.title3.bold())
                    Text("راح يستخرج الروابط، النصوص العربية، الـ endpoints، والكلمات المهمة، وبعد التعديل يطلع لك dylib جديد.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                PrimaryGradientButton(title: "اختيار ملف dylib", icon: "folder.badge.plus", action: importAction)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
