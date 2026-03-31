---
description: FCM Push Notification Workflows
---

# FCM Push Notification Workflows

This document outlines the system architecture, triggers, and payload structures for the Firebase Cloud Messaging (FCM) push notification system.

## 1. Token-Based Notification Logic
- **Token Storage**: In the Flutter application, `FirebaseMessaging.instance.getToken()` fetches the device FCM token.
- **Database Entry**: This token is stored in the `users` collection against the authenticated user's `uid`: `users/{uid} -> { fcmToken: "..." }`.
- **Targeting**: When a Cloud Function triggers, it queries the `users` collection by checking `uid` (direct) or `role` (broadcast) to gather target device tokens.
- **Delivery**: Tokens are passed to `admin.messaging().sendToDevice(tokens, payload, options)`, which handles high-priority system notifications.

## 2. Workflows & Triggers

### Scenario 1: Event Creation Approval
**Trigger:** `functions.firestore.document('events/{eventId}').onCreate(...)`
**Condition:** `status == 'pending'`
**Action:** Fetch tokens where `role == 'FACULTY'`
**Payload:**
```json
{
  "notification": {
    "title": "New Event Approval Required",
    "body": "A new event has been created and needs your approval."
  },
  "data": {
    "type": "approval_request",
    "screen": "event_approval"
  }
}
```

### Scenario 2: Event Approved
**Trigger:** `functions.firestore.document('events/{eventId}').onUpdate(...)`
**Condition:** `before.status == 'pending'` AND `after.status == 'approved'`
**Action:** Fetch token for `after.coordinatorId`
**Payload:**
```json
{
  "notification": {
    "title": "Event Approved",
    "body": "Your event has been approved successfully."
  },
  "data": {
    "type": "approval_success",
    "screen": "event_details"
  }
}
```

### Scenario 3: Event Started
**Trigger:** `functions.firestore.document('events/{eventId}').onUpdate(...)`
**Condition:** `before.status != 'ongoing'` AND `after.status == 'ongoing'`
**Action:** Fetch tokens for students registered to this `eventId`.
**Payload:**
```json
{
  "notification": {
    "title": "Event Started",
    "body": "Your registered event has started. Join now!"
  },
  "data": {
    "type": "event_start",
    "screen": "live_event"
  }
}
```

### Scenario 4: Certificate Verification Required
**Trigger:** `functions.firestore.document('certificates/{certId}').onCreate(...)` 
**Condition:** `status == 'pending'`
**Action:** Fetch tokens where `role == 'FACULTY'`
**Payload:**
```json
{
  "notification": {
    "title": "Certificate Verification Required",
    "body": "A certificate is waiting for your verification."
  },
  "data": {
    "type": "certificate_pending",
    "screen": "verification_page"
  }
}
```

### Scenario 5: Certificate Verified
**Trigger:** `functions.firestore.document('certificates/{certId}').onUpdate(...)`
**Condition:** `before.status == 'pending'` AND `after.status == 'verified'`
**Action:** Fetch token for `after.coordinatorId`
**Payload:**
```json
{
  "notification": {
    "title": "Certificate Verified",
    "body": "Your certificate has been verified."
  },
  "data": {
    "type": "certificate_done",
    "screen": "certificates"
  }
}
```

### Scenario 6: Team Invitation
**Trigger:** `functions.firestore.document('registrations/{regId}').onCreate(...)`
**Condition:** `isTeam == true`
**Action:** Fetch tokens for all users in `teammates` array.
**Payload:**
```json
{
  "notification": {
    "title": "Team Invitation",
    "body": "You have been invited to join a team event."
  },
  "data": {
    "type": "team_invite",
    "screen": "team_invite"
  }
}
```

## 3. High-Priority FCM Options
When wrapping `sendToDevice()`, we enforce maximum delivery priority so notifications arrive even when the phone is locked or the app is killed:
```js
const options = {
  priority: "high",
  timeToLive: 60 * 60 * 24
};
await admin.messaging().sendToDevice(tokens, payload, options);
```
