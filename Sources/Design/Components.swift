import SwiftUI
import UIKit

struct BrandMark: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 9 : 12, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: compact ? 17 : 22, weight: .semibold))
            }
            .frame(width: compact ? 34 : 44, height: compact ? 34 : 44)

            VStack(alignment: .leading, spacing: 0) {
                Text("AddiGuard")
                    .font(compact ? .headline : .title3.bold())
                if !compact {
                    Text("添加剂卫士")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AddiGuard 添加剂卫士")
    }
}

struct SectionTitle: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(_ title: String, eyebrow: String? = nil, subtitle: String? = nil) {
        self.title = title
        self.eyebrow = eyebrow
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.accentColor)
            }
            Text(title)
                .font(.title2.weight(.bold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RiskBadge: View {
    let risk: RiskLevel
    var showsLabel = true

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(risk.color)
                .frame(width: 9, height: 9)
            if showsLabel {
                Text(risk.title)
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, showsLabel ? 10 : 0)
        .padding(.vertical, showsLabel ? 6 : 0)
        .background(risk.color.opacity(showsLabel ? 0.11 : 0), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("资料核对优先级：\(risk.title)")
    }
}

struct SourcePill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(18)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}
