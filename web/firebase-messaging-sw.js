// Give the service worker access to Firebase Messaging.
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker.
// These values should match your Firebase Project settings.
firebase.initializeApp({
  apiKey: "AIzaSyBrUXM3S7brLueu4W4L68Yl7j4anmCtp0A",
  authDomain: "collegeeventmanager-b3211.firebaseapp.com",
  projectId: "collegeeventmanager-b3211",
  storageBucket: "collegeeventmanager-b3211.firebasestorage.app",
  messagingSenderId: "750597681838",
  appId: "1:750597681838:web:da08e3dc488842d5a6b33f", // Note: Ensure this matches your Web App ID
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title || 'New Dashboard Update';
  const notificationOptions = {
    body: payload.notification.body || 'A new activity was added',
    icon: '/favicon.png', // Default icon
    tag: 'dashboard-update', // Stacks/groups notifications
    data: payload.data, // Custom data for redirection
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click to open the app
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      if (clientList.length > 0) {
        let client = clientList[0];
        for (let i = 0; i < clientList.length; i++) {
          if (clientList[i].focused) {
            client = clientList[i];
          }
        }
        return client.focus();
      }
      return clients.openWindow('/'); // Relative path to open your app
    })
  );
});
