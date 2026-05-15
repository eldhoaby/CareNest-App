# 🗄️ Database Schema

CareNest utilizes Firebase Firestore (NoSQL) for real-time data synchronization.

## Core Collections

### `users`
Stores profile information and role assignments.
```json
{
  "uid": "string",
  "name": "string",
  "role": "elderly | caregiver | admin",
  "contactNumber": "string",
  "caregiverId": "string (reference)",
  "createdAt": "timestamp"
}
```

### `health_metrics`
Time-series data for vital signs.
```json
{
  "userId": "string (reference)",
  "heartRate": "number",
  "temperature": "number",
  "oxygenLevel": "number",
  "recordedAt": "timestamp"
}
```

### `alerts`
Stores emergency and threshold-breach notifications.
```json
{
  "userId": "string (reference)",
  "type": "fall_detected | high_hr | low_temp",
  "status": "active | resolved | dismissed",
  "resolvedBy": "string (reference)",
  "createdAt": "timestamp"
}
```
