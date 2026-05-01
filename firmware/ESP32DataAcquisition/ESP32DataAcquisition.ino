#include <Wire.h>
#include "MAX30105.h"   // SparkFun MAX3010x library (works with MAX30102)
#include <Arduino.h>

MAX30105 sensor;

// ==== I2C pins  ====
#define SDA_PIN 21
#define SCL_PIN 22
#define FORCE_SENSOR_PIN1 33 // FSR 1
#define FORCE_SENSOR_PIN2 32 // FSR 2


// ==== Sensor setup ====
const byte LED_BRIGHTNESS = 80;   // 0–255 (lower if saturated)
const byte SAMPLE_AVG     = 4;    // 1,2,4,8,16,32
const int  LED_MODE       = 2 ;    // 2 = Red + IR
const int  SAMPLE_RATE_HZ = 200;  // keep at 100 Hz
const int  PULSE_WIDTH    = 411;  // 69,118,215,411 µs — wider = more SNR
const int  ADC_RANGE      = 8192;

//EDA Parameters//
int R = 200000;
int F = 5000;
static const int EDA_PIN = 34;

//Rates//
#define EDA_HZ 32       // EDA sampling rate (Hz)
#define FSR_HZ 50       // FSR sampling rate (Hz)

#define LOG_HZ 50   // rows per second

//Timer for logging
static uint32_t lastLogMs = 0;
//

// --- rate-gated caches ---
static uint32_t lastEdaMs = 0, lastFsrMs = 0;
static int      fsr1_last = 0, fsr2_last = 0;

static int     eda_raw_last = 0;   // ADC counts (0..4095)
static float   Rskin_last   = 0.0; // Ohms
static double  CSkin_last   = 0.0; // microSiemens



// ==== HR algorithm parameters ====
const int   FS                 = SAMPLE_RATE_HZ;
const int   MA_DC_WINDOW       = FS * 1;   // 1 s moving-average for DC removal
const int   MA_SMOOTH_WINDOW   = 5;        // short smoother
const float THRESH_K           = 1.4f;     // k for adaptive threshold: thr = k*mean(|AC|)
const int   MIN_IBI_MS         = 300;      // 200 bpm upper bound
const int   MAX_IBI_MS         = 1500;     // 40 bpm lower bound
const int   IBI_MEDIAN_COUNT   = 5;        // smooth HR with last 5 beats

// ---- state for DC removal (moving average) ----
static int32_t dcBuf[MA_DC_WINDOW];
static int     dcIdx = 0;
static int64_t dcSum = 0;

// ---- state for short smoother ----
static int32_t smBuf[MA_SMOOTH_WINDOW];
static int     smIdx = 0;
static int64_t smSum = 0;

// ---- state for adaptive threshold from |AC| mean ----
static int32_t absBuf[MA_DC_WINDOW];
static int     absIdx = 0;
static int64_t absSum = 0;

// ---- peak detection state ----
static int32_t y_nm2 = 0, y_nm1 = 0;    // y[n-2], y[n-1]
static uint32_t t_nm2 = 0, t_nm1 = 0;   // times for those samples
static uint32_t lastBeatTime = 0;
static int      ibiHistory[IBI_MEDIAN_COUNT];
static int      ibiCount = 0;
static bool     haveHR = false;
static float    hrBPM = 0.0f;

// ---- helpers ----
inline int32_t movingAverageInsert(int32_t x, int32_t *buf, int &idx, int64_t &sum, int win) {
  sum += x - buf[idx];
  buf[idx] = x;
  idx++; if (idx >= win) idx = 0;
  return (int32_t)(sum / win);
}

int median5(int *a, int n) {
  // small, simple median for up to 5 integers
  int b[5];
  for (int i=0;i<n;i++) b[i]=a[i];
  // insertion sort
  for (int i=1;i<n;i++){
    int key=b[i], j=i-1;
    while(j>=0 && b[j]>key){ b[j+1]=b[j]; j--; }
    b[j+1]=key;
  }
  return b[n/2];
}

void setup() {
  Serial.begin(115200);
  delay(50);
  lastBeatTime = millis();
  analogReadResolution(12);
  analogSetPinAttenuation(EDA_PIN, ADC_11db); // ~0–3.55 V span (keep <= 3.3 V)
  pinMode(EDA_PIN, INPUT);

  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(400000); // I2C Fast mode

  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
    while (true) {
      Serial.println("MAX30102 not found. Check 3V3, GND, SDA, SCL and the pin defines at top.");
      delay(1000);
    }
  }

  sensor.setup(LED_BRIGHTNESS, SAMPLE_AVG, LED_MODE,
               SAMPLE_RATE_HZ, PULSE_WIDTH, ADC_RANGE);

  sensor.setPulseAmplitudeRed(LED_BRIGHTNESS);
  sensor.setPulseAmplitudeIR(0);
  sensor.setPulseAmplitudeGreen(0);

  // CSV header
  Serial.println("ts_ms,ir,HR,fsr1,fsr2,eda_adc,r_skin,eda_uS");
}

void loop() {
  sensor.check();
  

  while (sensor.available()) {
    uint32_t nowMs = millis();
    uint32_t irRaw = sensor.getFIFORed();
     

    
    //FSR Time & Read
    if (nowMs - lastFsrMs >= (1000UL / FSR_HZ)) { //Freq FSR
    fsr1_last = analogRead(FORCE_SENSOR_PIN1);
    fsr2_last = analogRead(FORCE_SENSOR_PIN2);
    lastFsrMs = nowMs;
    }

    //EDA Time
    if (nowMs - lastEdaMs >= (1000UL / EDA_HZ)) {
    int raw = analogRead(EDA_PIN);
    eda_raw_last = raw;

      // EDA conversions
    float vout   = (raw * 3.3f) / 4095.0f;
    float Rskin  = (R * (vout * (R + F) + 2.0f * 1.8f * F)) / (2.0f * 1.8f * R - vout * R - vout * F);
    double CSkin = (Rskin > 0.0f) ? (1.0 / Rskin) * 1e6 : 0.0;

    Rskin_last = Rskin;
    CSkin_last = CSkin;
    lastEdaMs  = nowMs;
  }

  

    // ----- 1) DC removal on IR -----
    int32_t dcMean = movingAverageInsert((int32_t)irRaw, dcBuf, dcIdx, dcSum, MA_DC_WINDOW);
    int32_t ac = (int32_t)irRaw - dcMean;

    // ----- 2) short smoothing -----
    int32_t smoothed = movingAverageInsert(ac, smBuf, smIdx, smSum, MA_SMOOTH_WINDOW);

    // ----- 3) adaptive threshold from |AC| mean -----
    int32_t absMean = movingAverageInsert((int32_t)abs(smoothed), absBuf, absIdx, absSum, MA_DC_WINDOW);
    float thr = THRESH_K * (float)absMean;

    // ----- 4) local-maximum peak picking with refractory guard -----
    // We have y[n-2] -> y_nm2, y[n-1] -> y_nm1, current -> y_n
    int32_t y_n = smoothed;

    bool isLocalMax = (y_nm1 > y_nm2) && (y_nm1 >= y_n);
    bool overThr    = ( (float)y_nm1 > thr );
    bool refractory = (nowMs - lastBeatTime) >= (uint32_t)MIN_IBI_MS;

    if (isLocalMax && overThr && refractory) {
      uint32_t ibi = nowMs - lastBeatTime;
      lastBeatTime = nowMs;

      if (ibi >= MIN_IBI_MS && ibi <= MAX_IBI_MS) {
        // push into history (size up to 5), compute median HR
        if (ibiCount < IBI_MEDIAN_COUNT) ibiHistory[ibiCount++] = (int)ibi;
        else {
          // shift left and insert
          for (int i=1;i<IBI_MEDIAN_COUNT;i++) ibiHistory[i-1]=ibiHistory[i];
          ibiHistory[IBI_MEDIAN_COUNT-1]=(int)ibi;
        }
        int n = (ibiCount < IBI_MEDIAN_COUNT) ? ibiCount : IBI_MEDIAN_COUNT;
        int ibiMed = median5(ibiHistory, n);
        hrBPM = 60000.0f / (float)ibiMed;
        haveHR = true;
      }
    }


    // advance FIFO sample
    sensor.nextSample();

    // roll the lag variables
    t_nm2 = t_nm1; y_nm2 = y_nm1;
    t_nm1 = nowMs; y_nm1 = y_n;
    
    //VARIABLES LOGGING
    if (nowMs - lastLogMs >= (1000UL / LOG_HZ)) {
    // Your current columns/order — keep exactly what your header says
    Serial.print(nowMs);        Serial.print(","); // [TIME]
    Serial.print(irRaw);        Serial.print(","); // [IR] 
    if (haveHR) Serial.print(hrBPM, 1);
    else        Serial.print(0);
    Serial.print(",");
    Serial.print(fsr1_last);    Serial.print(","); // [FSR1]
    Serial.print(fsr2_last);    Serial.print(","); // [FSR2]
    Serial.print(eda_raw_last); Serial.print(","); // [EDA Raw Data]
    Serial.print(Rskin_last);   Serial.print(","); // [R_Skin]
    Serial.println(CSkin_last);                   // [C_Skin] (Micro-siemens)

    lastLogMs = nowMs;
  }

  
  }
  
} 
