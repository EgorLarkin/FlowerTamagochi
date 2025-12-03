import SwiftUI

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

struct ContentView: View {
    @State private var flowerName = ""
    @State private var isLoading: Bool = false
    @State private var chatRecommendation: String = ""
    @State private var chatResponse = ""
    @State private var temp: Int = 0
    @State private var airHumidity: Int = 0
    @State private var soilHumidity: Int = 0
    @State private var lightLevel: Int = 0
    @State private var showStats: Bool = false
    @State private var countEdits: Int = 0
    @State private var showDeviceList: Bool = false
    @StateObject private var bluetoothManager = BluetoothManager()
    
    @State private var deviceName: String = ""
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(bluetoothManager.statusMessage)
                        .font(.system(size: 14))
                        .foregroundColor(bluetoothManager.isConnected ? .green : .red)
                    
                    Button("Показать устройства") {
                        showDeviceList = true
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                }
                Spacer()
                    .offset(x: 40)
            }
            .padding(.horizontal)
            .offset(x: 140)
            HStack {
                VStack(alignment: .leading) {
                    Text("🌡️: \(temp)°C")
                        .font(.system(size: 30))
                    Text("💧: \(airHumidity)%")
                        .font(.system(size: 30))
                    Text("🪴: \(soilHumidity)%")
                        .font(.system(size: 30))
                    Text("☀️: \(lightLevel)%")
                        .font(.system(size: 30))
                }
                .offset(y: -50)
                FlowMessage(message: chatRecommendation)
                    .padding()
                    .offset(x: 20, y: 5)
            }
            ZStack{
                Image("Flower")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 350)
                    .offset(x: -15, y: -80)
                    .padding()
                    .zIndex(1)
                ZStack{
                    Image("Pot")
                        .offset(y: 123)
                    if chatResponse != "" || isLoading {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.text.page")
                                .foregroundColor(.yellow)
                                .font(.system(size: 50))
                                .offset(y: 75)
                            if isLoading {
                                Text("Цветочек думает...")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 25))
                                    .offset(y: 100)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.yellow)
                            } else {
                                Text(chatResponse)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 25))
                                    .offset(y: 100)
                                    .frame(maxWidth: 270)
                                    .foregroundColor(.yellow)
                            }
                        }
                        .frame(maxWidth: 200, maxHeight: 300)
                    }
                }
            }
            TextField("Имя цветка", text: $flowerName)
                .multilineTextAlignment(.center)
                .font(.title)
                .fontWeight(.bold)
                .padding()
                .foregroundColor(.purple)
                .offset(y: 60)
            HStack{
                Button(
                    action: { fetchChatCompletion() },
                    label: {
                        Text(" Спросить \n цветочек ")
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .font(.system(size: 30))
                    })
                .cornerRadius(20)
                .frame(width: 500, height: 100)
                .offset(x: 160, y: 20)
                
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
            }
            .padding()
            .edgesIgnoringSafeArea(.all)
            .onChange(of: flowerName) { newValue in
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
            .onChange(of: bluetoothManager.temperature) { newValue in
                updateSensorValues()
                if updateDevName() {
                    self.flowerName = readFromFile()
                }
                if !bluetoothManager.isConnected {
                    deviceName = ""
                }
                print(deviceName)
                print(self.lightLevel)
            }
            .onChange(of: bluetoothManager.humidity) { newValue in
                updateSensorValues()
                if updateDevName() {
                    self.flowerName = readFromFile()
                }
                if !bluetoothManager.isConnected {
                    deviceName = ""
                }
                print(deviceName)
                print(self.lightLevel)
            }
            .onChange(of: bluetoothManager.lightLevel){ newValue in
                updateSensorValues()
                if updateDevName() {
                    self.flowerName = readFromFile()
                }
                if !bluetoothManager.isConnected {
                    deviceName = ""
                }
                print(deviceName)
                print(self.lightLevel)
            }
            .onChange(of: bluetoothManager.soilMoisture) { newValue in
                updateSensorValues()
                if updateDevName() {
                    self.flowerName = readFromFile()
                }
                if !bluetoothManager.isConnected {
                    deviceName = ""
                }
                print(deviceName)
                print(self.lightLevel)
            }
            .onChange(of: countEdits) { newValue in
                writeNewCount()
                if countEdits >= 10000 {
                    shrinkFile()
                    countEdits = 0
                }
            }
            .onChange(of: deviceName){ newValue in
                print(deviceName)
            }
        }
        .onAppear() {
            startDataUpdate()
            countEdits = Int(readEdits()) ?? 0
            print(countEdits)
            writeNewData(
                temp: temp,
                airHumidity: airHumidity,
                soilHumidity: soilHumidity,
                lightLevel: lightLevel
            )
        }
    }
    
    private func updateSensorValues() {
        self.temp = Int(bluetoothManager.temperature)
        self.airHumidity = Int(bluetoothManager.humidity)
        self.soilHumidity = Int(bluetoothManager.soilMoisture)
        self.lightLevel = Int(bluetoothManager.lightLevel)
        
        if temp >= 15 && temp <= 25 && airHumidity >= 40 && airHumidity <= 70 && soilHumidity >= 20 && soilHumidity <= 50 && lightLevel >= 20 && lightLevel <= 80 {
            chatRecommendation = "Все хорошо!"
        } else {
            chatRecommendation = "Спаси меня!"
        }
        
        writeNewData(
            temp: temp,
            airHumidity: airHumidity,
            soilHumidity: soilHumidity,
            lightLevel: lightLevel
        )
    }
    
    private func updateDevName() -> Bool{
        let oldName = self.deviceName
        self.deviceName = bluetoothManager.deviceName
        return oldName != self.deviceName
    }
    
    @MainActor
    func startDataUpdate() {}
    
    func fetchChatCompletion() {
        self.isLoading = true
        guard let url = URL(string: "https://router.huggingface.co/v1/chat/completions") else {
            self.chatResponse = "Неверный URL"
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer TOKEN", forHTTPHeaderField: "Authorization")
        
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
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            self.chatResponse = "Ошибка преобразования в JSON"
            self.isLoading = false
            return
        }
        
        request.httpBody = jsonData
        
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
    
    func writeNewName() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(
            self.deviceName + "FlowerName.txt"
        )
        do {
            try self.flowerName.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error write")
        }
    }
    
    func writeNewCount() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(self.deviceName + "DataCount.txt")
        do {
            try String(self.countEdits).write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error write")
        }
    }
    
    func readFromFile() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent((self.deviceName + "FlowerName.txt"))
        
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
    
    func readEdits() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(self.deviceName + "DataCount.txt")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return "0"
        }

        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            return fileContent
        } catch {
            return "0"
        }
    }
    
    func writeNewData(temp: Int, airHumidity: Int, soilHumidity: Int, lightLevel: Int) {
        if !bluetoothManager.isConnected {
            return
        }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let addString = "\(temp), \(airHumidity), \(soilHumidity), \(lightLevel)\n"
        let fileURL = documentsURL.appendingPathComponent(self.deviceName + "FlowerData.txt")
        
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
        let fileURL = documentsURL.appendingPathComponent(self.deviceName + "FlowerData.txt")
        
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
        let fileURL = documentsURL.appendingPathComponent(self.deviceName + "FlowerData.txt")
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            countEdits = 0
            writeNewCount()
        } catch {
            print("Error write")
        }
    }
}

struct DeviceListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String = ""
    
    var body: some View {
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
    }
}

#Preview {
    ContentView()
}
