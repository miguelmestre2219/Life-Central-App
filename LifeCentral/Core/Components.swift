import SwiftUI

// Small building blocks shared by every screen.

struct CardModifier: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View { modifier(CardModifier(padding: padding)) }

    /// Standard scrolling screen background.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

struct SectionLabel: View {
    let text: String
    var color: Color = .secondary
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct IconChip: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ProgressBar: View {
    /// 0…1. Values above 1 fill the bar and turn it amber.
    let value: Double
    var color: Color
    var secondValue: Double = 0
    var secondColor: Color = .clear
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let first = min(max(value, 0), 1)
            let second = min(max(secondValue, 0), 1 - first)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                HStack(spacing: 2) {
                    if first > 0 {
                        Capsule().fill(value > 1 ? Color.orange : color).frame(width: w * first)
                    }
                    if second > 0 {
                        Capsule().fill(secondColor).frame(width: max(0, w * second - 2))
                    }
                }
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

/// Pill-shaped choice used for filters and pickers.
struct ChoiceChip: View {
    let title: String
    let isOn: Bool
    var color: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isOn ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isOn ? Color(.systemBackground) : Color.primary)
                .background(isOn ? color : Theme.card, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Flows chips onto as many lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var color: Color = .accentColor
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            IconChip(symbol: symbol, color: color, size: 56)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal)
    }
}

/// The round + / floating "Add" button at the bottom of a screen.
struct FloatingAddButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(.body.weight(.semibold))
                .padding(.horizontal, 20)
                .frame(height: 52)
                .foregroundStyle(.white)
                .background(color, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

/// A text field for money, with the currency symbol in front.
struct AmountField: View {
    @Binding var text: String
    let currencyCode: String
    var font: Font = .display(40)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(CurrencyInfo.symbol(currencyCode))
                .font(font)
                .foregroundStyle(.secondary)
            TextField("0", text: $text)
                .font(font)
                .keyboardType(.decimalPad)
                .minimumScaleFactor(0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Amount in \(CurrencyInfo.name(currencyCode))")
    }
}

/// Row with a label on the left and a value on the right, used in forms and details.
struct ValueRow: View {
    let label: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(valueColor).multilineTextAlignment(.trailing)
        }
    }
}

struct CircleTick: View {
    let isOn: Bool
    var color: Color
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? color : Color.secondary.opacity(0.4), lineWidth: 2)
                .background(Circle().fill(isOn ? color : .clear))
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
