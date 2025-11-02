# Drug Tracker

A Flutter mobile application for tracking medication intake. Record and manage your drug intake with timestamps and dosages for multiple medications.

## Features

- **Multiple Drug Support**: Track three medications (Diazepam, Doxylamide, Zolpidem)
- **Date & Time Tracking**: Record exactly when each dose was taken
- **Dosage Tracking**: Log precise dosage amounts (in mg)
- **Local Storage**: Data persisted locally using SQLite
- **Clean Interface**: Modern Material Design UI with intuitive navigation
- **Delete Records**: Remove unwanted entries with confirmation

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Architecture

- **Models**: `DrugRecord` - Data model for medication entries
- **Database**: SQLite for local persistence (PostgreSQL-ready schema)
- **Screens**: Main list view and add record form
- **Widgets**: Reusable UI components

## Future Enhancements

- Cloud sync with PostgreSQL database
- Statistics and charts
- Reminder notifications
- Multiple device support

## Getting Help

For help with Flutter development, visit:
- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
