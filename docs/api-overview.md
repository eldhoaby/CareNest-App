# 🔌 API Overview

This document outlines the RESTful endpoints exposed by the CareNest backend. Note that much of the application's real-time functionality relies directly on Firestore listeners rather than polling these APIs.

## Authentication
Authentication tokens (JWT) must be provided in the `Authorization` header as `Bearer <token>`.

## Core Endpoints

### `POST /api/v1/alerts/trigger`
Used by the IoT bridge to manually trigger an emergency alert when MQTT fails.
- **Body:** `{ "sensorId": "...", "type": "fall", "value": "..." }`

### `GET /api/v1/users/:id/analytics`
Fetches aggregated health data for the React Admin Dashboard, bypassing Firestore limits for complex queries.

### `POST /api/v1/admin/assign-caregiver`
Allows an administrator to link a Caregiver profile to an Elderly profile.
- **Body:** `{ "elderlyId": "...", "caregiverId": "..." }`
