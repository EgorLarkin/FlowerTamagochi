//
//  BluetoothManager.swift
//  Flower Tamagochi
//
//  Created by Сергей Ларкин on 24/11/2025.
//

import Foundation
import CoreBluetooth
import Combine
import UIKit

// MARK: - BluetoothManager

final class BluetoothManager: NSObject, ObservableObject {
    // MARK: Constants
    private enum Constants {
        static let serviceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
        static let characteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
        static let scanStatusSearching = "Поиск устройств ESP32..."
        static let scanStopped = "Сканирование остановлено"
        static let initStatus = "Инициализация Bluetooth..."
        static let unknownDevice = "Unknown Device"
        static let dhtSeparator = " | "
        static let tempPrefix = "Темп: "
        static let tempSuffix = "°C"
        static let humidityPrefix = "Влаж: "
        static let percentSuffix = "%"
        static let soilPrefix = "Почва: "
        static let lightPrefix = "Свет: "
    }

    // MARK: - Bluetooth
    private var centralManager: CBCentralManager
    private var connectedPeripheral: CBPeripheral?
    private var targetCharacteristic: CBCharacteristic?

    private let serviceUUID = Constants.serviceUUID
    private let characteristicUUID = Constants.characteristicUUID

    // MARK: - Published State
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var isConnected = false
    @Published var statusMessage = Constants.initStatus
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var deviceName: String = ""

    @Published var temperature: Float = 0.0
    @Published var humidity: Float = 0.0
    @Published var soilMoisture: Float = 0.0
    @Published var lightLevel: Float = 0.0

    // MARK: - Init
    override init() {
        self.centralManager = CBCentralManager()
        super.init()
        self.centralManager.delegate = self
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            statusMessage = getBluetoothStateDescription(centralManager.state)
            print("Не могу начать сканирование: \(statusMessage)")
            return
        }

        discoveredDevices.removeAll()

        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        statusMessage = Constants.scanStatusSearching
        print("Начато сканирование BLE устройств")
    }

    func stopScanning() {
        centralManager.stopScan()
        statusMessage = Constants.scanStopped
        print("Сканирование остановлено")
    }

    func connectToDevice(_ device: CBPeripheral) {
        stopScanning()
        connectedPeripheral = device
        centralManager.connect(device, options: nil)
        statusMessage = "Подключение к \(device.name ?? "устройству")..."
        print("Подключаемся к устройству: \(device.name ?? "Unknown")")
        self.deviceName = device.name ?? Constants.unknownDevice // Сохраняем имя устройства
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            print("Отключение от устройства")
            self.deviceName = "" // Очищаем имя при отключении
        }
    }

    // MARK: - Parsing
    // Функция для парсинга данных с датчиков
    private func parseSensorData(_ message: String) {
        print("Получены данные: \(message)")

        // Временные переменные для новых значений
        var newTemperature: Float = 0.0
        var newHumidity: Float = 0.0
        var newSoilMoisture: Float = 0.0
        var newLightLevel: Float = 0.0

        // Пример формата: "Темп: 23.5°C, Влаж: 45.0% | Почва: 65% | Свет: 80%"

        // Разделяем на части по разделителю
        let parts = message.components(separatedBy: Constants.dhtSeparator)

        // Парсим данные DHT (температура и влажность воздуха)
        if parts.count > 0 {
            let dhtPart = parts[0]

            // Ищем температуру
            if let tempRange = dhtPart.range(of: Constants.tempPrefix) {
                let tempSubstring = dhtPart[tempRange.upperBound...]
                if let degreeRange = tempSubstring.range(of: Constants.tempSuffix) {
                    let tempString = String(tempSubstring[..<degreeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if let tempValue = Float(tempString) {
                        newTemperature = tempValue
                        print("Температура: \(newTemperature)°C")
                    }
                }
            }

            // Ищем влажность воздуха
            if let humidityRange = dhtPart.range(of: Constants.humidityPrefix) {
                let humiditySubstring = dhtPart[humidityRange.upperBound...]
                if let percentRange = humiditySubstring.range(of: Constants.percentSuffix) {
                    let humidityString = String(humiditySubstring[..<percentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if let humidityValue = Float(humidityString) {
                        newHumidity = humidityValue
                        print("Влажность воздуха: \(newHumidity)%")
                    }
                }
            }
        }

        // Парсим влажность почвы
        if parts.count > 1 {
            let soilPart = parts[1]

            if let soilRange = soilPart.range(of: Constants.soilPrefix) {
                let soilSubstring = soilPart[soilRange.upperBound...]
                if let percentRange = soilSubstring.range(of: Constants.percentSuffix) {
                    let soilString = String(soilSubstring[..<percentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if let soilValue = Float(soilString) {
                        newSoilMoisture = soilValue
                        print("Влажность почвы: \(newSoilMoisture)%")
                    }
                }
            }
        }

        // Парсим освещенность
        if parts.count > 2 {
            let lightPart = parts[2]
            if let lightRange = lightPart.range(of: Constants.lightPrefix) {
                let lightSubstring = lightPart[lightRange.upperBound...]
                if let percentRange = lightSubstring.range(of: Constants.percentSuffix) {
                    let lightString = String(lightSubstring[..<percentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if let lightValue = Float(lightString) {
                        newLightLevel = lightValue
                        print("Уровень освещенности: \(newLightLevel)%")
                    }
                }
            }
        }

        // Обновляем значения на главном потоке
        DispatchQueue.main.async {
            self.temperature = newTemperature
            self.humidity = newHumidity
            self.soilMoisture = newSoilMoisture
            self.lightLevel = newLightLevel
        }
    }

    // MARK: - Helpers
    private func getBluetoothStateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn:
            return "Bluetooth включен"
        case .poweredOff:
            return "Bluetooth выключен"
        case .resetting:
            return "Bluetooth перезагружается"
        case .unauthorized:
            return "Нет разрешения на Bluetooth"
        case .unsupported:
            return "Bluetooth не поддерживается"
        case .unknown:
            return "Состояние Bluetooth неизвестно"
        @unknown default:
            return "Неизвестное состояние Bluetooth"
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.bluetoothState = central.state
            self.statusMessage = self.getBluetoothStateDescription(central.state)

            print("Состояние Bluetooth: \(self.statusMessage)")

            switch central.state {
            case .poweredOn:
                print("Bluetooth включен - начинаем сканирование")
                self.startScanning()
            case .poweredOff:
                print("Bluetooth выключен")
                self.isConnected = false
                self.discoveredDevices.removeAll()
                self.deviceName = "" // Очищаем имя при выключении Bluetooth
            case .unauthorized:
                print("Нет разрешения на Bluetooth")
            case .unsupported:
                print("Bluetooth LE не поддерживается")
            case .resetting:
                print("Bluetooth перезагружается")
            case .unknown:
                print("Состояние Bluetooth неизвестно")
            @unknown default:
                print("Неизвестное состояние Bluetooth")
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? Constants.unknownDevice

        DispatchQueue.main.async {
            if !self.discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredDevices.append(peripheral)
                print("Найдено устройство: \(deviceName), RSSI: \(RSSI)")
                self.statusMessage = "Найдено устройство: \(deviceName)"
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            print("Успешно подключено к: \(peripheral.name ?? "Unknown")")
            self.isConnected = true
            self.deviceName = peripheral.name ?? Constants.unknownDevice // Сохраняем имя при подключении
            self.statusMessage = "Подключено к \(self.deviceName)"
            peripheral.delegate = self

            // Ищем только наш сервис
            peripheral.discoverServices([self.serviceUUID])
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("Ошибка отключения: \(error.localizedDescription)")
            } else {
                print("Отключено от ESP32")
            }

            self.isConnected = false
            self.statusMessage = "\(self.deviceName) отключен"
            self.targetCharacteristic = nil
            self.deviceName = "" // Очищаем имя при отключении

            // Перезапускаем сканирование через 2 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if self.bluetoothState == .poweredOn {
                    self.startScanning()
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            print("Ошибка подключения: \(error?.localizedDescription ?? "Unknown error")")
            self.statusMessage = "Ошибка подключения"

            // Возобновляем сканирование
            if self.bluetoothState == .poweredOn {
                self.startScanning()
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Ошибка поиска сервисов: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            print("Нет сервисов")
            return
        }

        for service in services {
            // Ищем характеристики только для нашего сервиса
            if service.uuid == serviceUUID {
                print("Найден сервис, ищем характеристики...")
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Ошибка поиска характеристик: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            print("Нет характеристик")
            return
        }

        for characteristic in characteristics {
            // Если это наша целевая характеристика
            if characteristic.uuid == characteristicUUID {
                print("Найдена характеристика для получения данных")
                self.targetCharacteristic = characteristic

                // Подписываемся на уведомления
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Подписались на уведомления")
                }

                // Читаем начальное значение
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                    print("Чтение начального значения")
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Ошибка получения данных: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value else {
            print("Нет данных")
            return
        }

        let message = String(data: data, encoding: .utf8) ?? "Нечитаемые данные"

        DispatchQueue.main.async {
            print("Получены данные от \(self.deviceName): \(message)")

            // Парсим данные с датчиков
            self.parseSensorData(message)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Ошибка подписки: \(error.localizedDescription)")
        } else {
            print("Уведомления: \(characteristic.isNotifying ? "включены" : "выключены")")
        }
    }
}
