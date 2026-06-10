// =============================================================
//  AKILLI TAHTA v2.0
//  20x30 NeoMatrix + IR + WiFiManager + BLE + WebSocket + NTP
//  Orijinal IR ve playlist özellikleri KORUNDU
//  DATA=GPIO23, IR=GPIO22
// =============================================================

// ─── KÜTÜPHANELER ───────────────────────────────────────────
#include <Adafruit_GFX.h>
#include <Adafruit_NeoMatrix.h>
#include <Adafruit_NeoPixel.h>
#include <IRremote.hpp>
#include <Preferences.h>

// WiFi / Network
#include <WiFi.h>
#include <WiFiManager.h>          // tzapu/WiFiManager
#include <WebSocketsServer.h>     // Links2004/arduinoWebSockets
#include <WebServer.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>          // bblanchon/ArduinoJson

// BLE
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Zaman
#include <time.h>

// ─── PIN & MATRIX ────────────────────────────────────────────
#define LED_PIN   23
#define IR_PIN    22
#define MATRIX_W  30
#define MATRIX_H  20

Adafruit_NeoMatrix matrix(
  MATRIX_H, MATRIX_W, LED_PIN,
  NEO_MATRIX_BOTTOM + NEO_MATRIX_LEFT +
  NEO_MATRIX_COLUMNS + NEO_MATRIX_PROGRESSIVE,
  NEO_GRB + NEO_KHZ800
);

// ─── BLE UUID'leri ───────────────────────────────────────────
#define BLE_SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define BLE_CHAR_CMD_UUID       "12345678-1234-1234-1234-123456789ab0"  // Yazma (mobil→tahta)
#define BLE_CHAR_STATUS_UUID    "12345678-1234-1234-1234-123456789ab1"  // Okuma/Notify (tahta→mobil)

// ─── IR HEX (değiştirilmedi) ─────────────────────────────────
const uint32_t IR_CH_MINUS=0xBA45FF00, IR_CH=0xB946FF00, IR_CH_PLUS=0xB847FF00;
const uint32_t IR_PREV=0xBB44FF00,     IR_NEXT=0xBF40FF00, IR_PLAY=0xBC43FF00;
const uint32_t IR_VOL_MINUS=0xF807FF00,IR_VOL_PLUS=0xEA15FF00, IR_EQ=0xF609FF00;
const uint32_t IR_0=0xE916FF00,        IR_F_MINUS=0xE619FF00, IR_F_PLUS=0xF20DFF00;
const uint32_t IR_1=0xF30CFF00,        IR_2=0xE718FF00, IR_3=0xA15EFF00;
const uint32_t IR_4=0xF708FF00,        IR_5=0xE31CFF00, IR_6=0xA55AFF00;
const uint32_t IR_7=0xBD42FF00,        IR_8=0xAD52FF00, IR_9=0xB54AFF00;

// ─── METİN LİSTESİ (değiştirilmedi) ─────────────────────────
const char* TEXTS[] = {
  "TOPRAKSIZ MARKET ",
  "HIDROPONIK SET ",
  "TOPRAKSIZ TARIM ",
  "BESIN COZUMU ",
  "HOBI SETLERI ",
  "DIKEY KULE ",
  "BALKONDA URET ",
  "MUTFAKTA TUKET ",
  "SERA KURULUMU ",
  "YILIN 365 GUNU HASAT ",
  "MAKSIMUM VERIM MINIMUM ALAN ",
  "A VE B BESINLERI ",
  "TOHUM FIDE ",
  "%90 DAHA AZ SU TUKETIMI ",
};
const uint8_t TEXT_COUNT = sizeof(TEXTS)/sizeof(TEXTS[0]);

// ─── PREFERENCES ─────────────────────────────────────────────
Preferences prefs;

// ─── TWINKLE BUFFER ──────────────────────────────────────────
static uint8_t twR[MATRIX_H][MATRIX_W] = {0};
static uint8_t twG[MATRIX_H][MATRIX_W] = {0};
static uint8_t twB[MATRIX_H][MATRIX_W] = {0};

// ─── TEMEL DURUM DEĞİŞKENLERİ (orijinal) ────────────────────
uint8_t brightness   = 160;
bool    blackout     = false;
int     scrollSpeed  = 40;
int     directionLR  = -1;
uint8_t baseHue      = 0;

enum Orient : uint8_t { OR_H=0, OR_V_UP=1, OR_V_DOWN=2 };
Orient  orient       = OR_H;
uint8_t rotateSteps  = 0;

enum BgMode : uint8_t { BG_OFF=0, BG_SOLID=1, BG_RAINBOW=2, BG_TWINKLE=3 };
BgMode  bgMode       = BG_OFF;

int     textY        = 6;
uint8_t textSize     = 1;
uint8_t selectedIndex= 0;
uint8_t activeIndex  = 0;
String  activeText   = TEXTS[0];
int16_t textX=0, textW=0;
uint32_t lastStep    = 0;
uint16_t frameCounter= 0;
bool    playlistMode = false;

// ─── YENİ: EKSTRA EFEKTLER ───────────────────────────────────
enum ExtraEffect : uint8_t {
  EFX_NONE     = 0,
  EFX_MATRIX   = 1,   // Yeşil kod yağmuru
  EFX_FIRE     = 2,   // Ateş efekti
  EFX_WAVE     = 3,   // Renk dalgası
  EFX_CONFETTI = 4,   // Konfeti
  EFX_CLOCK    = 5,   // Saat gösterimi (NTP)
  EFX_WEATHER  = 6,   // Hava durumu kaydırma
  EFX_DRAWING  = 7,   // Mobil çizim modu
};
ExtraEffect extraEffect = EFX_NONE;

// ─── YENİ: WiFi / WEATHER / ZAMAN ────────────────────────────
bool     wifiConnected    = false;
bool     ntpSynced        = false;
String   weatherCity      = "Ankara";
String   weatherApiKey    = "";          // OpenWeatherMap API key
String   weatherInfo      = "";          // "23C Bulutlu"
uint32_t lastWeatherFetch = 0;
uint32_t lastClockUpdate  = 0;
bool     weatherEnabled   = false;
bool     clockEnabled     = false;

// ─── YENİ: ZAMANLAYICI ───────────────────────────────────────
bool     schedulerEnabled = false;
int      schedOnHour      = 8,  schedOnMin  = 0;
int      schedOffHour     = 22, schedOffMin = 0;
bool     schedTriggered   = false;

// ─── YENİ: DRAWING BUFFER ────────────────────────────────────
uint8_t drawBuf[MATRIX_H][MATRIX_W][3] = {0};   // R,G,B

// ─── YENİ: BLE ───────────────────────────────────────────────
BLEServer*         pBleServer   = nullptr;
BLECharacteristic* pCmdChar     = nullptr;
BLECharacteristic* pStatusChar  = nullptr;
bool               bleConnected = false;
String             bleCmdBuffer = "";
bool               bleNewCmd    = false;

// ─── YENİ: WebSocket ─────────────────────────────────────────
WebSocketsServer   wsServer(81);
WebServer          httpServer(80);

// ─────────────────────────────────────────────────────────────
// YARDIMCI FONKSİYONLAR (orijinalden değiştirilmedi)
// ─────────────────────────────────────────────────────────────
uint16_t wheel(uint8_t p){
  p = 255 - p;
  if(p < 85)  return matrix.Color(255-p*3, 0, p*3);
  if(p < 170){ p-=85; return matrix.Color(0, p*3, 255-p*3); }
  p-=170; return matrix.Color(p*3, 255-p*3, 0);
}
void wheelRGB(uint8_t p, uint8_t &r, uint8_t &g, uint8_t &b){
  p=255-p;
  if(p<85){ r=255-p*3; g=0; b=p*3; return; }
  if(p<170){ p-=85; r=0; g=p*3; b=255-p*3; return; }
  p-=170; r=p*3; g=255-p*3; b=0;
}
uint16_t textColorForColumn(int16_t col){
  if(bgMode==BG_RAINBOW) return wheel((baseHue+col*8+frameCounter)&0xFF);
  return wheel(baseHue);
}
static inline uint8_t rotFromOrient(uint8_t o){
  if(o==0) return 0; if(o==1) return 1; return 3;
}
static inline void applyRotation(){
  uint8_t finalRot=(rotateSteps+rotFromOrient((uint8_t)orient))&0x3;
  matrix.setRotation(finalRot);
}

// ─────────────────────────────────────────────────────────────
// ARKAPLAN (orijinalden değiştirilmedi)
// ─────────────────────────────────────────────────────────────
void drawBackground(){
  if(bgMode==BG_OFF) return;
  if(bgMode==BG_SOLID){
    uint16_t c=wheel(baseHue);
    uint8_t r=(c>>16)&0xFF, g=(c>>8)&0xFF, b=c&0xFF;
    r=(r*200)/255; g=(g*200)/255; b=(b*200)/255;
    matrix.fillRect(0,0,matrix.width(),matrix.height(), matrix.Color(r,g,b));
    return;
  }
  if(bgMode==BG_RAINBOW){
    for(int x=0;x<matrix.width();x++){
      uint16_t c16=wheel((baseHue+x*6+frameCounter)&0xFF);
      uint8_t r=(c16>>16)&0xFF, g=(c16>>8)&0xFF, b=c16&0xFF;
      for(int y=0;y<matrix.height();y++) matrix.drawPixel(x,y,matrix.Color(r,g,b));
    }
    return;
  }
  if(bgMode==BG_TWINKLE){
    for(int y=0;y<MATRIX_H;y++)
      for(int x=0;x<MATRIX_W;x++){
        twR[y][x]=(uint8_t)((twR[y][x]*220)/255);
        twG[y][x]=(uint8_t)((twG[y][x]*220)/255);
        twB[y][x]=(uint8_t)((twB[y][x]*220)/255);
      }
    int sparks=max(2,MATRIX_W/2);
    for(int i=0;i<sparks;i++){
      int x=random(MATRIX_W), y=random(MATRIX_H);
      uint8_t r,g,b; wheelRGB((baseHue+random(255))&0xFF,r,g,b);
      twR[y][x]=r; twG[y][x]=g; twB[y][x]=b;
    }
    for(int y=0;y<MATRIX_H;y++)
      for(int x=0;x<MATRIX_W;x++)
        matrix.drawPixel(x,y,matrix.Color(twR[y][x],twG[y][x],twB[y][x]));
    return;
  }
}

// ─────────────────────────────────────────────────────────────
// METİN HAZIRLA & KAYDIR (orijinalden değiştirilmedi)
// ─────────────────────────────────────────────────────────────
void prepareText(const String& s){
  applyRotation();
  matrix.setTextWrap(false);
  matrix.setTextSize(textSize);
  int16_t x1,y1; uint16_t w,h;
  matrix.getTextBounds(s,0,0,&x1,&y1,&w,&h);
  textW=w;
  if(orient==OR_H){ textX=(directionLR<0)?matrix.width():-textW; }
  else{ textX=(matrix.width()/2)-(textW/2); }
}

void drawMarquee(){
  applyRotation();
  matrix.fillScreen(0);
  drawBackground();
  matrix.setTextSize(textSize);
  matrix.setTextColor(textColorForColumn(textX));
  int yCursor=(orient==OR_H)?max(0,min(matrix.height()-7*textSize,textY)):0;
  matrix.setCursor(textX,yCursor);
  matrix.print(activeText);
  matrix.show();

  if(orient==OR_H){
    textX+=(directionLR<0?-1:+1);
    bool wrapped=false;
    if(directionLR<0){ if(textX<-textW){ textX=matrix.width(); wrapped=true; }}
    else{ if(textX>matrix.width()){ textX=-textW; wrapped=true; }}
    if(playlistMode && wrapped){
      activeIndex=(activeIndex+1)%TEXT_COUNT;
      activeText=String(TEXTS[activeIndex]);
      baseHue+=31;
      prepareText(activeText);
      savePrefs();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// YENİ EFEKTLER
// ─────────────────────────────────────────────────────────────

// --- Matrix Kod Yağmuru ---
static uint8_t matrixDropY[MATRIX_W]   = {0};
static uint8_t matrixDropLen[MATRIX_W] = {0};
static uint8_t matrixDropSpd[MATRIX_W] = {0};
void initMatrixEffect(){
  for(int x=0;x<MATRIX_W;x++){
    matrixDropY[x]   = random(MATRIX_H);
    matrixDropLen[x] = random(3,MATRIX_H/2);
    matrixDropSpd[x] = random(1,4);
  }
}
void drawMatrixEffect(){
  matrix.fillScreen(0);
  for(int x=0;x<MATRIX_W;x++){
    if((frameCounter % matrixDropSpd[x])==0) matrixDropY[x]=(matrixDropY[x]+1)%MATRIX_H;
    for(int i=0;i<matrixDropLen[x];i++){
      int y=(matrixDropY[x]-i+MATRIX_H)%MATRIX_H;
      uint8_t bright=255-((i*255)/matrixDropLen[x]);
      matrix.drawPixel(x,y,matrix.Color(0,bright,0));
    }
  }
  matrix.show();
}

// --- Ateş Efekti ---
static uint8_t fireGrid[MATRIX_H+2][MATRIX_W] = {0};
void drawFireEffect(){
  // Altta kor yaratma
  for(int x=0;x<MATRIX_W;x++)
    fireGrid[MATRIX_H+1][x]=random(160,255);
  // Yukarı yayma
  for(int y=0;y<MATRIX_H+1;y++)
    for(int x=0;x<MATRIX_W;x++){
      int sum = (int)fireGrid[y+1][x]
              + (int)fireGrid[y+1][(x-1+MATRIX_W)%MATRIX_W]
              + (int)fireGrid[y+1][(x+1)%MATRIX_W]
              + (int)fireGrid[y][(x)];
      fireGrid[y][x] = (uint8_t)max(0, sum/4 - random(0,8));
    }
  matrix.fillScreen(0);
  for(int y=0;y<MATRIX_H;y++)
    for(int x=0;x<MATRIX_W;x++){
      uint8_t v=fireGrid[y][x];
      uint8_t r=min(255,v*2);
      uint8_t g=(v>128)?(v-128)*2:0;
      matrix.drawPixel(x,(MATRIX_H-1)-y,matrix.Color(r,g,0));
    }
  matrix.show();
}

// --- Dalga Efekti ---
void drawWaveEffect(){
  matrix.fillScreen(0);
  for(int x=0;x<MATRIX_W;x++){
    float wave=sin((x+frameCounter)*0.4f)*((MATRIX_H/2)-2);
    int   cy  =(MATRIX_H/2)+(int)wave;
    for(int w2=-1;w2<=1;w2++){
      int y=cy+w2;
      if(y>=0 && y<MATRIX_H)
        matrix.drawPixel(x,y,wheel((baseHue+x*8+frameCounter)&0xFF));
    }
  }
  matrix.show();
}

// --- Konfeti ---
void drawConfettiEffect(){
  // Fade
  for(int y=0;y<MATRIX_H;y++)
    for(int x=0;x<MATRIX_W;x++){
      uint32_t c=matrix.getPixelColor(y*MATRIX_W+x);  // basitleştirilmiş
      (void)c; // fade yerine her frame birkaç piksel yenile
    }
  matrix.fillScreen(0);
  for(int i=0;i<8;i++){
    int x=random(MATRIX_W), y=random(MATRIX_H);
    matrix.drawPixel(x,y,wheel(random(256)));
  }
  matrix.show();
}

// --- Saat Gösterimi (NTP ile) ---
void drawClockEffect(){
  if(!ntpSynced){ drawMarquee(); return; }
  struct tm t;
  if(!getLocalTime(&t)){ drawMarquee(); return; }
  char buf[12];
  snprintf(buf,sizeof(buf),"%02d:%02d",t.tm_hour,t.tm_min);
  String timeStr = String(buf);
  applyRotation();
  matrix.fillScreen(0);
  drawBackground();
  matrix.setTextSize(1);
  matrix.setTextColor(wheel(baseHue+frameCounter));
  matrix.setCursor(0,6);
  matrix.print(timeStr);
  matrix.show();
}

// --- Hava Durumu Kaydırma ---
void drawWeatherEffect(){
  if(weatherInfo.length()==0){ drawMarquee(); return; }
  applyRotation();
  matrix.fillScreen(0);
  matrix.setTextSize(1);
  matrix.setTextColor(wheel(baseHue+frameCounter));
  matrix.setCursor(textX,6);
  matrix.print(weatherInfo);
  matrix.show();
  textX--;
  if(textX < -(int16_t)(weatherInfo.length()*6)) textX=MATRIX_W;
}

// --- Çizim Modu ---
void drawDrawingMode(){
  matrix.fillScreen(0);
  for(int y=0;y<MATRIX_H;y++)
    for(int x=0;x<MATRIX_W;x++)
      matrix.drawPixel(x,y,matrix.Color(drawBuf[y][x][0],drawBuf[y][x][1],drawBuf[y][x][2]));
  matrix.show();
}

// Tüm ekstra efekt çağrıcısı
void drawExtraEffect(){
  switch(extraEffect){
    case EFX_MATRIX:   drawMatrixEffect();   break;
    case EFX_FIRE:     drawFireEffect();     break;
    case EFX_WAVE:     drawWaveEffect();     break;
    case EFX_CONFETTI: drawConfettiEffect(); break;
    case EFX_CLOCK:    drawClockEffect();    break;
    case EFX_WEATHER:  drawWeatherEffect();  break;
    case EFX_DRAWING:  drawDrawingMode();    break;
    default: break;
  }
}

// ─────────────────────────────────────────────────────────────
// PREFERENCES (genişletildi)
// ─────────────────────────────────────────────────────────────
void savePrefs(){
  prefs.begin("marq",false);
  prefs.putUChar("activeIndex",activeIndex);
  prefs.putString("activeText",activeText);
  prefs.putUChar("brightness",brightness);
  prefs.putShort("speed",scrollSpeed);
  prefs.putChar("dirLR",directionLR);
  prefs.putUChar("hue",baseHue);
  prefs.putUChar("orient",(uint8_t)orient);
  prefs.putUChar("bgMode",(uint8_t)bgMode);
  prefs.putUChar("textSize",textSize);
  prefs.putChar("textY",textY);
  prefs.putUChar("rot",rotateSteps);
  prefs.putBool("playlist",playlistMode);
  // Yeni alanlar
  prefs.putUChar("extraFx",(uint8_t)extraEffect);
  prefs.putString("wxCity",weatherCity);
  prefs.putString("wxKey",weatherApiKey);
  prefs.putBool("wxEn",weatherEnabled);
  prefs.putBool("clkEn",clockEnabled);
  prefs.putBool("schedEn",schedulerEnabled);
  prefs.putInt("schedOnH",schedOnHour);
  prefs.putInt("schedOnM",schedOnMin);
  prefs.putInt("schedOffH",schedOffHour);
  prefs.putInt("schedOffM",schedOffMin);
  prefs.end();
}
void loadPrefs(){
  prefs.begin("marq",true);
  activeIndex  = prefs.getUChar("activeIndex",0);
  activeText   = prefs.getString("activeText",TEXTS[activeIndex]);
  brightness   = prefs.getUChar("brightness",160);
  scrollSpeed  = prefs.getShort("speed",40);
  directionLR  = prefs.getChar("dirLR",-1);
  baseHue      = prefs.getUChar("hue",0);
  orient       = (Orient)prefs.getUChar("orient",(uint8_t)OR_H);
  bgMode       = (BgMode)prefs.getUChar("bgMode",(uint8_t)BG_OFF);
  textSize     = prefs.getUChar("textSize",1);
  textY        = prefs.getChar("textY",6);
  rotateSteps  = prefs.getUChar("rot",0);
  playlistMode = prefs.getBool("playlist",false);
  extraEffect  = (ExtraEffect)prefs.getUChar("extraFx",(uint8_t)EFX_NONE);
  weatherCity  = prefs.getString("wxCity","Ankara");
  weatherApiKey= prefs.getString("wxKey","");
  weatherEnabled= prefs.getBool("wxEn",false);
  clockEnabled = prefs.getBool("clkEn",false);
  schedulerEnabled=prefs.getBool("schedEn",false);
  schedOnHour  = prefs.getInt("schedOnH",8);
  schedOnMin   = prefs.getInt("schedOnM",0);
  schedOffHour = prefs.getInt("schedOffH",22);
  schedOffMin  = prefs.getInt("schedOffM",0);
  prefs.end();
}

void activateSelected(bool save=true){
  activeText=String(TEXTS[activeIndex]);
  if(activeText.length()==0) activeText=" ";
  prepareText(activeText);
  if(save) savePrefs();
}

// ─────────────────────────────────────────────────────────────
// HAVA DURUMU (OpenWeatherMap)
// ─────────────────────────────────────────────────────────────
void fetchWeather(){
  if(!wifiConnected || weatherApiKey.length()==0) return;
  HTTPClient http;
  String url = "http://api.openweathermap.org/data/2.5/weather?q="
             + weatherCity + "&appid=" + weatherApiKey
             + "&units=metric&lang=tr";
  http.begin(url);
  int code = http.GET();
  if(code==200){
    String payload = http.getString();
    DynamicJsonDocument doc(1024);
    deserializeJson(doc, payload);
    float temp      = doc["main"]["temp"];
    const char* desc= doc["weather"][0]["description"];
    char buf[40];
    snprintf(buf,sizeof(buf),"%.0fC %s  ",temp,desc);
    weatherInfo = String(buf);
    weatherInfo.toUpperCase();
  }
  http.end();
}

// ─────────────────────────────────────────────────────────────
// ZAMANLAYICI
// ─────────────────────────────────────────────────────────────
void checkScheduler(){
  if(!schedulerEnabled || !ntpSynced) return;
  struct tm t; if(!getLocalTime(&t)) return;
  int nowM = t.tm_hour*60 + t.tm_min;
  int onM  = schedOnHour*60  + schedOnMin;
  int offM = schedOffHour*60 + schedOffMin;
  bool shouldBeOn = (onM <= offM) ? (nowM>=onM && nowM<offM) : (nowM>=onM || nowM<offM);
  if(shouldBeOn && blackout)  { blackout=false; }
  if(!shouldBeOn && !blackout){ blackout=true; matrix.fillScreen(0); matrix.show(); }
}

// ─────────────────────────────────────────────────────────────
// JSON KOMUT İŞLEYİCİ (BLE + WebSocket ortak)
// ─────────────────────────────────────────────────────────────
String buildStatusJson(){
  DynamicJsonDocument doc(512);
  doc["brightness"]   = brightness;
  doc["speed"]        = scrollSpeed;
  doc["blackout"]     = blackout;
  doc["bgMode"]       = (int)bgMode;
  doc["orient"]       = (int)orient;
  doc["hue"]          = baseHue;
  doc["textSize"]     = textSize;
  doc["playlist"]     = playlistMode;
  doc["activeIndex"]  = activeIndex;
  doc["extraEffect"]  = (int)extraEffect;
  doc["weather"]      = weatherInfo;
  doc["clockEnabled"] = clockEnabled;
  doc["wifiOk"]       = wifiConnected;
  doc["ip"]           = wifiConnected ? WiFi.localIP().toString() : "N/A";
  String out; serializeJson(doc, out);
  return out;
}

void processJsonCommand(const String& jsonStr){
  DynamicJsonDocument doc(512);
  if(deserializeJson(doc, jsonStr) != DeserializationError::Ok) return;

  // ── Temel kontroller ──
  if(doc.containsKey("brightness")){
    brightness = (uint8_t)constrain((int)doc["brightness"],0,255);
    matrix.setBrightness(brightness);
  }
  if(doc.containsKey("speed"))     scrollSpeed = constrain((int)doc["speed"],5,300);
  if(doc.containsKey("hue"))       baseHue     = (uint8_t)(int)doc["hue"];
  if(doc.containsKey("textSize")){
    textSize = (uint8_t)constrain((int)doc["textSize"],1,2);
    prepareText(activeText);
  }
  if(doc.containsKey("blackout")){
    blackout=(bool)doc["blackout"];
    if(blackout){ matrix.fillScreen(0); matrix.show(); }
  }
  if(doc.containsKey("bgMode")){
    bgMode=(BgMode)constrain((int)doc["bgMode"],0,3);
  }
  if(doc.containsKey("orient")){
    orient=(Orient)constrain((int)doc["orient"],0,2);
    prepareText(activeText);
  }
  if(doc.containsKey("dirLR")){
    directionLR=((int)doc["dirLR"]>=0)?+1:-1;
    prepareText(activeText);
  }
  if(doc.containsKey("playlist")) playlistMode=(bool)doc["playlist"];
  if(doc.containsKey("activeIndex")){
    activeIndex=(uint8_t)constrain((int)doc["activeIndex"],0,TEXT_COUNT-1);
    activateSelected(false);
  }
  // ── Özel metin ──
  if(doc.containsKey("customText")){
    String ct = doc["customText"].as<String>();
    if(ct.length()>0){ activeText=ct; prepareText(activeText); }
  }
  // ── Efekt ──
  if(doc.containsKey("extraEffect")){
    ExtraEffect newFx=(ExtraEffect)constrain((int)doc["extraEffect"],0,7);
    if(newFx==EFX_MATRIX) initMatrixEffect();
    extraEffect=newFx;
    textX=MATRIX_W; // hava durumu / saat için reset
  }
  // ── Hava durumu ──
  if(doc.containsKey("weatherCity"))   weatherCity=doc["weatherCity"].as<String>();
  if(doc.containsKey("weatherApiKey")) weatherApiKey=doc["weatherApiKey"].as<String>();
  if(doc.containsKey("weatherEnabled")){
    weatherEnabled=(bool)doc["weatherEnabled"];
    if(weatherEnabled) fetchWeather();
  }
  // ── Saat ──
  if(doc.containsKey("clockEnabled"))  clockEnabled=(bool)doc["clockEnabled"];
  // ── Zamanlayıcı ──
  if(doc.containsKey("schedEnable"))   schedulerEnabled=(bool)doc["schedEnable"];
  if(doc.containsKey("schedOnHour"))   schedOnHour =(int)doc["schedOnHour"];
  if(doc.containsKey("schedOnMin"))    schedOnMin  =(int)doc["schedOnMin"];
  if(doc.containsKey("schedOffHour"))  schedOffHour=(int)doc["schedOffHour"];
  if(doc.containsKey("schedOffMin"))   schedOffMin =(int)doc["schedOffMin"];
  // ── Çizim pikseli ──
  if(doc.containsKey("px")){
    int px=(int)doc["px"], py=(int)doc["py"];
    int pr=(int)doc["pr"], pg=(int)doc["pg"], pb=(int)doc["pb"];
    if(px>=0&&px<MATRIX_W&&py>=0&&py<MATRIX_H){
      drawBuf[py][px][0]=pr; drawBuf[py][px][1]=pg; drawBuf[py][px][2]=pb;
    }
  }
  // ── Çizim temizle ──
  if(doc.containsKey("clearDraw") && (bool)doc["clearDraw"])
    memset(drawBuf,0,sizeof(drawBuf));

  savePrefs();

  // Status geri gönder
  String status = buildStatusJson();
  if(bleConnected && pStatusChar){
    pStatusChar->setValue(status.c_str());
    pStatusChar->notify();
  }
  wsServer.broadcastTXT(status);
}

// ─────────────────────────────────────────────────────────────
// BLE CALLBACKS
// ─────────────────────────────────────────────────────────────
class BleServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* s)    override { bleConnected=true;  Serial.println("[BLE] Baglandi"); }
  void onDisconnect(BLEServer* s) override {
    bleConnected=false;
    Serial.println("[BLE] Ayrildi");
    BLEDevice::startAdvertising();
  }
};
class BleCmdCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    bleCmdBuffer = String(c->getValue().c_str());
    bleNewCmd    = true;
  }
};

void setupBLE(){
  BLEDevice::init("AkilliTahta");
  pBleServer = BLEDevice::createServer();
  pBleServer->setCallbacks(new BleServerCallbacks());
  BLEService* svc = pBleServer->createService(BLE_SERVICE_UUID);

  // Komut karakteristiği (mobil yazar)
  pCmdChar = svc->createCharacteristic(
    BLE_CHAR_CMD_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  pCmdChar->setCallbacks(new BleCmdCallbacks());

  // Durum karakteristiği (tahta bildirir)
  pStatusChar = svc->createCharacteristic(
    BLE_CHAR_STATUS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pStatusChar->addDescriptor(new BLE2902());

  svc->start();
  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(BLE_SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("[BLE] Reklam baslatildi: AkilliTahta");
}

// ─────────────────────────────────────────────────────────────
// WEB SUNUCU (HTML arayüz — yedek)
// ─────────────────────────────────────────────────────────────
void handleRoot(){
  String html = R"rawhtml(
<!DOCTYPE html><html><head><meta charset='utf-8'>
<title>Akilli Tahta</title>
<meta name='viewport' content='width=device-width,initial-scale=1'>
<style>
  body{font-family:sans-serif;background:#111;color:#eee;padding:16px}
  input,select,button{padding:8px;margin:4px;border-radius:6px;border:none;font-size:14px}
  button{background:#4CAF50;color:white;cursor:pointer}
  .row{margin:8px 0}
</style></head><body>
<h2>&#127988; Akilli Tahta Kontrol</h2>
<div class='row'>
  <b>Metin:</b><br>
  <input id='txt' type='text' placeholder='Yazinizi girin' style='width:80%'>
  <button onclick='send({customText:document.getElementById("txt").value})'>Gonder</button>
</div>
<div class='row'>
  <b>Parlaklik:</b>
  <input type='range' min='0' max='255' value='160' oninput='send({brightness:+this.value})'>
</div>
<div class='row'>
  <b>Hiz:</b>
  <input type='range' min='5' max='300' value='40' oninput='send({speed:+this.value})'>
</div>
<div class='row'>
  <b>Renk:</b>
  <input type='range' min='0' max='255' value='0' oninput='send({hue:+this.value})'>
</div>
<div class='row'>
  <b>Arkaplan:</b>
  <select onchange='send({bgMode:+this.value})'>
    <option value='0'>Yok</option><option value='1'>Solid</option>
    <option value='2'>Rainbow</option><option value='3'>Twinkle</option>
  </select>
</div>
<div class='row'>
  <b>Efekt:</b>
  <select onchange='send({extraEffect:+this.value})'>
    <option value='0'>Normal Kaydir</option>
    <option value='1'>Matrix</option><option value='2'>Ates</option>
    <option value='3'>Dalga</option><option value='4'>Konfeti</option>
    <option value='5'>Saat</option><option value='6'>Hava Durumu</option>
  </select>
</div>
<div class='row'>
  <button onclick='send({blackout:true})'>&#128274; Kapat</button>
  <button onclick='send({blackout:false})'>&#128275; Ac</button>
  <button onclick='send({playlist:true})'>&#9654; Playlist</button>
</div>
<div id='status' style='margin-top:12px;font-size:12px;color:#aaa'></div>
<script>
var ws=new WebSocket('ws://'+location.hostname+':81');
ws.onmessage=function(e){ document.getElementById('status').textContent=e.data; };
function send(obj){ ws.send(JSON.stringify(obj)); }
</script></body></html>
)rawhtml";
  httpServer.send(200,"text/html",html);
}

// ─────────────────────────────────────────────────────────────
// WEBSOCKET CALLBACK
// ─────────────────────────────────────────────────────────────
void onWsEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t len){
  if(type==WStype_TEXT){
    String msg = String((char*)payload);
    processJsonCommand(msg);
  }
  else if(type==WStype_CONNECTED){
    wsServer.sendTXT(num, buildStatusJson());
  }
}

// ─────────────────────────────────────────────────────────────
// IR (orijinalden değiştirilmedi + ufak ek)
// ─────────────────────────────────────────────────────────────
void handleIR(){
  if(!IrReceiver.decode()) return;
  if(IrReceiver.decodedIRData.flags & IRDATA_FLAGS_IS_REPEAT){ IrReceiver.resume(); return; }
  uint32_t code=IrReceiver.decodedIRData.decodedRawData;

  if(code==IR_PLAY){
    playlistMode=!playlistMode;
    if(playlistMode){ baseHue+=23; prepareText(activeText); }
    savePrefs();
  }
  else if(code==IR_CH){ if(!playlistMode){ activeIndex=selectedIndex; activateSelected(true); } }
  else if(code==IR_CH_MINUS){ selectedIndex=(selectedIndex+TEXT_COUNT-1)%TEXT_COUNT; if(!playlistMode){ activeIndex=selectedIndex; activateSelected(true); } }
  else if(code==IR_CH_PLUS) { selectedIndex=(selectedIndex+1)%TEXT_COUNT;            if(!playlistMode){ activeIndex=selectedIndex; activateSelected(true); } }
  else if(code==IR_PREV)     { scrollSpeed=min(300,scrollSpeed+5); savePrefs(); }
  else if(code==IR_NEXT)     { scrollSpeed=max(5,  scrollSpeed-5); savePrefs(); }
  else if(code==IR_VOL_MINUS){ brightness=(brightness<=10?0:brightness-10); matrix.setBrightness(brightness); savePrefs(); }
  else if(code==IR_VOL_PLUS) { brightness=(brightness>=245?255:brightness+10); matrix.setBrightness(brightness); savePrefs(); }
  else if(code==IR_EQ)       { blackout=!blackout; if(blackout){ matrix.fillScreen(0); matrix.show(); } }
  else if(code==IR_F_MINUS)  { baseHue-=12; savePrefs(); }
  else if(code==IR_F_PLUS)   { baseHue+=12; savePrefs(); }
  else if(code==IR_1)        { orient=(orient==OR_H?OR_V_DOWN:(Orient)(orient-1)); prepareText(activeText); savePrefs(); }
  else if(code==IR_3)        { orient=(Orient)((orient+1)%3); prepareText(activeText); savePrefs(); }
  else if(code==IR_7)        { bgMode=(bgMode==0?BG_TWINKLE:(BgMode)(bgMode-1)); savePrefs(); }
  else if(code==IR_9)        { bgMode=(BgMode)((bgMode+1)%4); savePrefs(); }
  else if(code==IR_4)        { directionLR=-1; if(orient==OR_H) prepareText(activeText); savePrefs(); }
  else if(code==IR_6)        { directionLR=+1; if(orient==OR_H) prepareText(activeText); savePrefs(); }
  else if(code==IR_2 && orient==OR_H){ textY=max(0,textY-1); savePrefs(); }
  else if(code==IR_8 && orient==OR_H){ textY=min(MATRIX_H-(int)(7*textSize),textY+1); savePrefs(); }
  else if(code==IR_5)        { textSize=(textSize==1?2:1); prepareText(activeText); savePrefs(); }
  else if(code==IR_0)        { rotateSteps=(rotateSteps+1)&0x3; prepareText(activeText); savePrefs(); }

  IrReceiver.resume();
}

// ─────────────────────────────────────────────────────────────
// SETUP
// ─────────────────────────────────────────────────────────────
void setup(){
  Serial.begin(115200);
  matrix.begin();
  matrix.setTextWrap(false);
  loadPrefs();
  if(brightness==0) brightness=120;
  blackout=false;
  matrix.setBrightness(brightness);
  IrReceiver.begin(IR_PIN, DISABLE_LED_FEEDBACK);
  if(activeIndex>=TEXT_COUNT) activeIndex=0;
  if(activeText.length()==0) activeText=TEXTS[activeIndex];
  prepareText(activeText);

  // Boot renk testi (orijinal)
  for(int i=0;i<3;i++){
    uint16_t c=(i==0)?matrix.Color(255,0,0):(i==1)?matrix.Color(0,255,0):matrix.Color(0,0,255);
    matrix.fillScreen(c); matrix.show(); delay(100);
  }
  matrix.fillScreen(0); matrix.show();

  // ── BLE başlat ──
  setupBLE();

  // ── WiFiManager (non-blocking captive portal) ──
  WiFiManager wm;
  wm.setConfigPortalTimeout(90);   // 90s bekle, sonra devam et
  wm.setConnectTimeout(15);

  // WiFiManager özel parametreler (OpenWeatherMap key & şehir)
  WiFiManagerParameter paramCity("city","Hava durumu sehri","Ankara",20);
  WiFiManagerParameter paramKey("apikey","OWM API Key","",36);
  wm.addParameter(&paramCity);
  wm.addParameter(&paramKey);

  // LED'e "WiFi kurulum modu" mesajı
  matrix.fillScreen(0);
  matrix.setTextSize(1); matrix.setTextColor(matrix.Color(0,180,255));
  matrix.setCursor(0,6); matrix.print("WIFI SETUP");
  matrix.show();

  if(wm.autoConnect("AkilliTahta-Setup","12345678")){
    wifiConnected=true;
    if(strlen(paramCity.getValue())>0) weatherCity  = String(paramCity.getValue());
    if(strlen(paramKey.getValue()) >0) weatherApiKey= String(paramKey.getValue());
    Serial.print("[WiFi] Baglandi: "); Serial.println(WiFi.localIP());

    // NTP
    configTime(3*3600, 0, "pool.ntp.org", "time.nist.gov");
    delay(1500);
    struct tm t;
    if(getLocalTime(&t,3000)) ntpSynced=true;

    // WebSocket & HTTP
    wsServer.begin();
    wsServer.onEvent(onWsEvent);
    httpServer.on("/", handleRoot);
    httpServer.begin();
    Serial.printf("[HTTP] http://%s\n", WiFi.localIP().toString().c_str());

    if(weatherEnabled) fetchWeather();
    savePrefs();
  } else {
    Serial.println("[WiFi] Baglanti yok, BLE modu ile devam");
    // WiFi olmasa bile BLE çalışıyor
  }
}

// ─────────────────────────────────────────────────────────────
// LOOP
// ─────────────────────────────────────────────────────────────
void loop(){
  handleIR();

  // BLE komut işle
  if(bleNewCmd){ processJsonCommand(bleCmdBuffer); bleNewCmd=false; }

  // WebSocket & HTTP
  if(wifiConnected){ wsServer.loop(); httpServer.handleClient(); }

  // Zamanlayıcı kontrol (30s'de bir)
  static uint32_t lastSched=0;
  if(millis()-lastSched>30000){ checkScheduler(); lastSched=millis(); }

  // Hava durumu 10 dakikada bir
  if(wifiConnected && weatherEnabled && millis()-lastWeatherFetch>600000){
    fetchWeather(); lastWeatherFetch=millis();
  }

  if(blackout) return;

  uint32_t now=millis();
  if(now-lastStep>=(uint32_t)scrollSpeed){
    lastStep=now;

    if(extraEffect != EFX_NONE)  drawExtraEffect();
    else                          drawMarquee();

    frameCounter++;
  }
}
