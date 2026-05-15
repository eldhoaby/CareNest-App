# 📱 Mobile App Workflow

The CareNest Flutter application serves two primary user personas, each with a distinct workflow.

## 🧓 The Elderly Persona

The interface for the elderly is designed with accessibility in mind—large fonts, high contrast, and simplified navigation.

1. **Dashboard:** Displays current environmental stats (room temperature) and personal vitals (if wearables are connected).
2. **SOS Button:** A prominent, persistent panic button. Holding it for 3 seconds bypasses all thresholds and instantly triggers an emergency workflow, notifying all linked caregivers.
3. **Routine Reminders:** Simple push notifications for medication and daily check-ins.

## 👩‍⚕️ The Caregiver Persona

The interface for caregivers is data-rich and action-oriented.

1. **Overview List:** View all assigned elderly patients and their current status (Green = OK, Red = Alert).
2. **Detail View:** Drill down into a specific patient to view real-time sensor graphs and historical logs.
3. **Alert Management:** Receive push notifications for threshold breaches (e.g., heart rate > 120 bpm, or fall detected). Acknowledge and resolve alerts to log the intervention in the database.
