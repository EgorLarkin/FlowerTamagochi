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
#define DHT_TYPE            DHT11
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
    
    // Динамические калибровочные значения для сенсоров
    int SOIL_DRY_VALUE = 3900;   // Сухая почва (воздух) - будет обновляться
    int SOIL_WET_VALUE = 1500;   // Влажная почва (вода) - будет обновляться
    
    static constexpr int LIGHT_MIN_RAW = 4095;    // Темнота
    static constexpr int LIGHT_MAX_RAW = 0;     // Яркий свет
    
    // Для усреднения показаний
    static constexpr int SOIL_AVERAGE_COUNT = 10;
    int soilReadings[SOIL_AVERAGE_COUNT];
    int soilIndex = 0;
    
    // Для динамической калибровки
    int soilMinValue = 4096;  // Минимальное зарегистрированное значение
    int soilMaxValue = 0;     // Максимальное зарегистрированное значение
    unsigned long lastCalibrationTime = 0;
    const unsigned long CALIBRATION_INTERVAL = 60000; // Калибровка каждые 60 секунд
    
public:
    SensorManager() : dht(DHT_PIN, DHT_TYPE) {
        // Инициализация массива для усреднения
        for (int i = 0; i < SOIL_AVERAGE_COUNT; i++) {
            soilReadings[i] = 0;
        }
    }
    
    void begin() {
        dht.begin();
        pinMode(SOIL_MOISTURE_PIN, INPUT);
        pinMode(LIGHT_SENSOR_PIN, INPUT);
        
        // Настройка АЦП для более точных измерений
        analogReadResolution(12);  // 12 бит (0-4095)
        analogSetAttenuation(ADC_11db);  // Диапазон 0-3.3V
        
        // Загрузка сохранённых калибровочных значений
        loadCalibration();
    }
    
    void testLightSensor() {
        Serial.println("\n=== ТЕСТ ДАТЧИКА СВЕТА ===");
        Serial.println("Проверка работы датчика света...");
        
        for (int i = 0; i < 10; i++) {
            int rawValue = analogRead(LIGHT_SENSOR_PIN);
            Serial.print("Тест ");
            Serial.print(i + 1);
            Serial.print(": RAW=");
            Serial.print(rawValue);
            Serial.print(", расчитано=");
            Serial.print(readLightLevel());
            Serial.println("%");
            delay(500);
        }
        
        // Проверка с подтяжкой
        Serial.println("\nПроверка с внутренней подтяжкой...");
        pinMode(LIGHT_SENSOR_PIN, INPUT_PULLUP);
        for (int i = 0; i < 5; i++) {
            int rawValue = analogRead(LIGHT_SENSOR_PIN);
            Serial.print("С подтяжкой ");
            Serial.print(i + 1);
            Serial.print(": ");
            Serial.println(rawValue);
            delay(500);
        }
        pinMode(LIGHT_SENSOR_PIN, INPUT);  // Вернуть обычный режим
    }

    void loadCalibration() {
        Preferences prefs;
        prefs.begin("soil_calib", true);  // Режим чтения
        
        SOIL_DRY_VALUE = prefs.getInt("dry", 3900);
        SOIL_WET_VALUE = prefs.getInt("wet", 1500);
        soilMinValue = prefs.getInt("min", 4096);
        soilMaxValue = prefs.getInt("max", 0);
        
        prefs.end();
        
        Serial.print("Загружены калибровочные значения: сухо=");
        Serial.print(SOIL_DRY_VALUE);
        Serial.print(", влажно=");
        Serial.print(SOIL_WET_VALUE);
        Serial.print(", min=");
        Serial.print(soilMinValue);
        Serial.print(", max=");
        Serial.println(soilMaxValue);
    }
    
    void saveCalibration() {
        Preferences prefs;
        prefs.begin("soil_calib", false);  // Режим записи
        
        prefs.putInt("dry", SOIL_DRY_VALUE);
        prefs.putInt("wet", SOIL_WET_VALUE);
        prefs.putInt("min", soilMinValue);
        prefs.putInt("max", soilMaxValue);
        
        prefs.end();
        
        Serial.println("Калибровочные значения сохранены");
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
        // Читаем несколько раз и усредняем
        int sensorValue = 0;
        for (int i = 0; i < 10; i++) {
            sensorValue += analogRead(SOIL_MOISTURE_PIN);
            delay(1);
        }
        sensorValue = sensorValue / 10;
        
        // Обновляем динамические min/max значения
        updateDynamicCalibration(sensorValue);
        
        // Сохраняем в массив для скользящего среднего
        soilReadings[soilIndex] = sensorValue;
        soilIndex = (soilIndex + 1) % SOIL_AVERAGE_COUNT;
        
        // Вычисляем среднее
        int avgValue = 0;
        for (int i = 0; i < SOIL_AVERAGE_COUNT; i++) {
            avgValue += soilReadings[i];
        }
        avgValue = avgValue / SOIL_AVERAGE_COUNT;
        
        // Отладочная информация
        Serial.print("Сырое значение датчика почвы: ");
        Serial.print(sensorValue);
        Serial.print(" (среднее: ");
        Serial.print(avgValue);
        Serial.print(", min=");
        Serial.print(soilMinValue);
        Serial.print(", max=");
        Serial.print(soilMaxValue);
        Serial.print(")");
        
        // Используем динамические значения для калибровки, если они есть
        int calibrationDry = SOIL_DRY_VALUE;
        int calibrationWet = SOIL_WET_VALUE;
        
        // Если у нас есть реальные min/max значения, используем их
        if (soilMaxValue - soilMinValue > 500) {  // Достаточный диапазон
            calibrationDry = soilMaxValue;
            calibrationWet = soilMinValue;
        }
        
        int moisturePercent;
        if (calibrationWet < calibrationDry) {
            // Нормальная калибровка (влажная почва = меньшее значение)
            moisturePercent = map(avgValue, calibrationWet, calibrationDry, 100, 0);
        } else {
            // Инвертированная калибровка (влажная почва = большее значение)
            moisturePercent = map(avgValue, calibrationDry, calibrationWet, 0, 100);
        }
        
        // Дополнительная проверка и ограничение
        moisturePercent = constrain(moisturePercent, 0, 100);
        
        Serial.print(" -> Калиброванное: ");
        Serial.print(moisturePercent);
        Serial.println("%");
        
        return moisturePercent;
    }
    
    void updateDynamicCalibration(int rawValue) {
        // Обновляем min/max значения
        if (rawValue < soilMinValue) {
            soilMinValue = rawValue;
        }
        if (rawValue > soilMaxValue) {
            soilMaxValue = rawValue;
        }
        
        // Периодическое сохранение калибровочных значений
        unsigned long currentTime = millis();
        if (currentTime - lastCalibrationTime > CALIBRATION_INTERVAL) {
            // Устанавливаем калибровочные значения на основе реальных измерений
            // с небольшим запасом
            SOIL_WET_VALUE = soilMinValue - 100;  // Добавляем запас
            SOIL_DRY_VALUE = soilMaxValue + 100;  // Добавляем запас
            
            // Защита от выхода за пределы
            SOIL_WET_VALUE = constrain(SOIL_WET_VALUE, 0, 4095);
            SOIL_DRY_VALUE = constrain(SOIL_DRY_VALUE, 0, 4095);
            
            // Сохраняем в память
            saveCalibration();
            
            lastCalibrationTime = currentTime;
            
            Serial.println("Динамическая калибровка обновлена");
        }
    }
    
    int readLightLevel() {
        // Читаем несколько раз для усреднения
        int sensorValue = 0;
        for (int i = 0; i < 5; i++) {
            sensorValue += analogRead(LIGHT_SENSOR_PIN);
            delay(2);
        }
        sensorValue = sensorValue / 5;
        
        // Отладочная информация
        Serial.print("Свет: raw=");
        Serial.print(sensorValue);
        
        // Проверяем, есть ли сигнал вообще
        if (sensorValue == 0) {
            Serial.println(" - ВНИМАНИЕ: Датчик возвращает 0!");
            Serial.println("  Проверьте подключение датчика света к пину 25");
            Serial.println("  Возможно, датчик не подключен или сгорел");
        } else if (sensorValue == 4095) {
            Serial.println(" - ВНИМАНИЕ: Датчик возвращает 4095!");
            Serial.println("  Возможно, датчик закорочен или подключен неправильно");
        }
        
        int lightPercent = map(sensorValue, LIGHT_MIN_RAW, LIGHT_MAX_RAW, 0, 100);
        lightPercent = constrain(lightPercent, 0, 100);
        
        Serial.print(" -> ");
        Serial.print(lightPercent);
        Serial.println("%");
        
        return lightPercent;
    }
    
    // Функция для ручной калибровки датчика почвы
    void calibrateSoilSensor() {
        Serial.println("\n=== КАЛИБРОВКА ДАТЧИКА ВЛАЖНОСТИ ПОЧВЫ ===");
        Serial.println("1. Поместите датчик в СУХУЮ почву или воздух");
        Serial.println("   и нажмите любую клавишу...");
        while (!Serial.available());
        Serial.read();
        delay(100);
        
        int dryValue = 0;
        for (int i = 0; i < 30; i++) {
            dryValue += analogRead(SOIL_MOISTURE_PIN);
            Serial.print(".");
            delay(100);
        }
        dryValue = dryValue / 30;
        Serial.println();
        Serial.print("   Среднее значение в сухой среде: ");
        Serial.println(dryValue);
        
        Serial.println("\n2. Поместите датчик в ВОДУ или ОЧЕНЬ ВЛАЖНУЮ почву");
        Serial.println("   и нажмите любую клавишу...");
        while (!Serial.available());
        Serial.read();
        delay(100);
        
        int wetValue = 0;
        for (int i = 0; i < 30; i++) {
            wetValue += analogRead(SOIL_MOISTURE_PIN);
            Serial.print(".");
            delay(100);
        }
        wetValue = wetValue / 30;
        Serial.println();
        Serial.print("   Среднее значение в воде: ");
        Serial.println(wetValue);
        
        Serial.println("\n=== РЕЗУЛЬТАТЫ КАЛИБРОВКИ ===");
        Serial.print("Сырое сухое значение: ");
        Serial.println(dryValue);
        Serial.print("Сырое влажное значение: ");
        Serial.println(wetValue);
        
        // Определяем тип датчика и устанавливаем значения
        if (wetValue < dryValue) {
            Serial.println("Тип датчика: НОРМАЛЬНЫЙ (вода = меньшее значение)");
            SOIL_DRY_VALUE = dryValue;
            SOIL_WET_VALUE = wetValue;
        } else {
            Serial.println("Тип датчика: ИНВЕРТИРОВАННЫЙ (вода = большее значение)");
            SOIL_DRY_VALUE = wetValue;
            SOIL_WET_VALUE = dryValue;
        }
        
        // Сбрасываем динамические значения
        soilMinValue = SOIL_WET_VALUE;
        soilMaxValue = SOIL_DRY_VALUE;
        
        // Сохраняем калибровочные значения
        saveCalibration();
        
        Serial.println("=== КАЛИБРОВКА ЗАВЕРШЕНА ===");
        Serial.print("SOIL_DRY_VALUE = ");
        Serial.println(SOIL_DRY_VALUE);
        Serial.print("SOIL_WET_VALUE = ");
        Serial.println(SOIL_WET_VALUE);
        
        // Тестовое чтение после калибровки
        Serial.println("\nТестовое чтение после калибровки:");
        for (int i = 0; i < 5; i++) {
            int testValue = readSoilMoisture();
            Serial.print("Тест ");
            Serial.print(i + 1);
            Serial.print(": ");
            Serial.print(testValue);
            Serial.println("%");
            delay(1000);
        }
    }
    
    // Тестовая функция для проверки сырых значений
    void testRawValues() {
        Serial.println("\n=== ТЕСТ СЫРЫХ ЗНАЧЕНИЙ ===");
        Serial.println("Измеряем сырые значения без калибровки:");
        
        for (int i = 0; i < 10; i++) {
            int rawValue = analogRead(SOIL_MOISTURE_PIN);
            Serial.print("Измерение ");
            Serial.print(i + 1);
            Serial.print(": ");
            Serial.println(rawValue);
            delay(500);
        }
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
        
        String key = "data_" + String(index);
        String value = String(data.temperature, 1) + "," + 
                       String(data.humidity, 1) + "," + 
                       String(data.soilMoisture) + "," + 
                       String(data.lightLevel) + "," +
                       String(data.timestamp);
        
        preferences.putString(key.c_str(), value);
        
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
        
        if (count == 0) return "";
        
        String allData = "";
        int startIndex = (count == MAX_DATA_POINTS) ? index : 0;
        
        for (int i = 0; i < count; i++) {
            int currentIndex = (startIndex + i) % MAX_DATA_POINTS;
            String key = "data_" + String(currentIndex);
            String value = preferences.getString(key.c_str(), "");
            
            if (value.length() > 0) {
                if (allData.length() > 0) allData += "\n";
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
        pServer = BLEDevice::createServer();
        BLEService* pService = pServer->createService(SERVICE_UUID);
        
        pCharacteristic = pService->createCharacteristic(
            CHARACTERISTIC_UUID,
            BLECharacteristic::PROPERTY_READ |
            BLECharacteristic::PROPERTY_NOTIFY
        );
        
        pCharacteristic->setValue("ready");
        pService->start();
        
        BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
        pAdvertising->addServiceUUID(SERVICE_UUID);
        pAdvertising->setScanResponse(true);
        pAdvertising->setMinPreferred(0x06);
        pAdvertising->setMinPreferred(0x12);
        BLEDevice::startAdvertising();
        
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
            delay(500);
            BLEDevice::startAdvertising();
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
};

// Глобальные экземпляры
SensorManager sensorManager;
DataStorage dataStorage;
BLESensorServer bleServer;

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        bleServer.setConnected(true);
        Serial.println("Устройство подключено");
        
        // Отправляем все сохранённые данные при подключении
        dataStorage.begin();
        String allData = dataStorage.getAllStoredData();
        if (allData.length() > 0) {
            Serial.println("Отправка " + String(dataStorage.getStoredCount()) + " записей...");
            bleServer.sendData(allData);
            dataStorage.clearAllData();
        }
        dataStorage.end();
    }

    void onDisconnect(BLEServer* pServer) {
        bleServer.setConnected(false);
        Serial.println("Устройство отключено");
    }
};

void printHelp() {
    Serial.println("\n=== КОМАНДЫ МОНИТОРА ПОРТА ===");
    Serial.println("c - Калибровка датчика влажности почвы");
    Serial.println("t - Тест сырых значений датчика почвы");
    Serial.println("r - Сброс динамической калибровки");
    Serial.println("h - Вывод этого сообщения");
    Serial.println("s - Статус системы");
    Serial.println("============================\n");
}

void setup() {
    Serial.begin(115200);
    Serial.println("\n=== ИНИЦИАЛИЗАЦИЯ СИСТЕМЫ ДАТЧИКОВ ESP32 ===");
    
    // Запуск сенсоров
    sensorManager.begin();
    
    // Инициализация хранилища данных
    dataStorage.begin();
    Serial.println("Загружено " + String(dataStorage.getStoredCount()) + " записей");
    dataStorage.end();
    
    // Настройка BLE
    bleServer.setup("ESP32_Sensor_Server_2");
    bleServer.setCallbacks(new ServerCallbacks());
    
    // Вывод справки по командам
    printHelp();
    
    // Автоматическая проверка датчика почвы при запуске
    Serial.println("Автоматическая проверка датчика почвы...");
    sensorManager.testRawValues();
    
    Serial.println("\nСистема готова.");
    Serial.println("Формат данных: температура, влажность, почва, свет");
    Serial.println("============================================\n");
}

void loop() {
    static unsigned long lastReadTime = 0;
    static unsigned long lastStatusTime = 0;
    unsigned long currentTime = millis();
    
    // Обработка команд из монитора порта
    if (Serial.available()) {
        char cmd = Serial.read();
        switch (cmd) {
            case 'c':
            case 'C':
                sensorManager.calibrateSoilSensor();
                break;
                
            case 't':
            case 'T':
                sensorManager.testRawValues();
                break;
                
            case 'r':
            case 'R':
                Serial.println("Сброс динамической калибровки...");
                // Сброс значений
                sensorManager.loadCalibration();
                break;
                
            case 'h':
            case 'H':
                printHelp();
                break;
                
            case 's':
            case 'S':
                Serial.println("\n=== СТАТУС СИСТЕМЫ ===");
                Serial.println("BLE подключен: " + String(bleServer.isConnected() ? "Да" : "Нет"));
                dataStorage.begin();
                Serial.println("Сохранено записей: " + String(dataStorage.getStoredCount()));
                dataStorage.end();
                Serial.println("Время работы: " + String(currentTime / 1000) + " сек");
                Serial.println("======================\n");
                break;
            
            case 'l':
            case 'L':
                Serial.println("\nЗапуск теста датчика света...");
                sensorManager.testLightSensor();
                break;
        }
    }
    
    // Обновление статуса соединения BLE
    bleServer.updateConnectionStatus();
    
    // Основной цикл считывания данных с сенсоров
    if (currentTime - lastReadTime >= DATA_READ_INTERVAL) {
        float temperature = sensorManager.readTemperature();
        float humidity = sensorManager.readHumidity();
        int soilMoisture = sensorManager.readSoilMoisture();
        int lightLevel = sensorManager.readLightLevel();
        
        if (sensorManager.areReadingsValid(temperature, humidity, soilMoisture, lightLevel)) {
            String displayMessage = sensorManager.formatForDisplay(
                temperature, humidity, soilMoisture, lightLevel);
            
            // Отправка данных через BLE или сохранение в память
            if (bleServer.isConnected()) {
                bleServer.sendData(displayMessage);
                Serial.println("Отправлено (BLE): " + displayMessage);
            } else {
                // Сохраняем в память для последующей отправки
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
                
                Serial.println("Сохранено (локально): " + displayMessage);
            }
        } else {
            Serial.println("Ошибка чтения данных с датчиков");
            
            // Детальная диагностика
            Serial.print("Проверка значений: ");
            Serial.print("Темп=");
            Serial.print(temperature);
            Serial.print(", Влаж=");
            Serial.print(humidity);
            Serial.print(", Почва=");
            Serial.print(soilMoisture);
            Serial.print(", Свет=");
            Serial.println(lightLevel);
        }
        
        lastReadTime = currentTime;
    }
    
    // Периодический вывод статуса
    if (currentTime - lastStatusTime > 30000) {  // Каждые 30 секунд
        Serial.print(".");
        lastStatusTime = currentTime;
    }
    
    delay(100);
}
