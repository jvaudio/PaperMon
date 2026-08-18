import SwiftUI

struct DotGridBackground: View {
    var spacing: CGFloat = 22
    var dotDiameter: CGFloat = 2.2

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.paperMonCanvas)
            )

            var dots = Path()
            var x = spacing / 2
            while x < size.width {
                var y = spacing / 2
                while y < size.height {
                    dots.addEllipse(
                        in: CGRect(
                            x: x - dotDiameter / 2,
                            y: y - dotDiameter / 2,
                            width: dotDiameter,
                            height: dotDiameter
                        )
                    )
                    y += spacing
                }
                x += spacing
            }

            context.fill(dots, with: .color(.paperMonMuted.opacity(0.36)))
        }
        .accessibilityHidden(true)
    }
}

