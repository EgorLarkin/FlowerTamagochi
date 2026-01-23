import SwiftUI
import UIKit
import ImageIO

// MARK: - GIF Support
struct GIFView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        guard
            let gifURL = Bundle.main.url(forResource: gifName, withExtension: "gif"),
            let gifData = try? Data(contentsOf: gifURL),
            let source = CGImageSourceCreateWithData(gifData as CFData, nil)
        else {
            return container
        }

        let imageView = UIImageView()
        var frames: [UIImage] = []
        let frameCount = CGImageSourceGetCount(source)

        for index in 0..<frameCount {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) {
                frames.append(UIImage(cgImage: cgImage))
            }
        }

        imageView.animationImages = frames
        imageView.animationDuration = 2.0
        imageView.animationRepeatCount = 1
        imageView.startAnimating()

        container.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: container.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: container.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}

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

// MARK: - Content
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

    // MARK: Heart/Crying Animation State
    @State private var showingHeartAnimation = false
    @State private var showingCryingAnimation: Bool = false

    var body: some View {
        VStack {
            header
                .padding(.horizontal)

            Spacer()

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
            
            .onChange(of: self.isCrying) { _, newValue in
                if newValue {
                    startCryingAnimationTimer()
                } else {
                    startHeartAnimationTimer()
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
                startHeartAnimationTimer()
            }
    }
}

// MARK: - Timers & Animations
private extension ContentView {
    func startHeartAnimationTimer() {
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            showHeartAnimation()
        }
    }

    func showHeartAnimation() {
        self.showingHeartAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showingHeartAnimation = false
        }
    }

    func startCryingAnimationTimer() {
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            showCryingAnimation()
        }
    }

    func showCryingAnimation() {
        self.showingCryingAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showingCryingAnimation = false
        }
    }
}

// MARK: - Subviews
private extension ContentView {
    var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(bluetoothManager.statusMessage)
                    .font(.system(size: 14))
                    .foregroundColor(Color("UpColor"))

                Button(action: { showDeviceList = true }) {
                    Text("Показать устройства")
                        .font(.system(size: 14))
                        .foregroundColor(Color("UpColor"))
                }
            }

            Spacer()
                .offset(x: 40)

            Button(action: { self.isChatting = true }) {
                Image(systemName: "message.badge")
                    .font(.system(size: 40))
                    .foregroundColor(Color("UpColor"))
            }
            .disabled(!bluetoothManager.isConnected)
        }
    }

    var flowerArea: some View {
        ZStack {
            Image("Flower")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 350)
                .offset(x: 0, y: 100)
                .padding()
                .zIndex(2)

            sensorBoard
                .offset(x: 0, y: 180)
                .zIndex(3)

            if isCrying && bluetoothManager.isConnected {
                cryingLayer
                    .zIndex(3)
                    .offset(x: 20)
            } else if bluetoothManager.isConnected {
                happyLayer
                    .zIndex(3)
                    .offset(x: 20)
            } else {
                Image("HappyFace")
                    .resizable()
                    .offset(x: 1, y: -170)
                    .frame(width: 350, height: 300)
                    .zIndex(3)
            }
        }
    }

    var cryingLayer: some View {
        Group {
            if showingCryingAnimation {
                ZStack {
                    GIFView(gifName: "CryingAnimation")
                        .frame(width: 160, height: 130)
                        .offset(x: -17, y: -178)
                        .background(Color.clear)

                    Image("FaceForGif")
                        .resizable()
                        .offset(x: -19, y: -170)
                        .frame(width: 350, height: 300)
                }
                .offset(x: 1, y: 1)
            } else {
                Image("CryingFace")
                    .resizable()
                    .offset(x: -17, y: -155)
                    .frame(width: 400, height: 340)
            }
        }
    }

    var happyLayer: some View {
        Group {
            if showingHeartAnimation {
                ZStack {
                    GIFView(gifName: "HeartAnimation")
                        .frame(width: 170, height: 170)
                        .offset(x: -19, y: -190)
                        .background(Color.clear)

                    Image("FaceForGif")
                        .resizable()
                        .offset(x: -19, y: -170)
                        .frame(width: 350, height: 300)
                }
            } else {
                Image("HappyFace")
                    .resizable()
                    .offset(x: -19, y: -170)
                    .frame(width: 350, height: 300)
            }
        }
    }

    var sensorBoard: some View {
        ZStack {
            Rectangle()
                .frame(width: 150, height: 100)
                .cornerRadius(10)
                .foregroundColor(.black)
                .padding()
            if self.showsData {
                VStack(alignment: .leading) {
                    HStack {
                        Text("🌡️: \(bluetoothManager.isConnected ? temp: 0)°C")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.white))

                        HorizontalThermometer(bluetoothManager: self.bluetoothManager)
                    }
                    .offset(y: 10)

                    HStack {
                        Text("☁️: \(bluetoothManager.isConnected ? airHumidity : 0)% ")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.white))

                        GradientStatusBarAirHumidity(bluetoothManager: bluetoothManager)
                    }
                    .offset(y: 5)

                    HStack {
                        Text("💧: \(bluetoothManager.isConnected ? soilHumidity : 0)% ")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.white))

                        GradientStatusBarSoilHumidity(bluetoothManager: bluetoothManager)
                    }
                    .offset(y: 0)

                    HStack {
                        Text("☀️: \(bluetoothManager.isConnected ? lightLevel : 0)% ")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.white))

                        GradientStatusBarLight(bluetoothManager: bluetoothManager)
                    }
                    .offset(y: -5)
                }
            } else {
                chatScroll
                    .offset(y: 215)
            }
        }
    }

    var chatScroll: some View {
        ScrollView {
            if isLoading {
                Text("Цветочек думает...")
                    .foregroundColor(.white)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .zIndex(1)
                    .offset(y: 15)
            } else {
                Text(chatResponse)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15))
                    .foregroundColor(.yellow)
            }
        }
        .offset(y: -210)
        .frame(maxWidth: 130, maxHeight: 80)
    }

    var nameField: some View {
        TextField("Имя цветка", text: $flowerName)
            .multilineTextAlignment(.center)
            .font(.title)
            .fontWeight(.bold)
            .padding()
            .foregroundColor(Color("UpColor"))
            .offset(y: 60)
            .disabled(!bluetoothManager.isConnected)
    }

    var actionButtons: some View {
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
                        .background(Color("btnColor"))
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
                        .background(Color("btnColor"))
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
}

// MARK: - Logic
private extension ContentView {
    func sensorDrivenUpdate() {
        updateSensorValues()

        if updateDevName() {
            self.flowerName = readFromFile()
        }

        if !bluetoothManager.isConnected {
            deviceName = ""
        }
    }

    func updateSensorValues() {
        self.temp = Int(bluetoothManager.temperature)
        self.airHumidity = Int(bluetoothManager.humidity)
        self.soilHumidity = Int(bluetoothManager.soilMoisture)
        self.lightLevel = Int(bluetoothManager.lightLevel)

        if temp >= 15 && temp <= 30 && airHumidity >= 20 && airHumidity <= 80 && soilHumidity >= 20 && lightLevel >= 20 {
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

    func updateDevName() -> Bool {
        let oldName = self.deviceName
        self.deviceName = bluetoothManager.deviceName
        return oldName != self.deviceName
    }

    @MainActor
    func startDataUpdate() {}
}

// MARK: - File Names
private extension ContentView {
    func flowerNameFileName() -> String { self.deviceName + "FlowerName.txt" }
    func dataCountFileName() -> String { self.deviceName + "DataCount.txt" }
    func flowerDataFileName() -> String { self.deviceName + "FlowerData.txt" }
}

// MARK: - Networking
private extension ContentView {
    func makeChatRequest(url: URL, body: [String: Any]) -> URLRequest? {
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
}

// MARK: - Persistence
private extension ContentView {
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

// MARK: - Device List
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
                            .background(Color("btnColor"))
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
