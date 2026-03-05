const functions = require('firebase-functions');
const admin = require('firebase-admin');
const dotenv = require('dotenv');
const twilio = require('twilio');

dotenv.config();
admin.initializeApp();

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const fromNumber = process.env.TWILIO_FROM_NUMBER;

if (!accountSid || !authToken || !fromNumber) {
  console.warn('Twilio credentials are missing. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER in functions/.env');
}

const twilioClient = accountSid && authToken ? twilio(accountSid, authToken) : null;

function normalizePhone(phone) {
  if (!phone) return null;
  const digits = String(phone).replace(/\D/g, '');
  if (digits.length < 10) return null;
  // Assumes India numbers without country code, adjust if needed
  if (digits.length === 10) return `+91${digits}`;
  if (digits.startsWith('91') && digits.length === 12) return `+${digits}`;
  if (digits.startsWith('1') && digits.length === 11) return `+${digits}`;
  if (digits.startsWith('+')) return digits;
  return `+${digits}`;
}

async function sendSms(to, body) {
  if (!twilioClient) return;
  await twilioClient.messages.create({
    to,
    from: fromNumber,
    body,
  });
}

// --------- helper functions for FCM tokens ---------
async function getTokensByRole(role) {
  const usersSnap = await admin.firestore().collection('users').where('role', '==', role).get();
  const tokens = [];
  usersSnap.forEach(doc => {
    const t = doc.data().fcmToken;
    if (t) tokens.push(t);
  });
  return tokens;
}

async function getTokenByUid(uid) {
  const doc = await admin.firestore().collection('users').doc(uid).get();
  if (!doc.exists) return null;
  return doc.data().fcmToken || null;
}

// ---------- new notification triggers ----------

// When a global event document is created and status is pending,
// notify all faculties that an approval request has arrived.
exports.notifyOnEventCreated = functions.firestore
  .document('events/{eventId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    if (String(data.status).toLowerCase() !== 'pending') return null;

    const title = data.title || data.name || 'New Event';
    const payload = {
      notification: {
        title: 'New Event Approval Request',
        body: `A new event '${title}' has been created. Please review and approve.`,
      },
      data: {
        type: 'EVENT_APPROVAL_REQUEST',
        eventId: context.params.eventId,
      },
    };

    const tokens = await getTokensByRole('FACULTY');
    if (tokens.length === 0) return null;
    try {
      await admin.messaging().sendToDevice(tokens, payload);
    } catch (e) {
      console.error('Error sending approval request FCM', e);
    }

    // mark that we notified so duplicates are avoided on re-create
    return snap.ref.update({ pendingNotified: true });
  });

// When event document updates status, send targeted notifications.
exports.notifyOnEventStatusChange = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.status === after.status) return null;

    const newStatus = String(after.status).toLowerCase();
    let payload = null;
    let targetTokens = [];

    if (newStatus === 'approved') {
      // notify only the coordinator who created the event
      const coordId = after.createdBy || after.coordinatorId;
      if (coordId) {
        const token = await getTokenByUid(coordId);
        if (token) targetTokens.push(token);
      }
      payload = {
        notification: {
          title: 'Event Approved',
          body: `Your event '${after.title || ''}' has been approved.`,
        },
        data: {
          type: 'EVENT_APPROVED',
          eventId: context.params.eventId,
        },
      };
    } else if (newStatus === 'ongoing') {
      // send to all students when event goes live/ongoing
      targetTokens = await getTokensByRole('STUDENT');
      payload = {
        notification: {
          title: 'Event Registration Open',
          body: `Registration for '${after.title || ''}' is now open. Register now!`,
        },
        data: {
          type: 'EVENT_REGISTRATION_OPEN',
          eventId: context.params.eventId,
        },
      };
    }

    if (payload && targetTokens.length) {
      try {
        await admin.messaging().sendToDevice(targetTokens, payload);
      } catch (e) {
        console.error('Error sending status-change FCM', e);
      }
    }

    return null;
  });

exports.sendSmsOnEventApproved = functions.firestore
  .document('events/{eventId}')
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const status = String(data.status || 'approved').toLowerCase();
    if (status !== 'approved') return null;

    const title = data.title || data.name || 'New Event';
    const date = data.date || 'TBD';
    const time = data.time || 'TBD';
    const visibility = String(data.visibility || 'college').toLowerCase();
    const college = data.college || 'Unknown';

    const message = visibility === 'public'
      ? `New public event approved: ${title}. ${date} ${time}.`
      : `New event approved for ${college}: ${title}. ${date} ${time}.`;

    const db = admin.firestore();
    let query = db.collection('student')
      .where('role', '==', 'Student')
      .where('isActive', '==', true)
      .where('smsOptIn', '==', true);

    if (visibility !== 'public') {
      query = query.where('college', '==', college);
    }

    const studentsSnap = await query.get();
    if (studentsSnap.empty) return null;

    for (const doc of studentsSnap.docs) {
      const student = doc.data();
      const normalized = normalizePhone(student.phone);
      if (!normalized) continue;
      try {
        await sendSms(normalized, message);
      } catch (e) {
        console.error(`Failed to send SMS to ${normalized}`, e);
      }
    }

    await snap.ref.update({
      smsNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      smsNotificationCount: studentsSnap.size,
    });

    return null;
  });

exports.sendPushOnEventApproved = functions.firestore
  .document('events/{eventId}')
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const status = String(data.status || 'approved').toLowerCase();
    if (status !== 'approved') return null;

    const title = data.title || data.name || 'New Event';
    const date = data.date || 'TBD';
    const time = data.time || 'TBD';
    const visibility = String(data.visibility || 'college').toLowerCase();
    const college = String(data.college || 'general');

    const payload = {
      notification: {
        title: 'New Event Approved',
        body: `${title} • ${date} ${time}`,
      },
      data: {
        eventId: snap.id,
        visibility,
        college,
      },
    };

    const slug = college
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');

    const topic = visibility === 'public' ? 'events_public' : `events_college_${slug}`;

    try {
      await admin.messaging().sendToTopic(topic, payload);
    } catch (e) {
      console.error('FCM send failed', e);
    }

    return null;
  });
