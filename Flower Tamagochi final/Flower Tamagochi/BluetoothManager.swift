//
//  BluetoothManager.swift
//  Flower Tamagochi
//
//  Created by Сергей Ларкин on 15/09/2025.
//

import Foundation
import CoreBluetooth

/*class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var receivedText: String = ""
    @Published var isConnected: Bool = false
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private let serviceUUID = CBUUID(string: "YOUR_SERVICE_UUID")
    private let characteristicUUID = CBUUID(string: "YOUR_CHARACTERISTIC_UUID")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        } else {
            isConnected = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        centralManager.stopScan()
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, let value = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                
                self.receivedText += value + "\n"
            }
        }
    }
    
    func sendData(data: String) {
        guard let peripheral = peripheral,
              let dataToSend = data.data(using: .utf8),
              let characteristic = peripheral.services?.first?.characteristics?.first else { return }
        
        peripheral.writeValue(dataToSend, for: characteristic, type: .withResponse)
    }
}
*/
