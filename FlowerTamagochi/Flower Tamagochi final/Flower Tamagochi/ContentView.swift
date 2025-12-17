import SwiftUI

// MARK: - Models
struct ChatCompletionResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message

        struct Message: Codable {
            let content: String
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    // MARK: UI State
    @State private var flowerName: String = ""
    @State private var isLoading: Bool = false
    @State private var chatRecommendation: String = ""
    @State private var chatResponse: String = ""

    // MARK: Sensor Values (UI)
    @State private var temp: Int = 0
    @State private var airHumidity: Int = 0
    @State private var soilHumidity: Int = 0
    @State private var lightLevel: Int = 0

    // MARK: Flags
    @State private var showStats: Bool = false
    @State private var showDeviceList: Bool = false
    @State private var showsData: Bool = true
    @State private var isCrying: Bool = false
    @State private var isChatting: Bool = false

    // MARK: Persistence / Counters
    @State private var countEdits: Int = 0

    // MARK: Device
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var deviceName: String = ""

    var body: some View {
        VStack {
            header
                .padding(.horizontal)

            if bluetoothManager.isConnected {
                FlowMessage(message: chatRecommendation)
                    .padding()
                    .offset(x: 70, y: -20)
            } else {
                Spacer()
            }

            flowerArea
        }

        nameField

        actionButtons
            .padding()
            .edgesIgnoringSafeArea(.all)

            .onChange(of: flowerName) { _, _ in
                writeNewName()
            }

            .sheet(isPresented: $showStats) {
                StatsModal(
                    bluetoothManager: self.bluetoothManager
                )
            }

            .sheet(isPresented: $showDeviceList) {
                DeviceListView(bluetoothManager: bluetoothManager)
            }

            .sheet(isPresented: $isChatting) {
                ChatView(
                    viewModel: ChatViewModel(
                        bluetoothManager: self.bluetoothManager
                    ),
                    bluetoothManager: self.bluetoothManager
                )
            }

            // Sensor-driven updates
            .onChange(of: bluetoothManager.temperature) { _, newValue in
                if newValue > 0 && newValue < 50 {
                    sensorDrivenUpdate()
                }
            }
            .onChange(of: bluetoothManager.humidity) { _, newValue in
                if newValue > 0 && newValue <= 100 {
                    sensorDrivenUpdate()
                }
            }
            .onChange(of: bluetoothManager.lightLevel) { _, newValue in
                if newValue > 0 && newValue <= 100 {
                    sensorDrivenUpdate()
                }
            }
            .onChange(of: bluetoothManager.soilMoisture) { _, newValue in
                if newValue > 0 && newValue <= 100 {
                    sensorDrivenUpdate()
                }
            }

            // Count edits persistence
            .onChange(of: countEdits) { _, _ in
                writeNewCount()
                if countEdits >= 10000 {
                    shrinkFile()
                    countEdits = 0
                }
            }

            .onChange(of: self.bluetoothManager.isConnected) { _, newValue in
                if newValue {
                    self.countEdits = readEdits()
                }
            }
        
            .onAppear {
                startDataUpdate()
                writeNewData(
                    temp: temp,
                    airHumidity: airHumidity,
                    soilHumidity: soilHumidity,
                    lightLevel: lightLevel
                )
            }
    }

    // MARK: - Subviews
    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(bluetoothManager.statusMessage)
                    .font(.system(size: 14))
                    .foregroundColor(bluetoothManager.isConnected ? .green : .red)

                Button(action: { showDeviceList = true }) {
                    Text("Показать устройства")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
            }

            Spacer()
                .offset(x: 40)

            Button(action: { self.isChatting = true }) {
                Image(systemName: "plus.message.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            .disabled(!bluetoothManager.isConnected)
        }
    }

    private var flowerArea: some View {
        ZStack {
            Image("Flower")
                .resizable()
                .scaledToFit()
                .frame(width: 400, height: 350)
                .offset(x: -20, y: -75)
                .padding()
                .zIndex(2)

            if isCrying && bluetoothManager.isConnected {
                Image("CryingFace")
                    .offset(x: -31.5, y: -149)
                    .zIndex(3)
            }

            ZStack {
                Image("Pot")
                    .offset(y: 143)
                    .zIndex(0)

                Image("Board")
                    .offset(y: 173)
                    .zIndex(1)

                if showsData && bluetoothManager.isConnected {
                    sensorBoard
                        .zIndex(3)
                        .offset(y: 170)
                } else {
                    chatScroll
                        .zIndex(3)
                        .frame(maxWidth: 120, maxHeight: 63)
                        .offset(x: 5, y: 175)
                }
            }
        }
    }

    private var sensorBoard: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("🌡️: \(temp)°C")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.black))

                HorizontalThermometer(bluetoothManager: self.bluetoothManager)
            }
            .offset(y: 10)

            HStack {
                Text("💧: \(airHumidity)% ")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.black))

                GradientStatusBarAirHumidity(bluetoothManager: bluetoothManager)
            }
            .offset(y: 5)

            HStack {
                Text("🪴: \(soilHumidity)% ")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.black))

                GradientStatusBarSoilHumidity(bluetoothManager: bluetoothManager)
            }
            .offset(y: 0)

            HStack {
                Text("☀️: \(lightLevel)% ")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.black))

                GradientStatusBarLight(bluetoothManager: bluetoothManager)
            }
            .offset(y: -5)
        }
    }

    private var chatScroll: some View {
        ScrollView {
            if isLoading {
                Text("Цветочек думает...")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 15))
                    .offset(y: 5)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.yellow)
                    .zIndex(1)
            } else {
                Text(chatResponse)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 15))
                    .offset(y: 0)
                    .frame(maxWidth: 270)
                    .foregroundColor(.yellow)
            }
        }
    }

    private var nameField: some View {
        TextField("Имя цветка", text: $flowerName)
            .multilineTextAlignment(.center)
            .font(.title)
            .fontWeight(.bold)
            .padding()
            .foregroundColor(.purple)
            .offset(y: 60)
            .disabled(!bluetoothManager.isConnected)
    }

    private var actionButtons: some View {
        HStack {
            Button(
                action: {
                    if showsData {
                        showsData = false
                        fetchChatCompletion()
                    } else {
                        showsData = true
                    }
                },
                label: {
                    Text(!showsData ? " Скрыть \n ответ " : " Спросить \n цветочек ")
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .font(.system(size: 30))
                }
            )
            .cornerRadius(20)
            .frame(width: 500, height: 100)
            .offset(x: 160, y: 20)
            .disabled(!bluetoothManager.isConnected)

            Button(
                action: { showStats = true },
                label: {
                    Text(" Статистика \n цветочка ")
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .font(.system(size: 30))
                }
            )
            .cornerRadius(20)
            .frame(width: 500, height: 100)
            .offset(x: -170, y: 20)
            .disabled(!bluetoothManager.isConnected)
        }
    }

    // MARK: - Logic helpers
    private func sensorDrivenUpdate() {
        updateSensorValues()

        if updateDevName() {
            self.flowerName = readFromFile()
        }

        if !bluetoothManager.isConnected {
            deviceName = ""
        }
    }

    private func updateSensorValues() {
        self.temp = Int(bluetoothManager.temperature)
        self.airHumidity = Int(bluetoothManager.humidity)
        self.soilHumidity = Int(bluetoothManager.soilMoisture)
        self.lightLevel = Int(bluetoothManager.lightLevel)

        if temp >= 15 && temp <= 30 && airHumidity >= 20 && airHumidity <= 50 && soilHumidity >= 20 && soilHumidity <= 80 && lightLevel >= 20 && lightLevel <= 80 {
            chatRecommendation = "Все хорошо!"
            self.isCrying = false
        } else {
            chatRecommendation = "Спаси меня!"
            self.isCrying = true
        }

        writeNewData(
            temp: temp,
            airHumidity: airHumidity,
            soilHumidity: soilHumidity,
            lightLevel: lightLevel
        )
    }

    private func updateDevName() -> Bool {
        let oldName = self.deviceName
        self.deviceName = bluetoothManager.deviceName
        return oldName != self.deviceName
    }

    @MainActor
    func startDataUpdate() {}

    // MARK: - File name helpers
    private func flowerNameFileName() -> String { self.deviceName + "FlowerName.txt" }
    private func dataCountFileName() -> String { self.deviceName + "DataCount.txt" }
    private func flowerDataFileName() -> String { self.deviceName + "FlowerData.txt" }

    // MARK: - Networking
    private func makeChatRequest(url: URL, body: [String: Any]) -> URLRequest? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer TOKEN", forHTTPHeaderField: "Authorization")
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            return nil
        }
        request.httpBody = jsonData
        return request
    }

    func fetchChatCompletion() {
        self.isLoading = true
        guard let url = URL(string: "https://router.huggingface.co/v1/chat/completions") else {
            self.chatResponse = "Неверный URL"
            self.isLoading = false
            return
        }

        let body: [String: Any] = [
            "stream": false,
            "model": "deepseek-ai/DeepSeek-V3.2-Exp:novita",
            "messages": [
                [
                    "role": "user",
                    "content": "Ответь, как можно короче, пожалуйста(не более 15 слов). Если цветку все хорошо, обратившись к пользователю от имени цветка \(flowerName) без обращения к нему, от имени цветка, не предлагай варианты с изменением местоположения цветка, а только к его состоянию: Что нужно цветку \"\(flowerName)\", который стоит в комнате при температуре \(temp)°C, влажности воздуха \(airHumidity)%, освещенности \(self.lightLevel)% и влажности почвы \(soilHumidity)%?; ответь непринужденно и шуточно."
                ]
            ]
        ]

        guard let request = makeChatRequest(url: url, body: body) else {
            self.chatResponse = "Ошибка преобразования в JSON"
            self.isLoading = false
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { DispatchQueue.main.async { self.isLoading = false } }

            if let error = error {
                DispatchQueue.main.async {
                    self.chatResponse = "Ошибка: \(error.localizedDescription)"
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.chatResponse = "Не удалось получить HTTP ответ"
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.chatResponse = "Ошибка HTTP: \(httpResponse.statusCode)"
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.chatResponse = "Нет данных получено"
                }
                return
            }

            do {
                let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                DispatchQueue.main.async {
                    if let messageContent = chatResponse.choices.first?.message.content {
                        self.chatResponse = "\(messageContent)"
                    } else {
                        self.chatResponse = "Нет сообщений в ответе."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.chatResponse = "Ошибка декодирования: \(error.localizedDescription)"
                }
            }
        }
        task.resume()
    }

    // MARK: - Persistence
    func writeNewName() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(
            flowerNameFileName()
        )
        do {
            try self.flowerName.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error write")
        }
    }

    func writeNewCount() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(dataCountFileName())
        do {
            try String(self.countEdits).write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error write")
        }
    }

    func readFromFile() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(flowerNameFileName())

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return "File does not exist"
        }

        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            return fileContent
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }

    func readEdits() -> Int {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(dataCountFileName())

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return 0
        }

        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            return Int(fileContent) ?? 0
        } catch {
            return 0
        }
    }

    func writeNewData(temp: Int, airHumidity: Int, soilHumidity: Int, lightLevel: Int) {
        if !bluetoothManager.isConnected && !(temp > 0 && temp < 50 && airHumidity > 0 && airHumidity < 100 && soilHumidity > 0 && soilHumidity < 100 && lightLevel > 0 && lightLevel < 100) {
            return
        }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let addString = "\(temp), \(airHumidity), \(soilHumidity), \(lightLevel)\n"
        let fileURL = documentsURL.appendingPathComponent(flowerDataFileName())

        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            fileHandle.seekToEndOfFile()
            if let data = addString.data(using: .utf8) {
                fileHandle.write(data)
            }
            try? fileHandle.close()
        } else {
            do {
                try addString.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Error update data")
            }
        }
        countEdits += 1
    }

    func shrinkFile() {
        var sum_temp: Int = 0
        var sum_airHumidity: Int = 0
        var sum_soilHumidity: Int = 0
        var sum_lightLevel: Int = 0
        var dataArray: [String] = []

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(flowerDataFileName())

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist")
            return
        }

        do {
            let data = try String(contentsOf: fileURL, encoding: .utf8)
            dataArray = data.split(separator: "\n").map(String.init)

            if dataArray.count < 10000 {
                print("Not enough data to shrink.")
                return
            }

            for i in dataArray[dataArray.count - 10000..<dataArray.count] {
                let components = i.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if components.count == 4,
                   let tempValue = Int(components[0]),
                   let airHumidityValue = Int(components[1]),
                   let soilHumidityValue = Int(components[2]),
                   let lightLevelValue = Int(components[3])
                {
                    sum_temp += tempValue
                    sum_airHumidity += airHumidityValue
                    sum_soilHumidity += soilHumidityValue
                    sum_lightLevel += lightLevelValue
                }
            }

            let average_temp: Int = sum_temp / 10000
            let average_airHumidity: Int = sum_airHumidity / 10000
            let average_soilHumidity: Int = sum_soilHumidity / 10000
            let average_lightLevel: Int = sum_lightLevel / 10000

            print("Average Temp: \(average_temp), Average Air Humidity: \(average_airHumidity), Average Soil Humidity: \(average_soilHumidity), Average Light Level: \(average_lightLevel)")
            let addString = "\(average_temp), \(average_airHumidity), \(average_soilHumidity), \(average_lightLevel)\n"

            try "".write(to: fileURL, atomically: true, encoding: .utf8)

            if let fileHandle = try? FileHandle(forUpdating: fileURL) {
                fileHandle.seekToEndOfFile()
                if let data = addString.data(using: .utf8) {
                    fileHandle.write(data)
                    print("Data appended: \(addString)")
                }
                try? fileHandle.close()
            }
        } catch {
            print("Error reading/writing file: \(error.localizedDescription)")
        }
    }

    func clearFile() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(flowerDataFileName())
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            countEdits = 0
            writeNewCount()
        } catch {
            print("Error write")
        }
    }
}

// MARK: - DeviceListView
struct DeviceListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String = ""

    var body: some View {
        VStack {
            NavigationView {
                List(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                    Button(action: {
                        bluetoothManager.connectToDevice(device)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        VStack(alignment: .leading) {
                            Text(device.name ?? "Unknown Device")
                                .font(.headline)
                            Text(device.identifier.uuidString)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .navigationTitle("Выберите устройство")
                .navigationBarItems(trailing: Button("Закрыть") {
                    presentationMode.wrappedValue.dismiss()
                })
            }
            if (bluetoothManager.isConnected) {
                Button(
                    action: {
                        self.bluetoothManager.disconnect()
                        dismiss()
                    },
                    label: {
                        Text("Отключиться")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
