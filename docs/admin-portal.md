# 🖥️ Admin Portal Guide

The CareNest Admin Portal is a React-based web dashboard designed for system administrators and head nurses to manage the platform at scale.

## Key Features

1. **Global Dashboard:** View system-wide health alerts and active emergencies in real-time.
2. **User Management:** Create, suspend, and edit roles for Seniors and Caregivers.
3. **Hardware Provisioning:** Register new IoT devices and link them to specific user profiles.
4. **Analytics View:** Access historical data charts for patient vitals over time to aid in medical diagnosis.

## Tech Stack
- React.js
- Tailwind CSS (for responsive, utility-first styling)
- Firebase SDK (for auth and real-time listeners)
- Recharts (for data visualization)

## Architecture Notes
The admin portal bypasses the mobile API for read operations to reduce latency, connecting directly to Firestore via the Firebase Web SDK.
