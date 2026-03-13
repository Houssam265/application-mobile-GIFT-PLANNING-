# 🎁 GiftPlan

**GiftPlan** is a collaborative mobile application built with **Flutter** and **Supabase**. It is designed to help users seamlessly organize group gifts for events (birthdays, weddings, farewell parties). Users can create shared gift lists, add products with target prices, and allow invited friends to contribute money collaboratively towards those goals.

## 🚀 Features (Current Status)

### 🔐 Authentication
*   User registration, login, and password reset.
*   Secure authentication managed via Supabase Auth.

### 📋 List Management
*   **Create & Customize:** Create lists for specific events, add descriptions, and set an event date via calendar pickers.
*   **Cover Images:** Upload custom cover images for your lists, securely stored in Supabase Storage.
*   **Lifecycle Management:** Archive inactive lists, reactivate them with new dates, or permanently delete them securely, which cleans up all associated storage and database properties.

### 🛍️ Product Management
*   **Add Products:** Add desired products to lists including detailed info: Name, Description, Category, Target Price, and Web links.
*   **Product Formatting:** Enhance visual appeal by uploading pictures for individual products.
*   **Real-time Funding Status:** View beautiful, real-time progress bars scaling dynamically based on collaborative contributions from the database using Supabase Streams.

## 🛠️ Technology Stack

*   **Frontend Mobile**: [Flutter](https://flutter.dev/) (Dart)
*   **State Management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
*   **Routing**: `go_router` for deep linking and safe navigation
*   **Backend as a Service (BaaS)**: [Supabase](https://supabase.com/)
    *   **Database**: PostgreSQL
    *   **Authentification**: Supabase Auth
    *   **Storage**: Supabase Storage Buckets
    *   **Real-time**: Supabase Streams

## ⚙️ Getting Started

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
*   A running emulator or a connected physical mobile device.
*   An active **Supabase** project configured with the correct database schema.

### Installation

1. Clone the repository:
   ```bash
   git clone <repository_url>
   ```

2. Navigate to the project directory:
   ```bash
   cd Projet
   ```

3. Fetch dependencies:
   ```bash
   flutter pub get
   ```

4. Configuration: Ensure you have your `Supabase URL` and `Anon Key` correctly mapped into your constants/environment configurations inside `lib/core/constants/supabase_constants.dart`.

5. Run the app:
   ```bash
   flutter run
   ```
