import SwiftUI
import Foundation

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
    @State private var temp: Int?
    @State private var airHumidity: Int?
    @State private var soilHumidity: Int?
    @State private var showStats: Bool = false
    @State private var countEdits: Int = 0
//    @ObservedObject var bluetoothManager = BluetoothManager()
    var body: some View {
        ScrollView(.vertical, showsIndicators: false){
            VStack {
                HStack{
                    VStack(alignment: .leading){
                        Text("🌡️: \(temp ?? 0)°C")
                            .font(.system(size: 30))
                        Text("💧: \(airHumidity ?? 0)%")
                            .font(.system(size: 30))
                        Text("🪴: \(soilHumidity ?? 0)%")
                            .font(.system(size: 30))
                    }
                    FlowMessage(message: chatRecommendation)
                        .padding()
                        .offset(x: 40)
                }
                Image("Flower")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 400)
                    .offset(x: -25, y: -50)
                    .padding()
                TextField("Имя цветка", text: $flowerName)
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                    .foregroundColor(.purple)
                    .offset(y: -150)
                if chatResponse != "" || isLoading{
                    HStack{
                        Image(systemName: "exclamationmark.triangle.text.page")
                            .foregroundColor(.red)
                            .font(.system(size: 50))
                            .offset(y: -150)
                        if isLoading{
                            Text("Цветочек думает...")
                                .foregroundColor(.red)
                                .font(.system(size: 25))
                                .offset(y: -150)
                                .multilineTextAlignment(.center)
                            
                        } else {
                            Text(chatResponse)
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.red)
                                .font(.system(size: 25))
                                .offset(y: -150)
                                .frame(maxWidth: 250)
                        }
                    }
                }
                Button(
                    action: {fetchChatCompletion()},
                    label: {
                        Text(" Спросить  цветочек ")
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .font(.system(size: 30))
                    })
                .cornerRadius(20)
                .frame(width: 500)
                .offset(y: -100)
                Button(
                    action: {showStats = true}, label: {
                        Text(" Статистика цветочка ")
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .font(.system(size: 30))
                    }
                )
                .cornerRadius(20)
                .frame(width: 500)
                .offset(y: -75)
            }
            .padding()
            .edgesIgnoringSafeArea(.all)
            .onChange(of: flowerName) { newValue in
                writeNewName()
            }
            .sheet(isPresented: $showStats){StatsModal()}
            .onChange(of: temp) { newValue in
                if temp ?? 0 >= 15 && temp ?? 0 <= 25 && airHumidity ?? 0 >= 40 && airHumidity ?? 0 <= 70 && soilHumidity ?? 0 >= 20 && soilHumidity ?? 0 <= 50 {
                    chatRecommendation = "Все хорошо!"
                    writeNewData(
                        temp: temp ?? 0,
                        airHumidity: airHumidity ?? 0,
                        soilHumidity: soilHumidity ?? 0
                    )
                }else{
                    chatRecommendation = "Спаси меня!"
                    writeNewData(
                        temp: temp ?? 0,
                        airHumidity: airHumidity ?? 0,
                        soilHumidity: soilHumidity ?? 0
                    )
                }
            }
            .onChange(of: countEdits) { newValue in
                writeNewCount()
                if countEdits >= 10 {
                    shrinkFile()
                    countEdits = 0
                }
                
            }
        }
        .onAppear() {
            countEdits = Int(readEdits())!
            print(countEdits)
            flowerName = readFromFile()
            writeNewData(
                temp: temp ?? 0,
                airHumidity: airHumidity ?? 0,
                soilHumidity: soilHumidity ?? 0
            )
//            bluetoothManager.centralManagerDidUpdateState(bluetoothManager.centralManager)
//            clearFile()
        }
        
    }
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
                    "content": "Дай очень краткий ответ, пожалуйста. Если цветку все хорошо, обратившись к пользователю от имени цветка \(flowerName) без обращения к нему, от имени цветка, не предлагай варианты с изменением местоположения цветка, а только к его состоянию: Что нужно цветку \"роза\", который стоит в комнате при температуре \(temp ?? 0)°C, влажности воздуха \(airHumidity ?? 0)% и влажности почвы \(soilHumidity ?? 0)%?; ответь непринужденно и шуточно."
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
    func writeNewName() -> Void{
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("FlowerName.txt")
        do {
            try self.flowerName.write(to: fileURL, atomically: true, encoding: .utf8)
        }catch{
            print("Error write")
        }
    }
    func writeNewCount() -> Void{
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("DataCount.txt")
        do {
            try String(self.countEdits).write(to: fileURL, atomically: true, encoding: .utf8)
        }catch{
            print("Error write")
        }
    }
    func readFromFile() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("FlowerName.txt")
        
        // Проверка существования файла
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
        let fileURL = documentsURL.appendingPathComponent("DataCount.txt")
        
        // Проверка существования файла
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
    func writeNewData(temp: Int, airHumidity: Int, soilHumidity: Int){
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let addString = "\(temp), \(airHumidity), \(soilHumidity)\n"
        let fileURL = documentsURL.appendingPathComponent("FlowerData.txt")
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
        var dataArray: [String] = []
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("FlowerData.txt")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist")
            return
        }
        
        do {
            let data = try String(contentsOf: fileURL, encoding: .utf8)
            dataArray = data.split(separator: "\n").map(String.init)
            
            if dataArray.count < 10 {
                print("Not enough data to shrink.")
                return
            }

            for i in dataArray[dataArray.count - 10..<dataArray.count] {
                let components = i.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if components.count == 3,
                   let tempValue = Int(components[0]),
                   let airHumidityValue = Int(components[1]),
                   let soilHumidityValue = Int(components[2]) {
                    sum_temp += tempValue
                    sum_airHumidity += airHumidityValue
                    sum_soilHumidity += soilHumidityValue
                }
            }

            let average_temp: Int = sum_temp / 10
            let average_airHumidity: Int = sum_airHumidity / 10
            let average_soilHumidity: Int = sum_soilHumidity / 10

            print("Average Temp: \(average_temp), Average Air Humidity: \(average_airHumidity), Average Soil Humidity: \(average_soilHumidity)")
            let addString = "\(average_temp), \(average_airHumidity), \(average_soilHumidity)\n"
            
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
    func clearFile(){
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("FlowerData.txt")
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            countEdits = 0
            writeNewCount()
        }catch{
            print("Error write")
        }
    }
}

#Preview {
    ContentView()
}
