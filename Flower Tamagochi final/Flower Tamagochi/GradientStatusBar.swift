import SwiftUI

// Reusable status bar that renders the same visual algorithm as before
private struct GradientStatusBar: View {
    @Binding var value: Double
    let height: CGFloat
    let color: Color

    var body: some View {
        HStack() {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.7))
                    .frame(height: height)
                    .frame(maxWidth: 60)

                Rectangle()
                    .fill(color)
                    .frame(width: 60 * CGFloat(value), height: height)
                    .frame(maxWidth: 60)
                    .frame(alignment: .leading)
                    .offset(x: ((value * 60) - 60) / 2)
            }
            .cornerRadius(8)
            .frame(width: 60, height: height)
        }
    }
}

struct GradientStatusBarAirHumidity: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var value: Double = 0
    private let height: CGFloat = 5

    var body: some View {
        GradientStatusBar(value: $value, height: height, color: .white)
            .onChange(of: bluetoothManager.humidity) { _, _ in
                self.value = Double(bluetoothManager.humidity) / 100
            }
            .onChange(of: bluetoothManager.isConnected){ _, newValue in
                if !newValue {
                    self.value = 0
            }
        }
    }
}

struct GradientStatusBarSoilHumidity: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var value: Double = 0
    private let height: CGFloat = 5

    var body: some View {
        GradientStatusBar(value: $value, height: height, color: Color("HumidityBarColor"))
            .onChange(of: bluetoothManager.soilMoisture) { _, _ in
                self.value = Double(bluetoothManager.soilMoisture) / 100
            }
            .onChange(of: bluetoothManager.isConnected){ _, newValue in
                if !newValue {
                    self.value = 0
            }
        }
    }
}

struct GradientStatusBarLight: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var value: Double = 0
    private let height: CGFloat = 5

    var body: some View {
        GradientStatusBar(value: $value, height: height, color: .yellow)
            .onChange(of: bluetoothManager.lightLevel) { _, _ in
                self.value = Double(bluetoothManager.lightLevel) / 100
            }
            .onChange(of: bluetoothManager.isConnected){ _, newValue in
                if !newValue {
                    self.value = 0
            }
        }
    }
}
