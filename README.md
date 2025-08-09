# FarmSense AI

## Description

FarmSense AI is a comprehensive Flutter-based mobile application designed to be a smart farming companion. It leverages the power of Artificial Intelligence, specifically Google's Gemini API, to provide farmers with actionable insights and tools to manage their farms effectively. The app allows users to monitor their plants, get AI-powered advice, analyze plant health, receive weather-based suggestions, discover government schemes, and even participate in a community marketplace to buy and sell produce.

-----

## Key Features

  * **User Authentication**: Secure sign-up and login functionality using Firebase Authentication.
  * **Plant Management**: Add, edit, and delete plants from your farm's portfolio.
  * **AI Farm Advisor**: A chat interface to communicate with an AI assistant that can answer farming-related questions based on your farm's context.
  * **Image Analysis**: Upload photos of your plants to get insights and analysis from the AI.
  * **Diary**: Keep a personal farm diary to record thoughts, observations, and plans. The AI can also use these entries to provide more personalized advice.
  * **Plant Dashboard**: A dedicated dashboard for each plant that provides:
      * **Live Sensor Data**: View real-time data from your sensors for temperature, humidity, soil moisture, and light levels.
      * **AI Health Status**: Get an AI-generated health status of your plant.
      * **Weather Advisory**: Receive weather-based suggestions for your plants.
      * **Government Schemes**: Discover relevant government agricultural schemes.
      * **Market Trends**: Get an analysis of the market trends for your crops.
  * **Supply Recommendations**: Get AI-powered recommendations for products like fertilizers and pesticides.
  * **Social Market**:
      * **My Farm Stand**: Manage your own produce listings.
      * **Community Market**: Browse and view produce listings from other farmers in the community.

-----

## Screenshots

-----

## Technologies Used

  * **Frontend**: Flutter
  * **Backend**: Firebase (Authentication, Firestore)
  * **AI**: Google Gemini API
  * **State Management**: `StatefulWidget` and `StreamBuilder`
  * **Routing**: `MaterialPageRoute`
  * **HTTP Requests**: `http` package
  * **Location Services**: `geolocator` package
  * **Image Picking**: `image_picker` package

-----

## Setup Instructions

To get the FarmSense AI application up and running on your local machine, follow these steps:

### **1. Prerequisites**

  * **Flutter**: Make sure you have the Flutter SDK installed on your system. You can find the installation instructions on the [official Flutter website](https://flutter.dev/docs/get-started/install).
  * **Firebase Project**: You will need a Firebase project. If you don't have one, create a new project on the [Firebase Console](https://console.firebase.google.com/).
  * **Gemini API Key**: You'll need an API key for the Gemini API. You can get one from the [Google AI for Developers](https://ai.google.dev/) website.
  * **OpenWeatherMap API Key**: You need an API key from [OpenWeatherMap](https://openweathermap.org/api) to fetch weather data.

### **2. Clone the Repository**

```bash
git clone https://your-repository-url.com/farmsense-ai.git
cd farmsense-ai
```

### **3. Configure Firebase**

1.  **Android Setup**:
      * In the Firebase Console, add a new Android app to your project.
      * Follow the on-screen instructions to register your app. You will need the package name, which is `com.example.farmsense_ai` unless you've changed it.
      * Download the `google-services.json` file and place it in the `android/app` directory of your Flutter project.
2.  **Web and Windows Setup**:
      * The provided `lib/firebase_options.dart` file already contains configurations for web and Windows. You will need to replace the placeholder values with your actual Firebase project credentials.

### **4. Add API Keys**

Open the `lib/app_config.dart` file and replace the placeholder API keys with your actual keys:

```dart
class ApiKeys {
  static const String geminiApiKey = "YOUR_GEMINI_API_KEY";
  static const String openWeatherApiKey = "YOUR_OPENWEATHERMAP_API_KEY";
}
```

### **5. Install Dependencies**

Run the following command in your project's root directory to install all the required dependencies:

```bash
flutter pub get
```

### **6. Run the Application**

You can now run the application on your desired emulator or physical device:

```bash
flutter run
```

-----

## Project Structure

The project follows a feature-based structure, with each major feature having its own dedicated file in the `lib` directory.

```
lib/
├── main.dart                   # App entry point, main screens, and services
├── ai_chat_feature.dart        # AI Farm Advisor chat screen and widgets
├── app_config.dart             # App configuration, including API keys
├── diary_feature.dart          # Diary screen, add/edit entry, and diary chat
├── firebase_options.dart       # Firebase configuration
├── gemini_service.dart         # Service for interacting with the Gemini API
├── plant_dashboard_screen.dart # Plant-specific dashboard and AI companion chat
└── social_market.dart          # Marketplace screens for buying and selling produce
```
## Credits 
- Concept & UI Design [Jatin Solanki](https://github.com/Solanki-Jatin)
