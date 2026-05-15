# Architecture Documentation

This folder contains the architectural design documents for CareNest.

## Overview
CareNest leverages a decoupled microservices architecture with real-time data synchronization at its core. 

* **Mobile App:** Built with Flutter, utilizing Provider/Bloc for state management and Firebase for real-time streams.
* **Admin Dashboard:** Built with React, connected via secure API and Firestore snapshot listeners.
* **Backend:** Node.js Express server handling push notifications, complex aggregations, and third-party integrations.

*Please add architecture diagrams (e.g., Mermaid diagrams, Draw.io exports) to this folder to visually represent data flow, database schemas, and component interactions.*
