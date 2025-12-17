#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <DHT.h>
#include <Preferences.h>

// Конфигурационные константы
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Пин конфигурация
#define DHT_PIN             22
#define DHT_TYPE            DHT22
#define LIGHT_SENSOR_PIN    25
#define SOIL_MOISTURE_PIN   34

// Константы для работы с памятью
#define MAX_DATA_POINTS     100
#define DATA_READ_INTERVAL  5000  // 5 секунд
#define SENSOR_ERROR_VALUE  -999.0f

// Классы для разделения ответственности
class SensorManager {
private:
    DHT dht;
    
    // Калибровочные значения для сенсоров
    static constexpr int SOIL_MIN_RAW = 4095;
    static constexpr int SOIL_MAX_RAW = 1500;
    static constexpr int LIGHT_MIN_RAW = 4095;
    static constexpr int LIGHT_MAX_RAW = 200;
    
public:
    SensorManager() : dht(DHT_PIN, DHT_TYPE) {}
    
    void begin() {
        dht.begin();
        pinMode(SOIL_MOISTURE_PIN, INPUT);
        pinMode(LIGHT_SENSOR_PIN, INPUT);
    }
    
    float readTemperature() {
        float temperature = dht.readTemperature();
        return isValidTemperature(temperature) ? temperature : SENSOR_ERROR_VALUE;
    }
    
    float readHumidity() {
        float humidity = dht.readHumidity();
        return isValidHumidity(humidity) ? humidity : SENSOR_ERROR_VALUE;
    }
    
    int readSoilMoisture() {
        int sensorValue = analogRead(SOIL_MOISTURE_PIN);
        int moisturePercent = map(sensorValue, SOIL_MIN_RAW, SOIL_MAX_RAW, 0, 100);
        return constrain(moisturePercent, 0, 100);
    }
    
    int readLightLevel() {
        int sensorValue = analogRead(LIGHT_SENSOR_PIN);
        int lightPercent = map(sensorValue, LIGHT_MIN_RAW, LIGHT_MAX_RAW, 0, 100);
        return constrain(lightPercent, 0, 100);
    }
    
    bool areReadingsValid(float temp, float hum, int soil, int light) {
        return temp != SENSOR_ERROR_VALUE && hum != SENSOR_ERROR_VALUE &&
               temp > 0 && temp <= 50 && 
               hum >= 0 && hum <= 100 && 
               soil >= 0 && soil <= 100 && 
               light >= 0 && light <= 100;
    }
    
    String formatReadings(float temp, float hum, int soil, int light) {
        return String(temp, 1) + ", " + String(hum, 1) + ", " + 
               String(soil) + ", " + String(light);
    }
    
    String formatForDisplay(float temp, float hum, int soil, int light) {
        return "Темп: " + String(temp, 1) + "°C, Влаж: " + 
               String(hum, 1) + "% | Почва: " + 
               String(soil) + "% | Свет: " + 
               String(light) + "%";
    }
    
private:
    bool isValidTemperature(float temp) {
        return !isnan(temp) && temp >= -40 && temp <= 80;
    }
    
    bool isValidHumidity(float hum) {
        return !isnan(hum) && hum >= 0 && hum <= 100;
    }
};

class DataStorage {
private:
    Preferences preferences;
    
public:
    struct SensorData {
        float temperature;
        float humidity;
        int soilMoisture;
        int lightLevel;
        unsigned long timestamp;
    };
    
    void begin() {
        preferences.begin("sensor_data", false);
    }
    
    void end() {
        preferences.end();
    }
    
    void saveData(const SensorData& data) {
        int index = preferences.getInt("data_index", 0);
        int count = preferences.getInt("data_count", 0);
        
        // Сохраняем данные
        String key = "data_" + String(index);
        String value = String(data.temperature, 1) + "," + 
                       String(data.humidity, 1) + "," + 
                       String(data.soilMoisture) + "," + 
                       String(data.lightLevel) + "," +
                       String(data.timestamp);
        
        preferences.putString(key.c_str(), value);
        
        // Обновляем индексы
        index = (index + 1) % MAX_DATA_POINTS;
        preferences.putInt("data_index", index);
        
        if (count < MAX_DATA_POINTS) {
            preferences.putInt("data_count", count + 1);
        }
        
        Serial.println("Сохранено: " + value);
    }
    
    String getAllStoredData() {
        int count = preferences.getInt("data_count", 0);
        int index = preferences.getInt("data_index", 0);
        
        if (count == 0) {
            return "";
        }
        
        String allData = "";
        int startIndex = (count == MAX_DATA_POINTS) ? index : 0;
        
        for (int i = 0; i < count; i++) {
            int currentIndex = (startIndex + i) % MAX_DATA_POINTS;
            String key = "data_" + String(currentIndex);
            String value = preferences.getString(key.c_str(), "");
            
            if (value.length() > 0) {
                if (allData.length() > 0) {
                    allData += "\n";
                }
                // Убираем timestamp для отправки
                int lastComma = value.lastIndexOf(',');
                allData += value.substring(0, lastComma);
            }
        }
        
        return allData;
    }
    
    void clearAllData() {
        preferences.clear();
        Serial.println("Все данные очищены из памяти");
    }
    
    int getStoredCount() {
        return preferences.getInt("data_count", 0);
    }
};

class BLESensorServer {
private:
    BLEServer* pServer;
    BLECharacteristic* pCharacteristic;
    bool deviceConnected;
    bool oldDeviceConnected;
    
public:
    BLESensorServer() : pServer(nullptr), pCharacteristic(nullptr), 
                        deviceConnected(false), oldDeviceConnected(false) {}
    
    void setup(const char* deviceName) {
        BLEDevice::init(deviceName);
        
        // Создание сервера
        pServer = BLEDevice::createServer();
        
        // Создание сервиса
        BLEService* pService = pServer->createService(SERVICE_UUID);
        
        // Создание характеристики
        pCharacteristic = pService->createCharacteristic(
            CHARACTERISTIC_UUID,
            BLECharacteristic::PROPERTY_READ |
            BLECharacteristic::PROPERTY_NOTIFY
        );
        
        pCharacteristic->setValue("ready");
        pService->start();
        
        // Настройка advertising
        setupAdvertising();
        
        Serial.println("BLE сервер запущен. Имя: " + String(deviceName));
    }
    
    void setCallbacks(BLEServerCallbacks* callbacks) {
        if (pServer && callbacks) {
            pServer->setCallbacks(callbacks);
        }
    }
    
    void sendData(const String& data) {
        if (deviceConnected && data.length() > 0) {
            pCharacteristic->setValue(data.c_str());
            pCharacteristic->notify();
        }
    }
    
    void updateConnectionStatus() {
        if (!deviceConnected && oldDeviceConnected) {
            delay(500); // Даем время для завершения отключения
            pServer->startAdvertising();
            oldDeviceConnected = deviceConnected;
        }
        
        if (deviceConnected && !oldDeviceConnected) {
            oldDeviceConnected = deviceConnected;
        }
    }
    
    void setConnected(bool connected) {
        deviceConnected = connected;
    }
    
    bool isConnected() const {
        return deviceConnected;
    }
    
private:
    void setupAdvertising() {
        BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
        pAdvertising->addServiceUUID(SERVICE_UUID);
        pAdvertising->setScanResponse(true);
        pAdvertising->setMinPreferred(0x06);
        pAdvertising->setMinPreferred(0x12);
        BLEDevice::startAdvertising();
    }
};

// Глобальные экземпляры
SensorManager sensorManager;
DataStorage dataStorage;
BLESensorServer bleServer;

// Callback класс
class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) override {
        bleServer.setConnected(true);
        Serial.println("Устройство подключено");
        
        // Получаем и отправляем все сохраненные данные
        String allData = dataStorage.getAllStoredData();
        if (allData.length() > 0) {
            Serial.println("Отправка " + String(dataStorage.getStoredCount()) + " записей...");
            bleServer.sendData(allData);
            
            // Очищаем после успешной отправки
            dataStorage.clearAllData();
        }
    }

    void onDisconnect(BLEServer* pServer) override {
        bleServer.setConnected(false);
        Serial.println("Устройство отключено");
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("Инициализация системы...");
    
    // Инициализация сенсоров
    sensorManager.begin();
    
    // Инициализация хранилища
    dataStorage.begin();
    Serial.println("Загружено " + String(dataStorage.getStoredCount()) + " записей");
    dataStorage.end();
    
    // Настройка BLE сервера
    bleServer.setup("ESP32_Sensor_Server");
    bleServer.setCallbacks(new ServerCallbacks());
    
    Serial.println("Система готова. Формат данных: температура, влажность, почва, свет");
}

void loop() {
    static unsigned long lastReadTime = 0;
    unsigned long currentTime = millis();
    
    // Обновление статуса соединения BLE
    bleServer.updateConnectionStatus();
    
    // Периодический сбор данных
    if (currentTime - lastReadTime >= DATA_READ_INTERVAL) {
        // Чтение данных с датчиков
        float temperature = sensorManager.readTemperature();
        float humidity = sensorManager.readHumidity();
        int soilMoisture = sensorManager.readSoilMoisture();
        int lightLevel = sensorManager.readLightLevel();
        
        // Проверка корректности данных
        if (sensorManager.areReadingsValid(temperature, humidity, soilMoisture, lightLevel)) {
            String displayMessage = sensorManager.formatForDisplay(
                temperature, humidity, soilMoisture, lightLevel);
            
            if (bleServer.isConnected()) {
                // Отправка по BLE
                bleServer.sendData(displayMessage);
                Serial.println("Отправлено (BLE): " + displayMessage);
            } else {
                // Сохранение в память
                DataStorage::SensorData data = {
                    temperature,
                    humidity,
                    soilMoisture,
                    lightLevel,
                    currentTime
                };
                
                dataStorage.begin();
                dataStorage.saveData(data);
                dataStorage.end();
            }
        } else {
            Serial.println("Ошибка чтения данных с датчиков");
        }
        
        lastReadTime = currentTime;
    }
    
    delay(100); // Небольшая задержка для стабильности
}