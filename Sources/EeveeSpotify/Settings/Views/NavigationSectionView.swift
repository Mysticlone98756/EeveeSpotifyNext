import SwiftUI

struct NavigationSectionView: View {
    var color: Color
    var title: String
    var imageSystemName: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: color.opacity(0.28), radius: 2.5, y: 1.5)

                Image(systemName: imageSystemName)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(width: 30, height: 30)

            Text(title)
                .font(.body.weight(.medium))
                .foregroundColor(.white)

            Spacer()

            ChevronRightView()
        }
        .padding(.vertical, 3)
    }
}
