import SwiftUI

struct GradientStatusBarAirHumidity: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State var value: Double = 0
    let height: CGFloat = 5
    
    var body: some View {
        HStack() {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)
                    .frame(maxWidth: 60)
                
                Rectangle()
                    .fill(.blue)
                    .frame(width: 60 * CGFloat(value), height: height)
                    .frame(maxWidth: 60)
                    .frame(alignment: .leading)
                    .offset(x: ((value * 60) - 60) / 2)
            }
            .cornerRadius(8)
            .frame(width: 60, height: height)
        }
        .onChange(of: bluetoothManager.humidity) { _ in
            self.value = Double(bluetoothManager.humidity) / 100
        }
    }
}

struct GradientStatusBarSoilHumidity: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State var value: Double = 0
    let height: CGFloat = 5
    
    var body: some View {
        HStack() {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)
                    .frame(maxWidth: 60)
                
                Rectangle()
                    .fill(.blue)
                    .frame(width: 60 * CGFloat(value), height: height)
                    .frame(maxWidth: 60)
                    .frame(alignment: .leading)
                    .offset(x: ((value * 60) - 60) / 2)
            }
            .cornerRadius(8)
            .frame(width: 60, height: height)
        }
        .onChange(of: bluetoothManager.soilMoisture) { _ in
            self.value = Double(bluetoothManager.soilMoisture) / 100
        }
    }
}

struct GradientStatusBarLight: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State var value: Double = 0
    let height: CGFloat = 5
    
    var body: some View {
        HStack() {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)
                    .frame(maxWidth: 60)
                
                Rectangle()
                    .fill(.blue)
                    .frame(width: 60 * CGFloat(value), height: height)
                    .frame(maxWidth: 60)
                    .frame(alignment: .leading)
                    .offset(x: ((value * 60) - 60) / 2)
            }
            .cornerRadius(8)
            .frame(width: 60, height: height)
        }
        .onChange(of: bluetoothManager.lightLevel) { _ in
            self.value = Double(bluetoothManager.lightLevel) / 100
        }
    }
}

