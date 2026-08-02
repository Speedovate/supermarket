# Andrew's Supermarket MVP

A responsive Flutter Web MVP for Andrew's Supermarket, designed for sari-sari store owners who submit product order requests and for admins who review, quote, and manage those requests.

## What is included

- Public customer catalog with search, category filtering, local cart persistence, order review, and order request submission
- Secured admin area with login, dashboard, product management, category management, order management, and settings
- MVVM-oriented Flutter structure using Riverpod
- Material 3 UI based on the blue, red, white, and navy brand direction from the provided reference
- Firestore, Storage, and Hosting configuration files for Firebase deployment
- Sample seed data and documented Firestore model expectations

## Architecture

The project is organized around MVVM:

- `Model`
  - Core domain models live in [lib/core/models/app_models.dart](/Users/adrycallencatapang/StudioProjects/supermarket/lib/core/models/app_models.dart:1)
- `View`
  - Screens and reusable UI widgets live under each feature's `presentation/` folder
- `ViewModel`
  - Feature view models expose state to the UI, for example:
    - [lib/features/catalog/presentation/catalog_view_model.dart](/Users/adrycallencatapang/StudioProjects/supermarket/lib/features/catalog/presentation/catalog_view_model.dart:1)
    - [lib/features/cart/presentation/cart_view_model.dart](/Users/adrycallencatapang/StudioProjects/supermarket/lib/features/cart/presentation/cart_view_model.dart:1)
    - [lib/features/admin_dashboard/presentation/admin_dashboard_view_model.dart](/Users/adrycallencatapang/StudioProjects/supermarket/lib/features/admin_dashboard/presentation/admin_dashboard_view_model.dart:1)
- `State / data coordination`
  - [lib/features/app_state/app_controller.dart](/Users/adrycallencatapang/StudioProjects/supermarket/lib/features/app_state/app_controller.dart:1) currently acts as the shared app store and mutation layer for the MVP
  - For production Firebase rollout, replace or split these mutations into repositories and Firebase-backed data sources while keeping the existing view models stable

## Current runtime mode

The app currently runs in a local demo mode so it works immediately without Firebase credentials.

- Cart, products, categories, orders, and settings persist locally via `shared_preferences`
- Admin login uses demo credentials by default:
  - Email: `admin@andrews.local`
  - Password: `Admin123!`
- Firebase deployment artifacts are included, but FlutterFire-generated runtime config is still expected before production use

This gives you a functional MVP shell while keeping the structure ready for Firebase-backed repositories.

## Flutter setup

1. Install Flutter `3.41.x` or newer with Dart `3.11.x`
2. Run:

```bash
flutter pub get
```

3. Start the app locally:

```bash
flutter run -d chrome
```

## Firebase project setup

1. Create a Firebase project
2. Enable:
   - Authentication
   - Cloud Firestore
   - Cloud Storage
   - Firebase Hosting
3. In Authentication, enable Email/Password sign-in
4. Create an admin record in Firestore:

```text
admins/{uid}
{
  "email": "your-admin@email.com",
  "displayName": "Andrew Admin"
}
```

5. Apply the included config files:
   - [firestore.rules](/Users/adrycallencatapang/StudioProjects/supermarket/firestore.rules:1)
   - [storage.rules](/Users/adrycallencatapang/StudioProjects/supermarket/storage.rules:1)
   - [firestore.indexes.json](/Users/adrycallencatapang/StudioProjects/supermarket/firestore.indexes.json:1)
   - [firebase.json](/Users/adrycallencatapang/StudioProjects/supermarket/firebase.json:1)

## Firebase CLI setup

1. Install the Firebase CLI
2. Log in:

```bash
firebase login
```

3. Initialize or connect the project:

```bash
firebase use --add
```

## FlutterFire configuration

This repo does not yet include generated FlutterFire runtime files. Before switching from demo mode to live Firebase mode:

1. Install FlutterFire CLI
2. Run:

```bash
flutterfire configure
```

3. Add the generated `firebase_options.dart`
4. Replace the local persistence implementation in [lib/features/app_state/app_controller.dart](/Users/adrycallencatapang/StudioProjects/supermarket/lib/features/app_state/app_controller.dart:1) with Firebase repositories for:
   - auth
   - categories
   - products
   - orders
   - settings
5. Keep the existing view models and views, so the MVVM boundary remains stable

## Running locally

```bash
flutter run -d chrome
```

## Build for web

```bash
flutter build web
```

## Deploy to Firebase Hosting

```bash
firebase deploy --only hosting
```

## Enabling Best Sellers

In the current MVP:

1. Sign in to `/admin/login`
2. Open `/admin/settings`
3. Enable `Best Sellers`
4. Set the item limit
5. Move orders into valid statuses like `confirmed`, `preparing`, `ready_for_pickup`, `out_for_delivery`, or `completed`

The public homepage will keep the Best Sellers section fully hidden until both of these are true:

- `bestSellersEnabled` is on
- at least one product has valid ranked order data

## Seed data

Sample categories and products are bundled in:

- [assets/data/sample_seed.json](/Users/adrycallencatapang/StudioProjects/supermarket/assets/data/sample_seed.json:1)
- [lib/core/constants/sample_data.dart](/Users/adrycallencatapang/StudioProjects/supermarket/lib/core/constants/sample_data.dart:1)

## Quality checks

Run:

```bash
dart format lib test
flutter analyze
flutter test
```

## Known MVP limitations

- Runtime data is still local-first and not yet connected to live Firebase collections
- Admin login is demo-only until FlutterFire auth is wired in
- Product photo upload UI is not yet connected to Firebase Storage
- The admin dashboard uses compact operational tables rather than a fully custom mobile card system for every dataset
- Public product images currently use branded placeholders instead of uploaded image assets
- Order submission currently writes to local persisted state, not Firestore

## Suggested next production steps

1. Add FlutterFire runtime configuration
2. Move the app store mutations into repositories backed by Firestore and Firebase Auth
3. Add Storage-backed product photo upload and replacement
4. Add Cloud Functions or admin transactions for robust Best Seller metric synchronization
5. Tighten Firestore rules alongside repository validation
