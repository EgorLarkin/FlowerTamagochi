import SwiftUI

struct Message: Identifiable, Codable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var role: String {
        return isUser ? "user" : "assistant"
    }
}

// Для сохранения истории
struct ChatHistory: Codable {
    var messages: [Message]
    var lastUpdated: Date
}

struct ChatCompletionResponseView: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: MessageResponse
    }
    
    struct MessageResponse: Codable {
        let role: String
        let content: String
    }
}

struct ChatView: View {
    @ObservedObject private var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChatViewModel
    
    init(viewModel: ChatViewModel, bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack {
            HStack {
                Image("Flower")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                Spacer()
                Text("Чат с цветочком")
                    .font(.system(size: 25))
                    .foregroundColor(.mint)
                    .fontWeight(.bold)
                Spacer()
                
                // Кнопка очистки истории
                Button(action: {
                    viewModel.clearChatHistory()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .padding(.trailing)
            }
            .padding()
            .background(Color(.systemBackground))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                        
                        if viewModel.isLoading {
                            ThinkingIndicator()
                                .id("loading")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation {
                        if let lastMessage = viewModel.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isLoading) { isLoading in
                    if isLoading {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
                .onChange(of: bluetoothManager.isConnected){
                    if !bluetoothManager.isConnected {
                        dismiss()
                    }
                }
            }
            .background(Color(.systemGray6))
            
            VStack {
                Divider()
                
                HStack(alignment: .bottom, spacing: 12) {
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Введите сообщение...", text: $messageText, axis: .vertical)
                            .textFieldStyle(DefaultTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.blue)
                                .opacity(messageText.isEmpty ? 0.5 : 1)
                        }
                        .disabled(messageText.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Чат с цветком")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Загружаем историю при появлении
            viewModel.loadChatHistory()
        }
        .onDisappear {
            // Сохраняем историю при уходе
            viewModel.saveChatHistory()
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let userMessage = Message(
            content: messageText,
            isUser: true,
            timestamp: Date()
        )
        viewModel.messages.append(userMessage)
        
        // Сохраняем историю после каждого сообщения
        viewModel.saveChatHistory()
        
        viewModel.fetchChatCompletion(userMessage: messageText)
        
        messageText = ""
        isTextFieldFocused = false
    }
}

class ChatViewModel: ObservableObject {
    @ObservedObject private var bluetoothManager: BluetoothManager
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var chatResponse = ""
    @Published var showFlowerParameters = false
    
    private var flowerName: String?
    private let maxHistoryMessages = 20 // Максимальное количество сообщений в истории
    
    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }
    
    func fetchChatCompletion(userMessage: String) {
        if self.flowerName == nil {
            self.flowerName = readFromFile()
        }
        isLoading = true
        
        guard let url = URL(string: "https://router.huggingface.co/v1/chat/completions") else {
            self.chatResponse = "Неверный URL"
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer TOKEN", forHTTPHeaderField: "Authorization")
        
        // Подготавливаем историю сообщений для отправки
        let systemMessage = [
            "role": "system",
            "content": prepareSystemMessage()
        ]
        
        // Преобразуем историю сообщений в формат для API
        var apiMessages: [[String: String]] = [systemMessage]
        
        // Берем последние N сообщений для контекста (чтобы не превысить лимит токенов)
        let recentMessages = Array(messages.suffix(maxHistoryMessages))
        
        for message in recentMessages {
            apiMessages.append([
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ])
        }
        
        // Добавляем текущее сообщение пользователя
        apiMessages.append([
            "role": "user",
            "content": userMessage
        ])
        
        let body: [String: Any] = [
            "stream": false,
            "model": "deepseek-ai/DeepSeek-V3.2-Exp:novita",
            "messages": apiMessages
        ]
        
        print("Отправляем \(apiMessages.count) сообщений в истории")
        
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
                    let errorMessage = Message(
                        content: "Ошибка: \(error.localizedDescription)",
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(errorMessage)
                    self.saveChatHistory() // Сохраняем после ошибки тоже
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    let errorMessage = Message(
                        content: "Не удалось получить HTTP ответ",
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(errorMessage)
                    self.saveChatHistory()
                }
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    let errorMessage = Message(
                        content: "Ошибка HTTP: \(httpResponse.statusCode)",
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(errorMessage)
                    self.saveChatHistory()
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    let errorMessage = Message(
                        content: "Нет данных получено",
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(errorMessage)
                    self.saveChatHistory()
                }
                return
            }
            
            do {
                let chatResponse = try JSONDecoder().decode(ChatCompletionResponseView.self, from: data)
                DispatchQueue.main.async {
                    if let messageContent = chatResponse.choices.first?.message.content {
                        let responseMessage = Message(
                            content: messageContent,
                            isUser: false,
                            timestamp: Date()
                        )
                        self.messages.append(responseMessage)
                        self.chatResponse = messageContent
                        self.saveChatHistory() // Сохраняем после получения ответа
                    } else {
                        let errorMessage = Message(
                            content: "Нет сообщений в ответе.",
                            isUser: false,
                            timestamp: Date()
                        )
                        self.messages.append(errorMessage)
                        self.saveChatHistory()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    let errorMessage = Message(
                        content: "Ошибка декодирования: \(error.localizedDescription)",
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(errorMessage)
                    self.saveChatHistory()
                }
            }
        }
        task.resume()
    }
    
    private func prepareSystemMessage() -> String {
        let flowerName = self.flowerName ?? "Цветок"
        let temp = bluetoothManager.temperature
        let humidity = bluetoothManager.humidity
        let soilMoisture = bluetoothManager.soilMoisture
        let lightLevel = bluetoothManager.lightLevel
        
        return """
        Ты - цветок по имени \(flowerName). 
        Отвечай от своего имени, неформально, немного шутливо, поддерживай разговор с пользователем.
        
        Текущие показатели:
        - Температура воздуха: \(temp)°C
        - Влажность воздуха: \(humidity)%
        - Влажность почвы: \(soilMoisture)%
        - Уровень света: \(lightLevel)%
        
        Если состояние не очень хорошее - отвечай не очень весело.
        Поддерживай контекст предыдущих сообщений в диалоге.
        """
    }
    
    // MARK: - Сохранение и загрузка истории
    
    private func getHistoryFileName() -> String {
        let deviceName = bluetoothManager.deviceName
        return "\(deviceName)_ChatHistory.json"
    }
    
    private func getHistoryFileURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(getHistoryFileName())
    }
    
    func saveChatHistory() {
        let history = ChatHistory(messages: messages, lastUpdated: Date())
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            try data.write(to: getHistoryFileURL())
            print("История чата сохранена (\(messages.count) сообщений)")
        } catch {
            print("Ошибка сохранения истории чата: \(error)")
        }
    }
    
    func loadChatHistory() {
        let fileURL = getHistoryFileURL()
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Файл истории не найден, начинаем новый чат")
            addWelcomeMessage()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let history = try decoder.decode(ChatHistory.self, from: data)
            
            // Фильтруем старые сообщения (например, старше 7 дней)
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let filteredMessages = history.messages.filter { $0.timestamp > weekAgo }
            
            DispatchQueue.main.async {
                if filteredMessages.isEmpty {
                    self.addWelcomeMessage()
                } else {
                    self.messages = filteredMessages
                    print("История чата загружена (\(filteredMessages.count) сообщений)")
                }
            }
        } catch {
            print("Ошибка загрузки истории чата: \(error)")
            addWelcomeMessage()
        }
    }
    
    func clearChatHistory() {
        messages.removeAll()
        saveChatHistory()
        
        // Добавляем приветственное сообщение
        addWelcomeMessage()
        
        print("История чата очищена")
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = Message(
            content: "Привет! Я цветок \(flowerName ?? "ваш зеленый друг"). Давай поболтаем!",
            isUser: false,
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }
    
    // Управление размером истории
    func trimHistoryIfNeeded() {
        if messages.count > maxHistoryMessages * 2 {
            // Оставляем последние N*2 сообщений
            messages = Array(messages.suffix(maxHistoryMessages * 2))
            saveChatHistory()
            print("История чата обрезана до \(messages.count) сообщений")
        }
    }
    
    func readFromFile() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent((self.bluetoothManager.deviceName + "FlowerName.txt"))
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return "Цветок"
        }

        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            return fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Цветок"
        }
    }
}

// MARK: - Дополнительные вью

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.isUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(18)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Копировать", systemImage: "doc.on.doc")
                        }
                    }
                
                Text(formatDate(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Вчера, \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "dd.MM HH:mm"
        }
        return formatter.string(from: date)
    }
}

struct ThinkingIndicator: View {
    @State private var dotCount = 0
    
    var body: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .foregroundColor(.green)
            
            Text("Цветок думает")
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index < dotCount ? .green : .gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
            .onAppear {
                startAnimation()
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(20)
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation {
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}
