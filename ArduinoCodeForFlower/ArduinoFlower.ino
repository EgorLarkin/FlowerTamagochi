#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <DHT.h>

// UUID для сервиса и характеристик
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Пин для датчика DHT
#define DHT_PIN 22
#define DHT_TYPE DHT22   // или DHT22, в зависимости от вашего датчика

// Пин для датчика влажности почвы
#define SOIL_MOISTURE_PIN A0

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Создание объекта DHT
DHT dht(DHT_PIN, DHT_TYPE);

// Callback для подключения/отключения устройств
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Устройство подключено");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Устройство отключено");
    }
};

// Callback для записи данных
class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = pCharacteristic->getValue();
      
      if (value.length() > 0) {
        Serial.print("Получено сообщение: ");
        Serial.println(value);
        
        // Эхо-ответ
        String response = "ESP32 получил: " + value;
        pCharacteristic->setValue(response.c_str());
        pCharacteristic->notify();
      }
    }
};

// Функция для чтения температуры и влажности с DHT
String readDHTData() {
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  
  // Проверка на ошибки чтения
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("Ошибка чтения датчика DHT!");
    return "Ошибка DHT";
  }
  
  String data = "Темп: " + String(temperature, 1) + "°C, Влаж: " + String(humidity, 1) + "%";
  return data;
}

// Функция для чтения влажности почвы
String readSoilMoisture() {
  int sensorValue = analogRead(SOIL_MOISTURE_PIN);
  
  // Преобразование в проценты (может потребоваться калибровка)
  // Обычно: сухая почва ~4095, влажная ~1500 (зависит от датчика)
  int moisturePercent = map(sensorValue, 4095, 1500, 0, 100);
  moisturePercent = constrain(moisturePercent, 0, 100);
  
  String data = "Почва: " + String(moisturePercent) + "%";
  return data;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Запуск BLE сервера с датчиками...");

  // Инициализация датчика DHT
  dht.begin();
  
  // Настройка пина для датчика влажности почвы
  pinMode(SOIL_MOISTURE_PIN, INPUT);

  // Создание BLE устройства
  BLEDevice::init("ESP32_Sensor_Server");

  // Создание BLE сервера
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Создание BLE сервиса
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Создание BLE характеристики
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );

  // Установка callback для записи
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());

  // Начальные данные
  pCharacteristic->setValue("Датчики готовы");
  
  // Запуск сервиса
  pService->start();

  // Настройка advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // Функции для iPhone
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("Сервер запущен. Ожидание подключения...");
  Serial.println("Имя устройства: ESP32_Sensor_Server");
}

void loop() {
  // Обработка подключения/отключения
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
  
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // даем время для завершения подключения
    pServer->startAdvertising();
    Serial.println("Ожидание подключения...");
    oldDeviceConnected = deviceConnected;
  }
  
  // Отправка данных с датчиков каждые 5 секунд
  if (deviceConnected) {
    static unsigned long lastSendTime = 0;
    unsigned long currentTime = millis();
    
    if (currentTime - lastSendTime >= 5000) {
      // Чтение данных с датчиков
      String dhtData = readDHTData();
      String soilData = readSoilMoisture();
      
      // Формирование общего сообщения
      String message = dhtData + " | " + soilData;
      
      // Отправка по BLE
      pCharacteristic->setValue(message.c_str());
      pCharacteristic->notify();
      
      // Вывод в Serial для отладки
      Serial.println("Отправлено: " + message);
      
      lastSendTime = currentTime;
    }
  }
  
  delay(100);
}