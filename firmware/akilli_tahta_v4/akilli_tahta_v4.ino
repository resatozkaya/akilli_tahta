// =============================================================
//  AKILLI TAHTA v4.0 - TABELA MODU
//  BLE kontrolü + IR kumanda
//  Özellikler:
//  - Kayan yazı (renk, hız, yön)
//  - Renkli animasyonlu çerçeve
//  - 8 arkaplan efekti
//  - 6 yazı animasyonu
//  - Playlist modu
//  - NeoMatrix 20x30
// =============================================================
#include <Adafruit_GFX.h>
#include <Adafruit_NeoMatrix.h>
#include <Adafruit_NeoPixel.h>
#include <IRremote.hpp>
#include <Preferences.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define LED_PIN  23
#define IR_PIN   22
#define MW       30   // Matrix genişlik
#define MH       20   // Matrix yükseklik

Adafruit_NeoMatrix matrix(
  MH, MW, LED_PIN,
  NEO_MATRIX_BOTTOM + NEO_MATRIX_LEFT +
  NEO_MATRIX_COLUMNS + NEO_MATRIX_PROGRESSIVE,
  NEO_GRB + NEO_KHZ800
);

// ─── BLE ─────────────────────────────────────────────────────
#define SVC_UUID  "12345678-1234-1234-1234-123456789abc"
#define CMD_UUID  "12345678-1234-1234-1234-123456789ab0"
#define STS_UUID  "12345678-1234-1234-1234-123456789ab1"

BLEServer*         bleServer  = nullptr;
BLECharacteristic* cmdChar    = nullptr;
BLECharacteristic* stsChar    = nullptr;
bool               bleCon     = false;
String             bleCmd     = "";
bool               bleNew     = false;

// ─── IR ──────────────────────────────────────────────────────
const uint32_t IR_CH_M=0xBA45FF00,IR_CH=0xB946FF00,IR_CH_P=0xB847FF00;
const uint32_t IR_PRV=0xBB44FF00,IR_NXT=0xBF40FF00,IR_PLY=0xBC43FF00;
const uint32_t IR_VM =0xF807FF00,IR_VP=0xEA15FF00,IR_EQ=0xF609FF00;
const uint32_t IR_0=0xE916FF00,IR_FM=0xE619FF00,IR_FP=0xF20DFF00;
const uint32_t IR_1=0xF30CFF00,IR_2=0xE718FF00,IR_3=0xA15EFF00;
const uint32_t IR_4=0xF708FF00,IR_5=0xE31CFF00,IR_6=0xA55AFF00;
const uint32_t IR_7=0xBD42FF00,IR_8=0xAD52FF00,IR_9=0xB54AFF00;

// ─── METİN LİSTESİ ───────────────────────────────────────────
#define MAX_CUSTOM 8
String customTexts[MAX_CUSTOM] = {
  "TOPRAKSIZ MARKET ",
  "HIDROPONIK SET ",
  "TOPRAKSIZ TARIM ",
  "BESIN COZUMU ",
  "HOBI SETLERI ",
  "DIKEY KULE ",
  "BALKONDA URET ",
  "MUTFAKTA TUKET "
};
uint8_t textCount = 8;

// ─── ENUM'LAR ────────────────────────────────────────────────
enum TextAnim : uint8_t {
  TA_SCROLL = 0,   // Normal kayan
  TA_BLINK  = 1,   // Yanıp sönen
  TA_WAVE   = 2,   // Dalga renk
  TA_RAINBOW= 3,   // Gökkuşağı
  TA_GLOW   = 4,   // Parlaklık nabzı
  TA_TYPING = 5,   // Yazılıyor efekti
};

enum BorderAnim : uint8_t {
  BA_NONE    = 0,  // Çerçeve yok
  BA_SOLID   = 1,  // Tek renk
  BA_CHASE   = 2,  // Dönen nokta
  BA_RAINBOW = 3,  // Gökkuşağı dönen
  BA_PULSE   = 4,  // Nabız
  BA_SNAKE   = 5,  // Yılan
  BA_SPARKLE = 6,  // Kıvılcım
  BA_GRADIENT= 7,  // Gradyan
};

enum BgFill : uint8_t {
  BG_OFF     = 0,
  BG_SOLID   = 1,
  BG_RAINBOW = 2,
  BG_TWINKLE = 3,
  BG_MATRIX  = 4,
  BG_FIRE    = 5,
  BG_WAVE    = 6,
  BG_STARS   = 7,
};

// ─── DURUM ───────────────────────────────────────────────────
Preferences prefs;

uint8_t  brightness   = 160;
bool     blackout     = false;
int      scrollSpeed  = 40;
enum Orient : uint8_t { OR_H=0, OR_V_UP=1, OR_V_DOWN=2 };
Orient   orient       = OR_H;
int8_t   dirLR        = -1;
uint8_t  baseHue      = 0;
uint8_t  textSize     = 1;
int      textY        = 6;
uint8_t  rotSteps     = 0;
bool     playlistMode = false;
uint8_t  activeIdx    = 0;
String   activeText   = customTexts[0];
int16_t  textX        = 0, textW = 0;

TextAnim  textAnim    = TA_SCROLL;
BorderAnim borderAnim = BA_NONE;
uint8_t  borderHue    = 0;
uint8_t  borderWidth  = 1;
BgFill   bgFill       = BG_OFF;

// Animasyon state
uint32_t lastStep     = 0;
uint16_t frame        = 0;
uint8_t  blinkState   = 0;
int16_t  typeIdx      = 0;
uint8_t  chasePos     = 0;
uint8_t  snakePos     = 0;
float    pulseVal     = 0;
static uint8_t twR[MH][MW]={}, twG[MH][MW]={}, twB[MH][MW]={};
static uint8_t mDropY[MW]={}, mDropL[MW]={}, mDropS[MW]={};
static uint8_t fireG[MH+2][MW]={};

// ─── RENK YARDIMCIları ───────────────────────────────────────
uint16_t hsv(uint8_t h, uint8_t s=255, uint8_t v=255){
  // h: 0-255, döndür wheel renk
  h = 255-h;
  if(h<85) return matrix.Color((uint8_t)((255-h*3)*v/255), 0, (uint8_t)(h*3*v/255));
  if(h<170){h-=85; return matrix.Color(0,(uint8_t)(h*3*v/255),(uint8_t)((255-h*3)*v/255));}
  h-=170; return matrix.Color((uint8_t)(h*3*v/255),(uint8_t)((255-h*3)*v/255),0);
}
void hsv3(uint8_t h,uint8_t&r,uint8_t&g,uint8_t&b){
  uint16_t c=hsv(h);r=(c>>16)&0xFF;g=(c>>8)&0xFF;b=c&0xFF;
}

// ─── ARKAPLAN ────────────────────────────────────────────────
void drawBg(){
  if(bgFill==BG_OFF) return;
  if(bgFill==BG_SOLID){
    uint16_t c=hsv(baseHue);uint8_t r=(((c>>16)&0xFF)*200)/255,g=(((c>>8)&0xFF)*200)/255,b=((c&0xFF)*200)/255;
    matrix.fillRect(borderWidth,borderWidth,MW-2*borderWidth,MH-2*borderWidth,matrix.Color(r,g,b));
    return;
  }
  if(bgFill==BG_RAINBOW){
    for(int x=borderWidth;x<MW-borderWidth;x++){
      uint16_t c=hsv((baseHue+x*6+frame)&0xFF);
      uint8_t r=(c>>16)&0xFF,g=(c>>8)&0xFF,b=c&0xFF;
      for(int y=borderWidth;y<MH-borderWidth;y++) matrix.drawPixel(x,y,matrix.Color(r,g,b));
    }return;
  }
  if(bgFill==BG_TWINKLE){
    for(int y=0;y<MH;y++) for(int x=0;x<MW;x++){
      twR[y][x]=(twR[y][x]*220)/255;twG[y][x]=(twG[y][x]*220)/255;twB[y][x]=(twB[y][x]*220)/255;
    }
    for(int i=0;i<4;i++){
      int x=random(borderWidth,MW-borderWidth),y=random(borderWidth,MH-borderWidth);
      uint8_t r,g,b;hsv3((baseHue+random(255))&0xFF,r,g,b);
      twR[y][x]=r;twG[y][x]=g;twB[y][x]=b;
    }
    for(int y=0;y<MH;y++) for(int x=0;x<MW;x++)
      matrix.drawPixel(x,y,matrix.Color(twR[y][x],twG[y][x],twB[y][x]));
    return;
  }
  if(bgFill==BG_MATRIX){
    for(int x=0;x<MW;x++){
      if((frame%mDropS[x])==0) mDropY[x]=(mDropY[x]+1)%MH;
      for(int i=0;i<mDropL[x];i++){
        int y=(mDropY[x]-i+MH)%MH;
        matrix.drawPixel(x,y,matrix.Color(0,255-((i*255)/mDropL[x]),0));
      }
    }return;
  }
  if(bgFill==BG_FIRE){
    for(int x=0;x<MW;x++) fireG[MH+1][x]=random(160,255);
    for(int y=0;y<MH+1;y++) for(int x=0;x<MW;x++){
      int v=(int)fireG[y+1][x]+(int)fireG[y+1][(x-1+MW)%MW]+(int)fireG[y+1][(x+1)%MW]+(int)fireG[y][x];
      v=v/4-random(0,6); fireG[y][x]=(uint8_t)(v<0?0:v);
    }
    for(int y=0;y<MH;y++) for(int x=0;x<MW;x++){
      uint8_t v=fireG[y][x];
      matrix.drawPixel(x,(MH-1)-y,matrix.Color(min(255,v*2),(v>128)?(v-128)*2:0,0));
    }return;
  }
  if(bgFill==BG_WAVE){
    for(int x=borderWidth;x<MW-borderWidth;x++){
      int cy=(MH/2)+(int)(sin((x+frame)*0.4f)*((MH/2)-borderWidth-1));
      for(int w=-1;w<=1;w++){
        int y=cy+w;
        if(y>=borderWidth&&y<MH-borderWidth)
          matrix.drawPixel(x,y,hsv((baseHue+x*8+frame)&0xFF));
      }
    }return;
  }
  if(bgFill==BG_STARS){
    // Yıldız titreme
    for(int i=0;i<3;i++){
      int x=random(borderWidth,MW-borderWidth),y=random(borderWidth,MH-borderWidth);
      uint8_t v=random(100,255);
      matrix.drawPixel(x,y,matrix.Color(v,v,v));
    }return;
  }
}

// ─── ÇERÇEVE ─────────────────────────────────────────────────
void drawBorder(){
  if(borderAnim==BA_NONE||borderWidth==0) return;
  int perimeter=2*(MW+MH)-4;
  for(int bw=0;bw<borderWidth;bw++){
    int pos=0;
    // Üst
    for(int x=bw;x<MW-bw;x++){
      uint16_t c=0;
      if(borderAnim==BA_SOLID)   c=hsv(borderHue);
      else if(borderAnim==BA_CHASE)   c=(pos==chasePos%perimeter)?0xFFFF:hsv(borderHue,255,50);
      else if(borderAnim==BA_RAINBOW) c=hsv((borderHue+pos*4+frame*2)&0xFF);
      else if(borderAnim==BA_PULSE){  uint8_t v=(uint8_t)(128+127*sin(frame*0.08f));c=hsv(borderHue,255,v);}
      else if(borderAnim==BA_SNAKE)   c=(abs(pos-snakePos%perimeter)<4)?hsv((borderHue+frame)&0xFF):0;
      else if(borderAnim==BA_SPARKLE) c=(random(20)==0)?0xFFFF:hsv(borderHue,255,80);
      else if(borderAnim==BA_GRADIENT)c=hsv((borderHue+pos*255/perimeter)&0xFF);
      matrix.drawPixel(x,bw,c); pos++;
    }
    // Sağ
    for(int y=bw+1;y<MH-bw;y++){
      uint16_t c=0;
      if(borderAnim==BA_SOLID)   c=hsv(borderHue);
      else if(borderAnim==BA_CHASE)   c=(pos==chasePos%perimeter)?0xFFFF:hsv(borderHue,255,50);
      else if(borderAnim==BA_RAINBOW) c=hsv((borderHue+pos*4+frame*2)&0xFF);
      else if(borderAnim==BA_PULSE){  uint8_t v=(uint8_t)(128+127*sin(frame*0.08f));c=hsv(borderHue,255,v);}
      else if(borderAnim==BA_SNAKE)   c=(abs(pos-snakePos%perimeter)<4)?hsv((borderHue+frame)&0xFF):0;
      else if(borderAnim==BA_SPARKLE) c=(random(20)==0)?0xFFFF:hsv(borderHue,255,80);
      else if(borderAnim==BA_GRADIENT)c=hsv((borderHue+pos*255/perimeter)&0xFF);
      matrix.drawPixel(MW-1-bw,y,c); pos++;
    }
    // Alt (ters)
    for(int x=MW-2-bw;x>=bw;x--){
      uint16_t c=0;
      if(borderAnim==BA_SOLID)   c=hsv(borderHue);
      else if(borderAnim==BA_CHASE)   c=(pos==chasePos%perimeter)?0xFFFF:hsv(borderHue,255,50);
      else if(borderAnim==BA_RAINBOW) c=hsv((borderHue+pos*4+frame*2)&0xFF);
      else if(borderAnim==BA_PULSE){  uint8_t v=(uint8_t)(128+127*sin(frame*0.08f));c=hsv(borderHue,255,v);}
      else if(borderAnim==BA_SNAKE)   c=(abs(pos-snakePos%perimeter)<4)?hsv((borderHue+frame)&0xFF):0;
      else if(borderAnim==BA_SPARKLE) c=(random(20)==0)?0xFFFF:hsv(borderHue,255,80);
      else if(borderAnim==BA_GRADIENT)c=hsv((borderHue+pos*255/perimeter)&0xFF);
      matrix.drawPixel(x,MH-1-bw,c); pos++;
    }
    // Sol (ters)
    for(int y=MH-2-bw;y>bw;y--){
      uint16_t c=0;
      if(borderAnim==BA_SOLID)   c=hsv(borderHue);
      else if(borderAnim==BA_CHASE)   c=(pos==chasePos%perimeter)?0xFFFF:hsv(borderHue,255,50);
      else if(borderAnim==BA_RAINBOW) c=hsv((borderHue+pos*4+frame*2)&0xFF);
      else if(borderAnim==BA_PULSE){  uint8_t v=(uint8_t)(128+127*sin(frame*0.08f));c=hsv(borderHue,255,v);}
      else if(borderAnim==BA_SNAKE)   c=(abs(pos-snakePos%perimeter)<4)?hsv((borderHue+frame)&0xFF):0;
      else if(borderAnim==BA_SPARKLE) c=(random(20)==0)?0xFFFF:hsv(borderHue,255,80);
      else if(borderAnim==BA_GRADIENT)c=hsv((borderHue+pos*255/perimeter)&0xFF);
      matrix.drawPixel(bw,y,c); pos++;
    }
  }
  // Çerçeve animasyon sayaçları
  if(frame%2==0) chasePos++;
  if(frame%3==0) snakePos++;
}

// ─── YAZI ────────────────────────────────────────────────────
void applyOrient(){
  uint8_t r=(rotSteps+( orient==OR_H?0:orient==OR_V_UP?1:3 ))&0x3;
  matrix.setRotation(r);
}
void prepareText(const String&s){
  applyOrient();
  matrix.setTextWrap(false);matrix.setTextSize(textSize);
  int16_t x1,y1;uint16_t w,h;
  matrix.getTextBounds(s,0,0,&x1,&y1,&w,&h);textW=w;
  if(orient==OR_H){
    textX=(dirLR<0)?matrix.width():-textW;
  } else {
    // Dikey modda metin ortada sabit başlar, yukarı veya aşağı kayar
    textX=(matrix.width()/2)-(textW/2);
  }
}

uint16_t getTextColor(int16_t col){
  switch(textAnim){
    case TA_WAVE:    return hsv((baseHue+col*12+frame)&0xFF);
    case TA_RAINBOW: return hsv((baseHue+frame*3)&0xFF);
    case TA_GLOW: {
      uint8_t v=(uint8_t)(128+127*sin(frame*0.06f));
      return hsv(baseHue,255,v);
    }
    default: return hsv(baseHue);
  }
}

void drawText(){
  applyOrient();
  matrix.setTextWrap(false);matrix.setTextSize(textSize);

  if(textAnim==TA_BLINK){
    if(frame%20<10){
      matrix.setTextColor(hsv(baseHue));
      matrix.setCursor(textX,textY);matrix.print(activeText);
    }
  } else if(textAnim==TA_TYPING){
    // Yazı karakter karakter beliriyor
    int show=min((int)(frame/8),(int)activeText.length());
    String sub=activeText.substring(0,show);
    matrix.setTextColor(hsv(baseHue));
    matrix.setCursor(borderWidth+1,textY);matrix.print(sub);
    if(show>=(int)activeText.length()&&frame%80<5) matrix.drawPixel(borderWidth+1+show*6,textY+5,0xFFFF);
  } else {
    // Kaydırmalı animasyonlar
    for(int i=0;i<(int)activeText.length();i++){
      matrix.setTextColor(getTextColor(textX+i*6));
    }
    matrix.setTextColor(getTextColor(textX));
    matrix.setCursor(textX,textY);
    matrix.print(activeText);
    // Kaydır
    if(orient==OR_H){
      textX+=(dirLR<0?-1:+1);
    } else if(orient==OR_V_UP){
      textX--;  // Dikey yukarı = sol kaydırma (rotate ile yukarı olur)
    } else {
      textX++;  // Dikey aşağı
    }
    bool wrapped=false;
    if(orient==OR_H){
      if(dirLR<0){if(textX<-textW){textX=matrix.width();wrapped=true;}}
      else{if(textX>matrix.width()){textX=-textW;wrapped=true;}}
    } else {
      if(textX<-textW){textX=matrix.width();wrapped=true;}
      if(textX>matrix.width()){textX=-textW;wrapped=true;}
    }
    if(playlistMode&&wrapped){
      activeIdx=(activeIdx+1)%textCount;
      activeText=customTexts[activeIdx];
      baseHue+=31;prepareText(activeText);savePrefs();
    }
  }
}

// ─── ANA ÇİZİM ───────────────────────────────────────────────
void drawFrame(){
  matrix.fillScreen(0);
  drawBg();
  drawText();
  drawBorder();
  matrix.show();
  frame++;
}

// ─── PREFS ───────────────────────────────────────────────────
void savePrefs(){
  prefs.begin("tb",false);
  prefs.putUChar("ai",activeIdx);
  prefs.putUChar("br",brightness);prefs.putShort("sp",scrollSpeed);
  prefs.putUChar("ot",(uint8_t)orient);
  prefs.putChar("dl",dirLR);prefs.putUChar("hu",baseHue);
  prefs.putUChar("ts",textSize);prefs.putChar("ty",textY);
  prefs.putUChar("ro",rotSteps);prefs.putBool("pl",playlistMode);
  prefs.putUChar("ta",(uint8_t)textAnim);
  prefs.putUChar("ba",(uint8_t)borderAnim);
  prefs.putUChar("bh",borderHue);prefs.putUChar("bw",borderWidth);
  prefs.putUChar("bg",(uint8_t)bgFill);
  // Özel metinleri kaydet
  for(int i=0;i<textCount;i++){
    prefs.putString(("t"+String(i)).c_str(),customTexts[i]);
  }
  prefs.putUChar("tc",textCount);
  prefs.end();
}
void loadPrefs(){
  prefs.begin("tb",true);
  activeIdx=prefs.getUChar("ai",0);
  brightness=prefs.getUChar("br",160);scrollSpeed=prefs.getShort("sp",40);
  orient=(Orient)prefs.getUChar("ot",0);
  dirLR=prefs.getChar("dl",-1);baseHue=prefs.getUChar("hu",0);
  textSize=prefs.getUChar("ts",1);textY=prefs.getChar("ty",6);
  rotSteps=prefs.getUChar("ro",0);playlistMode=prefs.getBool("pl",false);
  textAnim=(TextAnim)prefs.getUChar("ta",0);
  borderAnim=(BorderAnim)prefs.getUChar("ba",0);
  borderHue=prefs.getUChar("bh",0);borderWidth=prefs.getUChar("bw",1);
  bgFill=(BgFill)prefs.getUChar("bg",0);
  uint8_t tc=prefs.getUChar("tc",8);
  if(tc>0&&tc<=MAX_CUSTOM) textCount=tc;
  for(int i=0;i<textCount;i++){
    String def=customTexts[i];
    customTexts[i]=prefs.getString(("t"+String(i)).c_str(),def);
  }
  prefs.end();
  if(activeIdx>=textCount) activeIdx=0;
  activeText=customTexts[activeIdx];
}

// ─── JSON STATUS ─────────────────────────────────────────────
String buildStatus(){
  String s="{";
  s+="\"brightness\":"+String(brightness)+",";
  s+="\"speed\":"+String(scrollSpeed)+",";
  s+="\"blackout\":"+String(blackout?"true":"false")+",";
  s+="\"hue\":"+String(baseHue)+",";
  s+="\"textSize\":"+String(textSize)+",";
  s+="\"orient\":"+String((int)orient)+",";
  s+="\"dirLR\":"+String(dirLR)+",";
  s+="\"playlist\":"+String(playlistMode?"true":"false")+",";
  s+="\"activeIdx\":"+String(activeIdx)+",";
  s+="\"textAnim\":"+String((int)textAnim)+",";
  s+="\"borderAnim\":"+String((int)borderAnim)+",";
  s+="\"borderHue\":"+String(borderHue)+",";
  s+="\"borderWidth\":"+String(borderWidth)+",";
  s+="\"bgFill\":"+String((int)bgFill)+",";
  s+="\"textCount\":"+String(textCount)+",";
  s+="\"texts\":[";
  for(int i=0;i<textCount;i++){
    s+="\""+customTexts[i]+"\"";
    if(i<textCount-1) s+=",";
  }
  s+="]}";
  return s;
}

void sendStatus(){
  if(bleCon&&stsChar){
    String st=buildStatus();
    // BLE MTU ~512, uzunsa böl
    if(st.length()<=512){
      stsChar->setValue(st.c_str());stsChar->notify();
    }
  }
}

// ─── KOMUT İŞLE ──────────────────────────────────────────────
void processCmd(const String&raw){
  // Basit JSON parse - key:value
  auto getInt=[&](const String&k,int def)->int{
    int i=raw.indexOf("\""+k+"\":");
    if(i<0) return def;
    int s=i+k.length()+3;
    return raw.substring(s).toInt();
  };
  auto getBool=[&](const String&k,bool def)->bool{
    int i=raw.indexOf("\""+k+"\":");
    if(i<0) return def;
    int s=i+k.length()+3;
    return raw.substring(s,s+4)=="true";
  };
  auto getStr=[&](const String&k)->String{
    int i=raw.indexOf("\""+k+"\":\"");
    if(i<0) return "";
    int s=i+k.length()+4;
    int e=raw.indexOf("\"",s);
    if(e<0) return "";
    return raw.substring(s,e);
  };

  if(raw.indexOf("\"brightness\":")>=0){ brightness=(uint8_t)constrain(getInt("brightness",160),0,255);matrix.setBrightness(brightness);}
  if(raw.indexOf("\"speed\":")>=0)      scrollSpeed=constrain(getInt("speed",40),5,500);
  if(raw.indexOf("\"hue\":")>=0)        baseHue=(uint8_t)getInt("hue",0);
  if(raw.indexOf("\"borderHue\":")>=0)  borderHue=(uint8_t)getInt("borderHue",0);
  if(raw.indexOf("\"borderWidth\":")>=0)borderWidth=(uint8_t)constrain(getInt("borderWidth",1),0,4);
  if(raw.indexOf("\"textSize\":")>=0){  textSize=(uint8_t)constrain(getInt("textSize",1),1,2);prepareText(activeText);}
  if(raw.indexOf("\"orient\":")>=0){  orient=(Orient)constrain(getInt("orient",0),0,2);prepareText(activeText);}
  if(raw.indexOf("\"dirLR\":")>=0){     dirLR=(getInt("dirLR",-1)>=0)?1:-1;prepareText(activeText);}
  if(raw.indexOf("\"textY\":")>=0){     textY=constrain(getInt("textY",6),0,MH-8);}
  if(raw.indexOf("\"blackout\":")>=0){  blackout=getBool("blackout",false);if(blackout){matrix.fillScreen(0);matrix.show();}}
  if(raw.indexOf("\"playlist\":")>=0)   playlistMode=getBool("playlist",false);
  if(raw.indexOf("\"textAnim\":")>=0)   textAnim=(TextAnim)constrain(getInt("textAnim",0),0,5);
  if(raw.indexOf("\"borderAnim\":")>=0) borderAnim=(BorderAnim)constrain(getInt("borderAnim",0),0,7);
  if(raw.indexOf("\"bgFill\":")>=0)     bgFill=(BgFill)constrain(getInt("bgFill",0),0,7);
  if(raw.indexOf("\"activeIdx\":")>=0){ activeIdx=(uint8_t)constrain(getInt("activeIdx",0),0,textCount-1);activeText=customTexts[activeIdx];prepareText(activeText);}
  if(raw.indexOf("\"rotSteps\":")>=0){  rotSteps=(uint8_t)getInt("rotSteps",0)&0x3;prepareText(activeText);}

  // Özel metin güncelle: {"setText":{"idx":0,"text":"MERHABA "}}
  if(raw.indexOf("\"setText\":")>=0){
    int bi=raw.indexOf("\"setText\":");
    String sub=raw.substring(bi+10);
    int idxPos=sub.indexOf("\"idx\":");
    int txtPos=sub.indexOf("\"text\":\"");
    if(idxPos>=0&&txtPos>=0){
      int idx=sub.substring(idxPos+6).toInt();
      int ts=txtPos+8;
      int te=sub.indexOf("\"",ts);
      String newTxt=sub.substring(ts,te);
      if(idx>=0&&idx<MAX_CUSTOM){
        customTexts[idx]=newTxt;
        if(idx>=textCount) textCount=idx+1;
        if(idx==activeIdx){activeText=newTxt;prepareText(activeText);}
      }
    }
  }

  // Yeni metin ekle: {"addText":"YENI YAZI "}
  String addT=getStr("addText");
  if(addT.length()>0&&textCount<MAX_CUSTOM){
    customTexts[textCount]=addT;
    textCount++;
  }

  savePrefs();
  sendStatus();
}

// ─── IR ──────────────────────────────────────────────────────
void handleIR(){
  if(!IrReceiver.decode()) return;
  if(IrReceiver.decodedIRData.flags&IRDATA_FLAGS_IS_REPEAT){IrReceiver.resume();return;}
  uint32_t c=IrReceiver.decodedIRData.decodedRawData;
  if(c==IR_PLY){playlistMode=!playlistMode;savePrefs();}
  else if(c==IR_CH_M){if(activeIdx>0)activeIdx--;else activeIdx=textCount-1;activeText=customTexts[activeIdx];prepareText(activeText);savePrefs();}
  else if(c==IR_CH_P){activeIdx=(activeIdx+1)%textCount;activeText=customTexts[activeIdx];prepareText(activeText);savePrefs();}
  else if(c==IR_PRV){scrollSpeed=min(500,scrollSpeed+5);savePrefs();}
  else if(c==IR_NXT){scrollSpeed=max(5,scrollSpeed-5);savePrefs();}
  else if(c==IR_VM){brightness=(brightness<=10?0:brightness-10);matrix.setBrightness(brightness);savePrefs();}
  else if(c==IR_VP){brightness=(brightness>=245?255:brightness+10);matrix.setBrightness(brightness);savePrefs();}
  else if(c==IR_EQ){blackout=!blackout;if(blackout){matrix.fillScreen(0);matrix.show();}}
  else if(c==IR_FM){baseHue-=16;savePrefs();}
  else if(c==IR_FP){baseHue+=16;savePrefs();}
  else if(c==IR_1){orient=(Orient)((orient+1)%3);prepareText(activeText);savePrefs();}
  else if(c==IR_3){borderAnim=(BorderAnim)((borderAnim+1)%8);savePrefs();}
  else if(c==IR_7){bgFill=(BgFill)((bgFill+1)%8);savePrefs();}
  else if(c==IR_9){borderHue+=32;savePrefs();}
  else if(c==IR_4){
    if(orient==OR_H) dirLR=-1;
    else{ orient=OR_V_UP; }
    prepareText(activeText);savePrefs();
  }
  else if(c==IR_6){
    if(orient==OR_H) dirLR=+1;
    else{ orient=OR_V_DOWN; }
    prepareText(activeText);savePrefs();
  }
  else if(c==IR_5){textSize=(textSize==1?2:1);prepareText(activeText);savePrefs();}
  else if(c==IR_0){rotSteps=(rotSteps+1)&0x3;prepareText(activeText);savePrefs();}
  else if(c==IR_8){borderWidth=(borderWidth>=3?0:borderWidth+1);savePrefs();}
  IrReceiver.resume();
}

// ─── BLE ─────────────────────────────────────────────────────
class BleSrvCB : public BLEServerCallbacks {
  void onConnect(BLEServer*)    override { bleCon=true; Serial.println("[BLE] Baglandi"); delay(500); sendStatus(); }
  void onDisconnect(BLEServer*) override { bleCon=false; Serial.println("[BLE] Ayrildi"); BLEDevice::startAdvertising(); }
};
class BleCmdCB : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override { bleCmd=String(c->getValue().c_str()); bleNew=true; }
};

void setupBLE(){
  BLEDevice::init("AkilliTahta");
  BLEDevice::setMTU(512);
  bleServer=BLEDevice::createServer();
  bleServer->setCallbacks(new BleSrvCB());
  BLEService* svc=bleServer->createService(SVC_UUID);
  cmdChar=svc->createCharacteristic(CMD_UUID, BLECharacteristic::PROPERTY_WRITE|BLECharacteristic::PROPERTY_WRITE_NR);
  cmdChar->setCallbacks(new BleCmdCB());
  stsChar=svc->createCharacteristic(STS_UUID, BLECharacteristic::PROPERTY_READ|BLECharacteristic::PROPERTY_NOTIFY);
  stsChar->addDescriptor(new BLE2902());
  svc->start();
  BLEAdvertising* adv=BLEDevice::getAdvertising();
  adv->addServiceUUID(SVC_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
  Serial.println("[BLE] AkilliTahta hazir");
}

// ─── SETUP ───────────────────────────────────────────────────
void setup(){
  Serial.begin(115200);
  matrix.begin(); matrix.setTextWrap(false);
  loadPrefs();
  if(brightness==0) brightness=120;
  blackout=false;
  matrix.setBrightness(brightness);
  IrReceiver.begin(IR_PIN, DISABLE_LED_FEEDBACK);
  // Matrix efekt başlat
  for(int x=0;x<MW;x++){mDropY[x]=random(MH);mDropL[x]=random(3,MH/2);mDropS[x]=random(1,4);}
  prepareText(activeText);
  // Boot animasyon
  for(uint8_t h=0;h<255;h+=5){matrix.fillScreen(hsv(h));matrix.show();delay(8);}
  matrix.fillScreen(0);matrix.show();
  setupBLE();
  Serial.println("[HAZIR] AkilliTahta v4.0");
}

// ─── LOOP ────────────────────────────────────────────────────
void loop(){
  handleIR();
  if(bleNew){ processCmd(bleCmd); bleNew=false; }
  if(blackout) return;
  uint32_t now=millis();
  if(now-lastStep>=(uint32_t)scrollSpeed){
    lastStep=now;
    drawFrame();
  }
}
