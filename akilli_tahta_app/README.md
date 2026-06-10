# 📟 Akıllı Tahta v2.0

20×30 NeoMatrix LED panel için ESP32 tabanlı akıllı kontrol sistemi.
IR uzaktan kumanda + Bluetooth + WiFi + Mobil Uygulama

---

## 📁 Proje Yapısı

```
akilli_tahta_v2.ino          ← ESP32 firmware (Arduino IDE)
akilli_tahta_app/            ← Flutter mobil uygulama
  lib/
    main.dart
    services/board_service.dart   ← BLE + WebSocket
    screens/
      home_screen.dart
      connect_screen.dart         ← BLE tarama + WiFi IP girişi
      control_screen.dart         ← Ana kontrol paneli
      effects_screen.dart         ← Efektler + hava durumu + zamanlayıcı
      draw_screen.dart            ← Parmakla çizim
      settings_screen.dart
  .github/workflows/build_apk.yml ← Otomatik APK derleme
```

---

## ⚡ ESP32 Kütüphaneleri (Arduino IDE → Library Manager)

| Kütüphane | Yazar |
|---|---|
| Adafruit NeoMatrix | Adafruit |
| Adafruit NeoPixel | Adafruit |
| IRremote | shirriff/z3t0 |
| WiFiManager | tzapu |
| arduinoWebSockets | Links2004 |
| ArduinoJson | bblanchon |
| ESP32 BLE Arduino | Neil Kolban (built-in) |

---

## 🔌 İlk Kurulum

### 1. ESP32'ye Firmware Yükle
1. Arduino IDE'de `akilli_tahta_v2.ino` aç
2. Board: **ESP32 Dev Module**
3. Kütüphaneleri yükle (yukarıdaki tablo)
4. Upload et

### 2. WiFi Ayarı (ilk açılışta)
1. Tahta açılışta `"AkilliTahta-Setup"` WiFi ağı yayınlar
2. Telefondan bu ağa bağlan
3. Açılan captive portal'da ev WiFi'ınızı seç ve şifre gir
4. Şehir adı + OpenWeatherMap API key gir (isteğe bağlı)
5. Kaydet → Tahta kendi WiFi'ına bağlanır

> **Not:** WiFi yoksa tahta sadece BLE modunda çalışmaya devam eder.

### 3. OpenWeatherMap API Key (Ücretsiz)
1. https://openweathermap.org adresine kayıt ol
2. API Keys → Generate key
3. Uygulamadan veya WiFiManager'dan gir

---

## 📱 Mobil Uygulama Kurulumu

### Android APK (GitHub Actions)
1. Repoyu GitHub'a push et
2. Actions sekmesinden `Build APK` workflow'u çalıştır
3. Artifacts bölümünden APK'yı indir
4. Telefona kur (bilinmeyen kaynaklara izin ver)

### Geliştirme Ortamı
```bash
flutter pub get
flutter run
```

---

## 🎮 BLE Bağlantısı

1. Uygulamayı aç
2. **"Bağlantı Kur"** butonuna bas
3. **Bluetooth** sekmesinde **"Tara"**ya bas
4. **"AkilliTahta"** cihazına dokun
5. Bağlandıktan sonra tüm özellikler aktif olur

---

## 📡 WiFi / WebSocket Bağlantısı

1. ESP32'nin IP adresini öğren (Serial Monitor veya router)
2. Uygulamada **WiFi** sekmesinden IP'yi gir
3. **"Bağlan"**a bas

Ayrıca tarayıcıdan `http://<IP_ADRESI>` ile web arayüzüne erişebilirsiniz.

---

## 🎨 Özellikler

| Özellik | IR | BLE | WiFi |
|---|:---:|:---:|:---:|
| Kaydırma metni | ✅ | ✅ | ✅ |
| Özel metin | - | ✅ | ✅ |
| Parlaklık | ✅ | ✅ | ✅ |
| Hız | ✅ | ✅ | ✅ |
| Renk | ✅ | ✅ | ✅ |
| Arkaplan efekti | ✅ | ✅ | ✅ |
| Playlist modu | ✅ | ✅ | ✅ |
| Matrix yağmuru | - | ✅ | ✅ |
| Ateş efekti | - | ✅ | ✅ |
| Dalga efekti | - | ✅ | ✅ |
| Saat gösterimi | - | ✅ | ✅ |
| Hava durumu | - | ✅ | ✅ |
| Parmakla çizim | - | ✅ | ✅ |
| Zamanlayıcı | - | ✅ | ✅ |
| Açma/kapama | ✅ | ✅ | ✅ |

---

## 🔧 JSON Komut Referansı

```json
{ "brightness": 160 }          // 0-255
{ "speed": 40 }                 // ms/frame (küçük=hızlı)
{ "hue": 128 }                  // 0-255 renk tonu
{ "bgMode": 2 }                 // 0=Kapalı 1=Solid 2=Rainbow 3=Twinkle
{ "orient": 0 }                 // 0=Yatay 1=DikeY↑ 2=Dikey↓
{ "extraEffect": 1 }            // 0-7 efekt seçimi
{ "blackout": true }            // Ekranı kapat/aç
{ "customText": "MERHABA" }     // Özel metin
{ "activeIndex": 3 }            // Hazır metin index
{ "playlist": true }            // Playlist modu
{ "weatherEnabled": true }      // Hava durumu
{ "weatherCity": "Istanbul" }   // Şehir
{ "weatherApiKey": "xxx" }      // OWM API key
{ "clockEnabled": true }        // Saat modu
{ "schedEnable": true }         // Zamanlayıcı
{ "schedOnHour": 8 }            // Açılış saati
{ "schedOffHour": 22 }          // Kapanış saati
{ "px":5,"py":3,"pr":255,"pg":0,"pb":0 }  // Çizim pikseli
{ "clearDraw": true }           // Çizimi temizle
```

---

## 📋 Sonraki Adımlar (iOS)

iOS için XCode + Apple Developer hesabı gerekir.
Flutter kodu değişmeden iOS'ta da çalışır:
```bash
flutter build ios --release
```
TestFlight üzerinden dağıtım yapılabilir.
