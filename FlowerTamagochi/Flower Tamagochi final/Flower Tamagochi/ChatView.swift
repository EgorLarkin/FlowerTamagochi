import Foundation
import SwiftUI

struct Message: Identifiable, Codable {
    var id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date

    var role: String { isUser ? "user" : "assistant" }
}

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

final class ChatAPIService {

    private let apiURL = URL(string: "https://router.huggingface.co/v1/chat/completions")!
    private let apiKey = "Bearer TOKEN"

    func sendRequest(messages: [[String: String]],
                     completion: @escaping (Result<String, Error>) -> Void) {

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "stream": false,
            "model": "deepseek-ai/DeepSeek-V3.2-Exp:novita",
            "messages": messages
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(NSError(domain: "JSONEncoding", code: 1)))
            return
        }

        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                completion(.failure(error)); return
            }

            guard
                let http = response as? HTTPURLResponse,
                (200...299).contains(http.statusCode),
                let data = data
            else {
                completion(.failure(NSError(domain: "HTTPError", code: 2)))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(ChatCompletionResponseView.self, from: data)
                completion(.success(decoded.choices.first?.message.content ?? "Пустой ответ"))
            } catch {
                completion(.failure(error))
            }

        }.resume()
    }
}

final class ChatHistoryManager {

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func fileURL(for deviceName: String) -> URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("\(deviceName)_ChatHistory.json")
    }

    func loadHistory(for deviceName: String) -> [Message]? {
        let url = fileURL(for: deviceName)

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let history = try decoder.decode(ChatHistory.self, from: data)

            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!

            let filtered = history.messages.filter { $0.timestamp > weekAgo }
            return filtered
        } catch {
            print("Error loading chat history:", error)
            return nil
        }
    }

    func saveHistory(messages: [Message], deviceName: String) {
        let history = ChatHistory(messages: messages, lastUpdated: .now)
        let url = fileURL(for: deviceName)

        do {
            let data = try encoder.encode(history)
            try data.write(to: url)
        } catch {
            print("Error saving chat history:", error)
        }
    }
}

final class ChatViewModel: ObservableObject {

    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var chatResponse = ""

    private let bluetoothManager: BluetoothManager
    private let apiService = ChatAPIService()
    private let historyManager = ChatHistoryManager()

    private let maxHistoryMessages = 20
    private var flowerName: String?

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }

    // MARK: - API

    func fetchChatCompletion(userMessage: String) {
        isLoading = true

        if flowerName == nil {
            flowerName = readFlowerName()
        }

        let systemMessage: [String: String] = [
            "role": "system",
            "content": prepareSystemMessage()
        ]

        let recent = Array(messages.suffix(maxHistoryMessages))

        let history: [[String: String]] = recent.map {
            ["role": $0.role, "content": $0.content]
        }

        let requestMessages =
            [systemMessage] + history + [["role": "user", "content": userMessage]]

        apiService.sendRequest(messages: requestMessages) { result in
            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let content):
                    let message = Message(content: content, isUser: false, timestamp: .now)
                    self.messages.append(message)
                    self.chatResponse = content
                case .failure(let error):
                    let message = Message(content: "Ошибка: \(error.localizedDescription)",
                                          isUser: false, timestamp: .now)
                    self.messages.append(message)
                }

                self.saveChatHistory()
            }
        }
    }

    // MARK: - System prompt

    private func prepareSystemMessage() -> String {
        """
        Ты — цветок по имени \(flowerName ?? "Цветок").
        Отвечай неформально, дружелюбно и от своего лица.

        Показатели:
        • Температура: \(bluetoothManager.temperature)°C
        • Влажность воздуха: \(bluetoothManager.humidity)%
        • Влажность почвы: \(bluetoothManager.soilMoisture)%
        • Освещённость: \(bluetoothManager.lightLevel)%

        Если параметры плохие — отвечай менее радостно.
        Учитывай контекст диалога.
        """
    }

    // MARK: - History

    func loadChatHistory() {
        if let saved = historyManager.loadHistory(for: bluetoothManager.deviceName),
           !saved.isEmpty {
            messages = saved
        } else {
            addWelcomeMessage()
        }
    }

    func saveChatHistory() {
        historyManager.saveHistory(messages: messages, deviceName: bluetoothManager.deviceName)
    }

    func clearChatHistory() {
        messages.removeAll()
        saveChatHistory()
        addWelcomeMessage()
    }

    private func addWelcomeMessage() {
        messages.append(
            Message(
                content: "Привет! Я цветок \(flowerName ?? "без имени"). Давай поболтаем!",
                isUser: false,
                timestamp: .now
            )
        )
    }

    // MARK: - Helpers

    private func readFlowerName() -> String {
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("\(bluetoothManager.deviceName)FlowerName.txt")

        guard let text = try? String(contentsOf: fileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return "Цветок" }

        return text
    }
}

struct ChatView: View {

    @ObservedObject private var bluetoothManager: BluetoothManager
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool

    // MARK: - Init

    init(viewModel: ChatViewModel, bluetoothManager: BluetoothManager) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.bluetoothManager = bluetoothManager
    }

    // MARK: - Body

    var body: some View {
        VStack {
            header
            messageList
            inputField
        }
        .navigationTitle("Чат с цветком")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.loadChatHistory() }
        .onDisappear { viewModel.saveChatHistory() }
        .onChange(of: bluetoothManager.isConnected) { _, newValue in
            if !newValue {
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image("Flower")
                .resizable()
                .frame(width: 50, height: 50)
                .clipShape(Circle())

            Spacer()

            Text("Чат с цветочком")
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(.mint)

            Spacer()

            Button(action: viewModel.clearChatHistory) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(.trailing)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Messages List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        ThinkingIndicator()
                            .id("loading")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGray6))
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToLast(proxy)
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading { scrollToLoading(proxy) }
            }
        }
    }

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        withAnimation {
            if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func scrollToLoading(_ proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("loading", anchor: .bottom)
        }
    }

    // MARK: - Input Field

    private var inputField: some View {
        VStack {
            Divider()

            HStack(spacing: 12) {
                TextField("Введите сообщение...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit(sendMessage)

                Button(action: sendMessage) {
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

    // MARK: - Actions

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let message = Message(
            content: messageText,
            isUser: true,
            timestamp: .now
        )

        viewModel.messages.append(message)
        viewModel.saveChatHistory()
        viewModel.fetchChatCompletion(userMessage: messageText)

        messageText = ""
        isTextFieldFocused = false
    }
}

struct MessageBubble: View {
    let message: Message

    var isUser: Bool { message.isUser }

    var body: some View {
        HStack {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(alignment: .bottom) {

                    if !isUser { avatar }

                    bubble

                    if isUser { avatarHidden }
                }

                timestamp
            }
            .padding(isUser ? .leading : .trailing, 40)
            .padding(.vertical, 4)

            if !isUser { Spacer() }
        }
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
        .animation(.easeOut(duration: 0.2), value: message.id)
    }

    // MARK: - Components

    private var bubble: some View {
        Text(message.content)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .foregroundColor(bubbleTextColor)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .contextMenu { copyButton }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isUser ? .trailing : .leading)
    }

    // MARK: Appearance

    private var bubbleBackground: Color {
        isUser ? Color.blue : Color(.systemGray5)
    }

    private var bubbleTextColor: Color {
        isUser ? .white : .primary
    }

    // MARK: Avatar

    private var avatar: some View {
        Image(systemName: "leaf.fill")
            .foregroundColor(.green)
            .font(.system(size: 22))
            .opacity(0.8)
    }

    private var avatarHidden: some View {
        Color.clear.frame(width: 22, height: 22)
    }

    // MARK: Timestamp

    private var timestamp: some View {
        Text(formatDate(message.timestamp))
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()

        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Вчера, " + DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        } else {
            formatter.dateFormat = "dd.MM HH:mm"
        }

        return formatter.string(from: date)
    }

    // MARK: - Context menu

    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = message.content
        } label: {
            Label("Копировать", systemImage: "doc.on.doc")
        }
    }
}

struct ThinkingIndicator: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {

            Image(systemName: "leaf.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)
                .opacity(0.9)

            Text("Цветок думает")
                .foregroundColor(.secondary)
                .font(.subheadline)

            DotsAnimation()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
        )
        .padding(.vertical, 4)
    }
}

// MARK: - Animated dots

struct DotsAnimation: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundColor(.green)
                    .scaleEffect(animate ? 1.0 : 0.3)
                    .opacity(animate ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(0.2 * Double(index)),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

