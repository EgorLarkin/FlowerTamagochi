import SwiftUI

struct HorizontalThermometer: View {
    // MARK: - Properties

    @ObservedObject private var bluetoothManager: BluetoothManager

    private var temperature: Float

    private let width: CGFloat = 60
    private let height: CGFloat = 5

    private var normalizedValue: CGFloat {
        let clamped = bluetoothManager.isConnected ? max(0, min(50, temperature)) : 0
        return CGFloat(clamped / 50.0)
    }

    // MARK: - Init

    init(bluetoothManager: BluetoothManager) {
        self._bluetoothManager = ObservedObject(initialValue: bluetoothManager)
        self.temperature = bluetoothManager.temperature
    }

    // MARK: - Body

    var body: some View {
        let backgroundCorner = height / 2
        let fillWidth: CGFloat = width * normalizedValue
        let offsetX: CGFloat = ((CGFloat(temperature) - 50.0) / 50.0) * (width / 2)

        return VStack(spacing: 5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: backgroundCorner)
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: width, height: height)
                    .frame(maxWidth: width)

                RoundedRectangle(cornerRadius: backgroundCorner)
                    .fill(Color.red)
                    .frame(width: fillWidth, height: height)
                    .frame(maxWidth: width)
                    .offset(x: offsetX)
                    .frame(maxWidth: width)
            }
            .frame(width: width, height: height)
            .frame(maxWidth: width)
        }
    }
}
