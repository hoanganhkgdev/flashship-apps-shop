# Flashship Shop App

Partner-shop mobile application for **Flashship**, a multi-service local delivery and on-demand services platform.

The Shop App gives business partners a dedicated interface for managing delivery operations and connects to Flashship's Laravel backend, Firebase realtime infrastructure, and location services.

## Product Overview

Flashship is built as a multi-role ecosystem with separate applications for customers, drivers, shops, and internal operations.

The Shop App focuses on merchant workflows, allowing partner shops to work with delivery orders through a dedicated mobile experience while staying synchronized with the broader Flashship platform.

## Tech Stack

- Flutter / Dart
- Riverpod — state management
- GoRouter — navigation
- Dio — REST API networking
- Google Maps Flutter
- Geolocator
- Firebase Core
- Firebase Cloud Messaging
- Firebase Realtime Database
- Shared Preferences
- Flutter Secure Storage
- Local Authentication
- Crypto
- Device Info Plus
- WebView Flutter
- Image Picker

## Application Architecture

```text
Shop App (Flutter)
      │
      ├── REST API ─────────► Laravel Backend
      │                        ├── Authentication
      │                        ├── Shop
      │                        ├── Orders
      │                        ├── Pricing
      │                        └── Core Services
      │
      ├── Firebase Realtime ► Operational updates
      │
      ├── FCM ──────────────► Push notifications
      │
      └── Maps / GPS ───────► Location-based workflows
```

## Key Engineering Areas

This project demonstrates mobile development across:

- REST API integration using Dio
- Riverpod-based application state
- Declarative routing with GoRouter
- Merchant and delivery-order workflows
- Firebase Cloud Messaging
- Firebase Realtime Database integration
- Google Maps and device location
- Runtime location handling
- Secure local storage
- Local device authentication
- Device-aware functionality
- WebView and external URL workflows
- Android and iOS development

## Security-Oriented Capabilities

The application includes packages for secure local storage, local authentication, cryptographic utilities, and device information. These capabilities support security-sensitive merchant workflows while keeping credentials and environment-specific secrets outside source control.

## Flashship Ecosystem

- **Customer App** — creates and manages service orders
- **Driver App** — receives and processes delivery jobs
- **Shop App** — supports partner-shop delivery operations
- **Laravel Backend** — APIs, authentication, orders, pricing, permissions, payments, and integrations
- **Admin Platform** — internal operations and management

## Getting Started

### Requirements

- Flutter SDK compatible with Dart `^3.6.0`
- Android Studio and/or Xcode
- Configured Firebase project
- Google Maps credentials
- Access to the Flashship backend API

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Analyze

```bash
flutter analyze
```

### Test

```bash
flutter test
```

## Configuration & Security

Production API credentials, Firebase configuration, signing credentials, keys, and other sensitive environment-specific values should not be committed to source control.

## Project Context

Flashship Shop is an actively developed real-world merchant application. It forms part of a larger delivery ecosystem and integrates mobile UI, backend APIs, realtime data, notifications, maps, device capabilities, and security-oriented local storage.

---

**Flashship** — Local delivery and on-demand services platform.
