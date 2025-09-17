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
                        Image(systemName: "exclamationmark.brakesignal")
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
                    action: {
                        
                    }, label: {
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
        }
        .onAppear() {
            flowerName = readFromFile()
            writeNewData(
                temp: temp ?? 0,
                airHumidity: airHumidity ?? 0,
                soilHumidity: soilHumidity ?? 0
            )
//            bluetoothManager.centralManagerDidUpdateState(bluetoothManager.centralManager)
        }
        
    }
    func fetchChatCompletion() {
        self.isLoading = true
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            self.chatResponse = "Неверный URL"
            self.isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer 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", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": "deepseek/deepseek-chat-v3.1:free",
            "messages": [
                [
                    "role": "user",
                    "content": "Дай ответ в одну строку, обратившись к пользователю без обращения к нему, от имени цветка, не предлагай варианты с изменением местоположения цветка, а только к его состоянию: Что нужно цветку \"роза\", который стоит в комнате при температуре \(temp ?? 0)°C, влажности воздуха \(airHumidity ?? 0)% и влажности почвы \(soilHumidity ?? 0)%?; а если цветку очень плохо, то ответь шуточно."
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
        let path = "/Users/sergejlarkin/Documents/Flower Tamagochi final/Flower Tamagochi/FlowerName.txt"
        do {
            try self.flowerName.write(toFile: path, atomically: true, encoding: .utf8)
        }catch{
            print("Error write")
        }
    }
    func readFromFile()-> String{
        let path = "/Users/sergejlarkin/Documents/Flower Tamagochi final/Flower Tamagochi/FlowerName.txt"
        var fileContent: String = ""
        do {
            fileContent = try String(contentsOfFile: path, encoding: .utf8)
            return fileContent
        } catch {
            return "Error read"
        }
    }
    func writeNewData(temp: Int, airHumidity: Int, soilHumidity: Int){
        var fileContent: String = ""
        var addString = "\(temp), \(airHumidity), \(soilHumidity)"
        let path = "/Users/sergejlarkin/Documents/Flower Tamagochi final/Flower Tamagochi/FlowerData.txt"
        do {
            fileContent = try String(contentsOfFile: path, encoding: .utf8)
            fileContent += "\n" + addString
            try fileContent.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Error update data")
        }
    }
}

#Preview {
    ContentView()
}
