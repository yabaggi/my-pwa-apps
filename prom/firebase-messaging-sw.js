// firebase-messaging-sw.js

// 1. Import the compatibility SDKs
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// 2. Initialize (Must match your index.html config)
firebase.initializeApp({
    apiKey: "AIzaSyCnRiWaq8gIRvPvnV5mTW6elJBFAol2vg8",
    authDomain: "books-library-b70cf.firebaseapp.com",
    projectId: "books-library-b70cf",
    storageBucket: "books-library-b70cf.firebasestorage.app",
    messagingSenderId: "903495800021",
    appId: "1:903495800021:web:a7e5d7e63579208445be5c" 
});

const messaging = firebase.messaging();

// 3. THE FIX: Handle the background message
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Customize notification here
  const notificationTitle = payload.notification.title || "New Message";
  const notificationOptions = {
    body: payload.notification.body || "You have a new update.",
    icon: '/prom/icons/icon-192x192.png', // Ensure this path is correct!
    badge: '/prom/icons/icon-72x72.png'
  };

  // This line is what replaces the "Site updated in background" message
  return self.registration.showNotification(notificationTitle, notificationOptions);
});