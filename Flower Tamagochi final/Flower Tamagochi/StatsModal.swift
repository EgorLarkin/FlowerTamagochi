import SwiftUI
import Charts

struct StatsModal: View {
    @Environment(\.dismiss) var dismiss
    @State private var data: String = ""
    @State private var dataArray: [String] = []
    @State var temp: [Int] = []
    @State var airHumidity: [Int] = []
    @State var soilHumidity: [Int] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }, label: {
                        Text("Готово")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                    })
                    .padding()
                }
                VStack {
                    Text("Температура")
                        .fontWeight(.bold)
                        .font(.title)
                    ScrollView(.horizontal, showsIndicators: false){
                        Chart {
                            ForEach(Array(temp.enumerated()), id: \.offset) { index, value in
                                LineMark(
                                    x: .value("Измерение", index + 1),
                                    y: .value("Температура", value)
                                )
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(minWidth: 300)
                        .frame(height: 200)
                        .padding(.leading, 40)
                    }
                }

                VStack {
                    Text("Влажность воздуха")
                        .fontWeight(.bold)
                        .font(.title)
                    ScrollView(.horizontal, showsIndicators: false){
                        Chart {
                            ForEach(Array(airHumidity.enumerated()), id: \.offset) { index, value in
                                LineMark(
                                    x: .value("Измерение", index + 1),
                                    y: .value("Влажность", value)
                                )
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(minWidth: 300)
                        .frame(height: 200)
                        .padding(.leading, 40)
                    }
                }

                VStack {
                    Text("Влажность почвы")
                        .fontWeight(.bold)
                        .font(.title)
                    ScrollView(.horizontal, showsIndicators: false){
                        Chart {
                            ForEach(Array(soilHumidity.enumerated()), id: \.offset) { index, value in
                                LineMark(
                                    x: .value("Измерение", index + 1),
                                    y: .value("Влажность", value)
                                )
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(minWidth: 300)
                        .frame(height: 200)
                        .padding(.leading, 40)
                    }
                }
            }
            .padding()
            .onAppear {
                let data = readFromFile()
                print(data)
                dataArray = data.split(separator: "\n").map(String.init)
                temp.append(contentsOf: dataArray.compactMap { line in
                    let itemArray = line.split(separator: ", ").map(String.init)
                    return Int(itemArray[0])
                })
                airHumidity.append(contentsOf: dataArray.compactMap { line in
                    let itemArray = line.split(separator: ", ").map(String.init)
                    return Int(itemArray[1])
                })
                soilHumidity.append(contentsOf: dataArray.compactMap { line in
                    let itemArray = line.split(separator: ", ").map(String.init)
                    return Int(itemArray[2])
                })
            }
        }
    }
    func readFromFile() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("FlowerData.txt")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist")
            return "File does not exist"
        }

        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            print(fileContent + "data")
            return fileContent
        } catch {
            print("Error reading file: \(error.localizedDescription)")
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}

#Preview {
    StatsModal()
}
