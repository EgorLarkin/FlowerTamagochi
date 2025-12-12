import SwiftUI
import Charts

// MARK: - Reusable Chart View
struct ChartView: View {
    let title: String
    let data: [Int]
    let yAxisLabel: String

    private var chartWidth: CGFloat {
        let base: CGFloat = 500
        let perItem: CGFloat = 60
        let computed = CGFloat(data.count) * perItem
        return max(base, computed)
    }

    var body: some View {
        VStack {
            Text(title)
                .fontWeight(.bold)
                .font(.title)

            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        LineMark(
                            x: .value("Измерение", index + 1),
                            y: .value(yAxisLabel, value)
                        )
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(width: chartWidth)
                .frame(height: 200)
                .padding(.leading, 40)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollTargetLayout()
        }
    }
}

// MARK: - StatsModal
struct StatsModal: View {
    // MARK: Environment
    @Environment(\.dismiss) var dismiss

    // MARK: Dependencies
    @ObservedObject var bluetoothManager: BluetoothManager

    // MARK: Local State
    @State private var temp: [Int] = []
    @State private var airHumidity: [Int] = []
    @State private var soilHumidity: [Int] = []
    @State private var lightLevel: [Int] = []

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 30) {
                    header
                        .padding(.horizontal)
                        .padding(.top)

                    Group {
                        ChartView(
                            title: "Температура",
                            data: temp,
                            yAxisLabel: "Температура"
                        )

                        ChartView(
                            title: "Влажность воздуха",
                            data: airHumidity,
                            yAxisLabel: "Влажность"
                        )

                        ChartView(
                            title: "Влажность почвы",
                            data: soilHumidity,
                            yAxisLabel: "Влажность"
                        )

                        ChartView(
                            title: "Освещенность",
                            data: lightLevel,
                            yAxisLabel: "Освещенность"
                        )
                    }
                    .padding(.horizontal)

                    clearButton
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                }
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .onAppear { loadData() }
        .onChange(of: bluetoothManager.humidity) { _ in loadData() }
        .onChange(of: bluetoothManager.temperature) { _ in loadData() }
        .onChange(of: bluetoothManager.soilMoisture) { _ in loadData() }
        .onChange(of: bluetoothManager.lightLevel) { _ in loadData() }
    }

    // MARK: - Subviews
    private var header: some View {
        HStack {
            Text("Статистика")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            Button("Готово") {
                dismiss()
            }
            .foregroundColor(.blue)
            .fontWeight(.bold)
        }
    }

    private var clearButton: some View {
        Button(action: {
            clearFile()
            dismiss()
        }) {
            Text("Очистить статистику")
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }

    // MARK: - Data Loading
    private func loadData() {
        let data = readFromFile()
        let dataArray = data.split(separator: "\n").map(String.init)

        temp.removeAll()
        airHumidity.removeAll()
        soilHumidity.removeAll()
        lightLevel.removeAll()

        for line in dataArray {
            let itemArray = line.split(separator: ", ").map(String.init)

            if itemArray.count >= 4 {
                if let tempValue = Int(itemArray[0]) { temp.append(tempValue) }
                if let airHumValue = Int(itemArray[1]) { airHumidity.append(airHumValue) }
                if let soilHumValue = Int(itemArray[2]) { soilHumidity.append(soilHumValue) }
                if let lightValue = Int(itemArray[3]) { lightLevel.append(lightValue) }
            }
        }
    }

    // MARK: - File I/O
    private func readFromFile() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(
            bluetoothManager.deviceName + "FlowerData.txt"
        )

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ""
        }

        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("Ошибка чтения файла: \(error.localizedDescription)")
            return ""
        }
    }

    private func clearFile() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(
            bluetoothManager.deviceName + "FlowerData.txt"
        )

        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            temp.removeAll()
            airHumidity.removeAll()
            soilHumidity.removeAll()
            lightLevel.removeAll()
        } catch {
            print("Ошибка очистки файла: \(error)")
        }
    }
}
