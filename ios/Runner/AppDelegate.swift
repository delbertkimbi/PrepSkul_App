import Flutter
import UIKit
// TODO: Uncomment when Google Maps API key is configured
// import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // TODO: Initialize Google Maps when API key is configured
    // Replace YOUR_GOOGLE_MAPS_API_KEY with your actual API key from Google Cloud Console
    // Get your key at: https://console.cloud.google.com/google/maps-apis/credentials
    // GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}