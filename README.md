<div align="center">
  
# 🏥 CareNest
### Ambient Assisted Living & Healthcare System

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/firebase-ffca28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/)
[![React](https://img.shields.io/badge/react-%2320232a.svg?style=for-the-badge&logo=react&logoColor=%2361DAFB)](https://reactjs.org/)
[![Node.js](https://img.shields.io/badge/node.js-6DA55F?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

*An enterprise-grade, real-time healthcare monitoring platform designed to empower elderly care through ambient intelligence.*

[Report Bug](https://github.com/eldhoaby/CareNest-App/issues) · [Request Feature](https://github.com/eldhoaby/CareNest-App/issues)
</div>

---

## 📖 Project Vision & Objectives

**CareNest** is a comprehensive Ambient Assisted Living (AAL) system engineered to provide non-intrusive, real-time monitoring and support for the elderly. By combining a mobile application for real-time alerts with a robust admin dashboard for data management, CareNest aims to bridge the gap between independent living and necessary medical oversight.

Our primary objective is to enhance the quality of life for seniors while providing peace of mind to their families and caregivers through continuous, intelligent monitoring.

## ✨ Key Features

* **Real-time Health Monitoring:** Continuous synchronization of vital data and environmental metrics.
* **Intelligent Alert Management:** Automated threshold-based alerts dispatched instantly via Firebase Cloud Messaging.
* **Role-Based Access Control:** Distinct interfaces tailored for Elderly, Caregivers, and Administrators.
* **Ambient Sensor Integration:** Support for smart home sensors detecting motion, temperature, and anomalies.
* **Secure Authentication:** Multi-factor and OAuth support utilizing Firebase Authentication.
* **Responsive Admin Dashboard:** A React-based portal for managing users, reviewing analytics, and configuring system parameters.

## 🛠 Tech Stack

| Domain | Technology | Description |
| :--- | :--- | :--- |
| **Frontend (Mobile)** | Flutter, Dart | Cross-platform mobile application for Elderly & Caregivers |
| **Frontend (Web)** | React.js | Responsive Admin Dashboard |
| **Backend & APIs** | Node.js, Express.js | RESTful APIs and webhook handlers |
| **Database & Real-time** | Firebase Firestore | NoSQL database with real-time listeners |
| **Authentication** | Firebase Auth | Secure user identity management |
| **Deployment** | Vercel, Render | Automated CI/CD and hosting infrastructure |

## 📐 System Architecture

The CareNest architecture follows a decoupled, microservices-oriented approach ensuring high availability and scalability:

1. **Mobile Client (Flutter):** Connects directly to Firebase via WebSockets for real-time data sync and listens for push notifications.
2. **Web Portal (React):** Communicates with the Node.js backend for administrative actions and aggregates Firestore data.
3. **Backend Service (Node/Express):** Hosted on Render, this service manages heavy data processing, external API integrations, and secure administrative operations.
4. **Data Layer (Firebase):** Acts as the single source of truth, facilitating real-time updates across all connected clients.

## 📂 Repository Structure

```text
CareNest/
├── lib/                      # Flutter mobile application source code
│   ├── core/                 # Core services, themes, and utilities
│   ├── models/               # Data models and serialization
│   ├── screens/              # UI screens (Elderly, Caregiver, etc.)
│   └── widgets/              # Reusable UI components
├── assets/                   # Static assets and images
│   └── screenshots/          # Application UI showcases
├── docs/                     # Project documentation
│   └── architecture/         # System design diagrams
├── .github/                  # GitHub templates and workflows
└── README.md                 # Project documentation
```

## 📸 Screenshots

*(Placeholders for application screenshots. Add your actual screenshots to the `assets/screenshots/` directory.)*

<div align="center">
  <img src="assets/screenshots/placeholder1.png" alt="Dashboard" width="200" style="margin: 10px;"/>
  <img src="assets/screenshots/placeholder2.png" alt="Alerts" width="200" style="margin: 10px;"/>
  <img src="assets/screenshots/placeholder3.png" alt="Monitoring" width="200" style="margin: 10px;"/>
</div>

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable)
* [Node.js & npm](https://nodejs.org/) (v16+)
* Firebase CLI (`npm install -g firebase-tools`)

### Installation & Local Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/eldhoaby/CareNest-App.git
   cd CareNest-App
   ```

2. **Setup Mobile App (Flutter)**
   ```bash
   flutter pub get
   flutter run
   ```

3. **Configure Environment Variables**
   Create a `.env` file in the root directory and add your Firebase credentials:
   ```env
   FIREBASE_API_KEY=your_api_key
   FIREBASE_PROJECT_ID=carenest-app
   FIREBASE_SENDER_ID=your_sender_id
   ```

## 📦 Deployment

### Mobile Application
The Flutter application can be built for production using standard build commands:
```bash
flutter build apk --release    # For Android
flutter build ipa --release    # For iOS
```

### Backend & Admin Portal
* **Frontend:** Deployed via **Vercel** with automatic deployments triggered on the `main` branch.
* **Backend:** Hosted on **Render**, running the Express.js server connected to Firebase Admin SDK.

## 🔒 Security Considerations

* **Data Encryption:** All data transmitted between clients and the cloud is encrypted via HTTPS/TLS.
* **Firestore Security Rules:** Strict rules are implemented to ensure users can only access their specific data.
* **Authentication:** Passwords are never stored; Firebase Auth handles all secure token exchanges.

## 🛣 Future Roadmap

- [ ] Integration with wearable IoT devices (Apple Watch, Fitbit).
- [ ] Machine Learning models for predictive health anomaly detection.
- [ ] Voice-activated commands via Google Assistant & Siri.
- [ ] Offline-first data caching capabilities.

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines.

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 🙏 Acknowledgements

* [Flutter Documentation](https://flutter.dev/docs)
* [Firebase Features](https://firebase.google.com/docs)
* [React UI Components](https://reactjs.org/)

---
<div align="center">
  <b>Built with ❤️ for a safer, smarter tomorrow.</b>
</div>
