// Firebase Cloud Messaging Service Worker
// This file is required for FCM push notifications on web

// Import Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Firebase configuration (will be injected by FlutterFire)
// For now, use a placeholder - FlutterFire will inject the actual config
const firebaseConfig = {
  apiKey: "AIzaSyD1UWKHuEPDn81zVjS3zVmfeuLiz2-Sy0g",
  appId: "1:613507205446:web:4273277c53d8416313fd47",
  messagingSenderId: "613507205446",
  projectId: "operating-axis-420213",
  authDomain: "operating-axis-420213.firebaseapp.com",
  storageBucket: "operating-axis-420213.firebasestorage.app",
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Customize notification here
  const notificationTitle = payload.notification?.title || 'PrepSkul';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new message',
    icon: '/app_logo(blue).png',
    badge: '/app_logo(blue).png',
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});


