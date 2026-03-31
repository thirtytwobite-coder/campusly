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
async function getTokensByRole(role, college = null) {
  let query = admin.firestore().collection('users').where('role', '==', role.toUpperCase());
  if (college && String(college).trim().length > 0) {
    query = query.where('college', '==', String(college).toUpperCase());
  }
  const usersSnap = await query.get();
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

// =========================================================================
// NEW FCM NOTIFICATION TRIGGERS (Requested Scenarios)
// =========================================================================

// Scenario 1: When a Club Coordinator creates an event -> Send notification to Club Faculty
exports.notifyOnEventCreated = functions.firestore
  .document('events/{eventId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    if (String(data.status).toLowerCase() !== 'pending') return null;

    const payload = {
      notification: {
        title: 'New Event Approval Required',
        body: 'A new event has been created and needs your approval.',
      },
      data: {
        type: 'approval_request',
        screen: 'event_approval',
      },
    };

    const tokens = await getTokensByRole('FACULTY');
    if (tokens.length === 0) return null;
    try {
      await admin.messaging().sendToDevice(tokens, payload, { priority: 'high', timeToLive: 86400 });
    } catch (e) {
      console.error('Error sending approval request FCM', e);
    }

    return snap.ref.update({ pendingNotified: true });
  });

// Scenario 2 & 3: When Faculty approves event OR Club Coordinator starts event
exports.notifyOnEventStatusChange = functions.firestore
  .document('events/{eventId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.status === after.status) return null;

    const newStatus = String(after.status).toLowerCase();
    const oldStatus = String(before.status).toLowerCase();

    // Scenario 2: Event Approved -> Send notification to Club Coordinator
    if (newStatus === 'approved' && oldStatus === 'pending') {
      const coordId = after.createdBy || after.coordinatorId;
      if (coordId) {
        const token = await getTokenByUid(coordId);
        if (token) {
          const payload = {
            notification: {
              title: 'Event Approved',
              body: 'Your event has been approved successfully.',
            },
            data: {
              type: 'approval_success',
              screen: 'event_details',
            },
          };
          await admin.messaging().sendToDevice([token], payload, { priority: 'high', timeToLive: 86400 });
        }
      }
    } 
    // Scenario 3: Event Started -> Send notification to all registered students
    else if (newStatus === 'ongoing' && oldStatus !== 'ongoing') {
      const registrationsSnap = await admin.firestore().collection('registrations')
        .where('eventId', '==', context.params.eventId)
        .get();
      
      const userIds = new Set();
      registrationsSnap.forEach(doc => {
        if (doc.data().userId) userIds.add(doc.data().userId);
      });

      const tokens = [];
      for (const uid of userIds) {
        const t = await getTokenByUid(uid);
        if (t) tokens.push(t);
      }

      if (tokens.length > 0) {
        const payload = {
          notification: {
            title: 'Event Started',
            body: 'Your registered event has started. Join now!',
          },
          data: {
            type: 'event_start',
            screen: 'live_event',
          },
        };
        await admin.messaging().sendToDevice(tokens, payload, { priority: 'high', timeToLive: 86400 });
      }
    }

    return null;
  });

// Scenario 4: When Coordinator sends certificate for verification -> Send notification to Main Faculty
exports.notifyOnCertificatePending = functions.firestore
  .document('certificate_approvals/{certId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    if (data.status !== 'pending') return null;

    const clubDoc = await admin.firestore().collection('clubs').doc(data.clubId).get();
    let college = null;
    if (clubDoc.exists) {
      const clubData = clubDoc.data() || {};
      college = clubData.college || clubData.collegeCode || null;
    }

    const payload = {
      notification: {
        title: 'Certificate Verification Required',
        body: 'A certificate is waiting for your verification.',
      },
      data: {
        type: 'certificate_pending',
        screen: 'verification_page',
      },
    };

    const tokens = await getTokensByRole('MAIN FACULTY', college);
    if (tokens.length > 0) {
      await admin.messaging().sendToDevice(tokens, payload, { priority: 'high', timeToLive: 86400 });
    }
    return null;
  });

// Scenario 5: When Faculty verifies certificate -> Send notification to Club Coordinator
exports.notifyOnCertificateVerified = functions.firestore
  .document('certificate_approvals/{certId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    
    // Status can change to 'approved' or 'verified' when faculty verifies
    if (before.status === 'pending' && (after.status === 'approved' || after.status === 'verified')) {
      const clubId = after.clubId;
      let targetTokens = [];
      
      if (clubId) {
        const clubDoc = await admin.firestore().collection('clubs').doc(clubId).get();
        if (clubDoc.exists && clubDoc.data().coordinatorId) {
          const token = await getTokenByUid(clubDoc.data().coordinatorId);
          if (token) targetTokens.push(token);
        }
      }
      
      if (targetTokens.length === 0 && after.requestedById) {
         const t = await getTokenByUid(after.requestedById);
         if (t) targetTokens.push(t);
      }
      
      if (targetTokens.length > 0) {
        const payload = {
          notification: {
            title: 'Certificate Verified',
            body: 'Your certificate has been verified.',
          },
          data: {
            type: 'certificate_done',
            screen: 'certificates',
          },
        };
        await admin.messaging().sendToDevice(targetTokens, payload, { priority: 'high', timeToLive: 86400 });
      }
    }
    return null;
  });

// Scenario 6: When a student registers for a team event -> Send notification to all selected teammates
exports.notifyOnTeamInvite = functions.firestore
  .document('registrations/{regId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    
    // In our logic, 'isTeamLeader: false' and 'status: pending' denotes a team invite.
    if (data.isTeamLeader === false && data.status === 'pending' && data.teamId && data.userId) {
       const token = await getTokenByUid(data.userId);
       if (token) {
         const payload = {
           notification: {
             title: 'Team Invitation',
             body: 'You have been invited to join a team event.',
           },
           data: {
             type: 'team_invite',
             screen: 'team_invite',
           },
         };
         await admin.messaging().sendToDevice([token], payload, { priority: 'high', timeToLive: 86400 });
       }
    }
    return null;
  });


// =========================================================================
// LEGACY TRIGGERS AND SMS NOTIFICATIONS
// =========================================================================

exports.notifyOnStudentNotification = functions.firestore
  .document('student/{studentId}/notifications/{notifyId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const studentId = context.params.studentId;
    const token = await getTokenByUid(studentId);
    if (!token) return null;

    const payload = {
      notification: {
        title: data.title || 'New Notification',
        body: data.message || data.body || 'You have a new message.',
      },
      data: {
        type: data.type || 'STUDENT_NOTIFICATION',
        eventId: data.eventId || '',
        regId: data.regId || '',
      },
    };

    try {
      await admin.messaging().sendToDevice(token, payload, { priority: 'high' });
    } catch (e) {
      console.error('Error sending student notification FCM', e);
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

exports.notifyOnClubNotification = functions.firestore
  .document('clubs/{clubId}/notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const clubId = context.params.clubId;

    const clubDoc = await admin.firestore().collection('clubs').doc(clubId).get();
    if (!clubDoc.exists) return null;
    
    const clubData = clubDoc.data();
    let targetTokens = [];

    if (clubData.coordinatorId) {
      const token = await getTokenByUid(clubData.coordinatorId);
      if (token) targetTokens.push(token);
    }

    if (targetTokens.length === 0) return null;

    const payload = {
      notification: {
        title: data.title || 'Club Update',
        body: data.message || data.body || 'You have a new notification for your club.',
      },
      data: {
        type: data.type || 'club_notification',
      },
    };

    try {
      await admin.messaging().sendToDevice(targetTokens, payload, { priority: 'high' });
    } catch (e) {
      console.error('FCM send failed for club notification', e);
    }
    return null;
  });
