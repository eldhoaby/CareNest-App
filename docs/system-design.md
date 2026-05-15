# 🏗 System Design & Architecture

CareNest implements a highly responsive, event-driven architecture designed to ensure high availability and sub-second latency for critical emergency alerts. The system utilizes a decoupled microservices-inspired approach.

## Detailed Architectural Flow

The following diagram illustrates the flow of data across the different layers of the CareNest ecosystem, derived directly from the application's source code architecture.

```mermaid
flowchart TD
    %% Define Styles
    classDef hardware fill:#2d3436,stroke:#b2bec3,stroke-width:2px,color:#dfe6e9;
    classDef backend fill:#0984e3,stroke:#74b9ff,stroke-width:2px,color:#ffffff;
    classDef database fill:#e17055,stroke:#fab1a0,stroke-width:2px,color:#ffffff;
    classDef mobile fill:#00b894,stroke:#55efc4,stroke-width:2px,color:#ffffff;
    classDef service fill:#6c5ce7,stroke:#a29bfe,stroke-width:2px,color:#ffffff;
    classDef web fill:#fdcb6e,stroke:#ffeaa7,stroke-width:2px,color:#2d3436;

    %% IoT Edge Tier
    subgraph IoT_Edge ["🔌 IoT Edge Layer (Hardware)"]
        Sensors["Sensors (PIR, Temp, ECG)"]:::hardware
        ESP["Microcontroller (ESP32/8266)"]:::hardware
        Sensors --> ESP
    end

    %% Network / Broker
    subgraph Network ["🌐 Networking Protocol"]
        MQTT["MQTT Broker (Telemetry Streams)"]:::backend
        ESP -- "Publishes Data" --> MQTT
    end

    %% Cloud Infrastructure Tier
    subgraph Cloud ["☁️ Cloud Infrastructure (Firebase)"]
        Firestore[("Firestore (Real-time DB)")]:::database
        Auth["Firebase Auth (Identity)"]:::database
        FCM["Firebase Cloud Messaging"]:::database
        
        MQTT -- "Ingestion Worker writes to" --> Firestore
    end

    %% Application Core Services (Extracted from lib/core/services)
    subgraph Mobile_Core ["⚙️ Flutter Core Services"]
        FirebaseSvc["FirebaseService"]:::service
        AlertSvc["AlertService / CacheService"]:::service
        NotifSvc["NotificationService / SoundService"]:::service
        
        Firestore -- "Snapshot Listeners" --> FirebaseSvc
        FirebaseSvc --> AlertSvc
        FCM -- "Push Notifications" --> NotifSvc
        AlertSvc --> NotifSvc
    end

    %% Presentation Layer (Extracted from lib/screens)
    subgraph Presentation ["📱 Presentation Layer (Flutter App)"]
        ElderlyUI["Elderly Screens (Dashboard, Activity)"]:::mobile
        CaregiverUI["Caregiver Screens (Monitoring, Alerts)"]:::mobile
        EmergencyUI["Emergency Override Module"]:::mobile
        
        Auth -. "Authenticates" .-> ElderlyUI
        Auth -. "Authenticates" .-> CaregiverUI
        
        AlertSvc --> ElderlyUI
        AlertSvc --> CaregiverUI
        ElderlyUI -- "Triggers SOS" --> EmergencyUI
        EmergencyUI -- "Writes Emergency State" --> Firestore
    end

    %% Web Admin Layer
    subgraph Web_Admin ["💻 Administrative Layer"]
        ReactUI["React Admin Dashboard"]:::web
        Firestore -- "Aggregated Analytics" --> ReactUI
    end
```

## Layer Breakdown

### 1. Presentation Layer (`lib/screens`)
Separates concerns via role-based routing. The `Elderly` module provides an accessible, simplified interface with a prominent SOS trigger. The `Caregiver` module offers high-fidelity data visualization and alert management capabilities.

### 2. Core Services Layer (`lib/core/services`)
- **`FirebaseService`:** Acts as the singleton bridge between the UI and cloud infrastructure, managing active snapshot subscriptions to prevent memory leaks.
- **`AlertService` & `GlobalAlertCacheService`:** Houses the business logic for evaluating thresholds. It intercepts changes in the `SensorDataModel` and, if an anomaly is detected, constructs an `AlertModel`.
- **`NotificationService` & `SoundService`:** Handles local OS-level push notifications and audio alerts ensuring the caregiver is immediately notified even when the app is backgrounded.

### 3. Data Entities (`lib/models`)
Data serialization is strictly typed to ensure integrity over the wire:
- `UserModel` for identity.
- `SensorDataModel` for telemetry logs.
- `AlertModel` for incident tracking and resolution state.

### 4. Scalability Factors
- **Stateless Backend:** Any Node.js processing workers are stateless, allowing for horizontal pod autoscaling based on MQTT traffic load.
- **Serverless Database:** Firestore automatically scales read/write capacity based on active application connections.
