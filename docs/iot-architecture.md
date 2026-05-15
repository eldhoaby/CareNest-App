# 📡 IoT Architecture & Integration

CareNest relies on real-time ambient data to ensure elderly safety. This document outlines how hardware interacts with our cloud infrastructure.

## Hardware Stack
- **Microcontrollers:** ESP32 / ESP8266
- **Sensors:** 
  - Passive Infrared (PIR) for motion
  - DHT11/22 for temperature and humidity
  - AD8232 for basic ECG/Heart Rate monitoring

## MQTT Messaging Protocol
We utilize a lightweight MQTT broker (Mosquitto) for telemetry data.
- **Publishing:** Sensors publish to specific topics (e.g., `carenest/device_123/vitals`).
- **Subscribing:** A Node.js worker subscribes to these topics, validates the payload, and commits it to Firestore.

## Fallback Mechanisms
If the primary internet connection drops, the ESP32 buffers up to 50 localized events and batch-publishes them upon reconnection.
