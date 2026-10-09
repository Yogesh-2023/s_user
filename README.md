# taxify

A new Flutter project.

## API configuration

The customer API base URL is supplied at build/run time. For the Postman
backend running locally on port 3000, an Android emulator can connect with:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

For a deployed backend, replace the value with its HTTPS origin. Do not append
`/api/v1/customer`; endpoint paths are added by the app.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
