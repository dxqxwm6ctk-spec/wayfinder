import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

admin.initializeApp();

type BookingInput = {
  userId?: string;
  areaId?: string;
  tripSlotId?: string;
};

type BookingValidationResult = {
  ok: boolean;
  message: string;
  bookingId?: string;
  status?: string;
  departureAt?: string;
  cutoffAt?: string;
};

const firestore = admin.firestore();

function normalize(value: unknown): string {
  return String(value ?? '').trim().toLowerCase();
}

function toDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  return null;
}

function readInt(value: unknown, fallback = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  return fallback;
}

function requireString(value: unknown, fieldName: string): string {
  const normalized = String(value ?? '').trim();
  if (!normalized) {
    throw new HttpsError('invalid-argument', `${fieldName} is required.`);
  }
  return normalized;
}

async function validateBookingInput(input: BookingInput): Promise<BookingValidationResult> {
  const userId = requireString(input.userId, 'userId');
  const areaId = requireString(input.areaId, 'areaId');
  const tripSlotId = requireString(input.tripSlotId, 'tripSlotId');

  const slotRef = firestore.collection('tripSlots').doc(tripSlotId);
  const bookingRef = firestore.collection('preBookings').doc(`${tripSlotId}_${userId}`);

  const [slotSnap, bookingSnap] = await Promise.all([slotRef.get(), bookingRef.get()]);

  if (!slotSnap.exists) {
    return { ok: false, message: 'Trip slot not found.' };
  }

  const slotData = slotSnap.data() ?? {};
  const slotAreaId = String(slotData.areaId ?? '').trim();
  if (!slotAreaId || normalize(slotAreaId) !== normalize(areaId)) {
    return { ok: false, message: 'Trip slot does not belong to this area.' };
  }

  if (slotData.active !== true) {
    return { ok: false, message: 'Trip slot is not active.' };
  }

  const departureAt = toDate(slotData.departureAt);
  if (!departureAt) {
    return { ok: false, message: 'Trip slot is missing departure time.' };
  }

  const cutoffMinutes = readInt(slotData.cutoffMinutes, 30);
  const cutoffAt = new Date(departureAt.getTime() - Math.max(cutoffMinutes, 1) * 60 * 1000);
  if (Date.now() > cutoffAt.getTime()) {
    return { ok: false, message: 'Booking cutoff has passed.' };
  }

  const maxCapacity = readInt(slotData.maxCapacity, 0);
  const bookedCount = readInt(slotData.bookedCount, 0);
  if (maxCapacity > 0 && bookedCount >= maxCapacity) {
    return { ok: false, message: 'Trip slot is full.' };
  }

  if (bookingSnap.exists) {
    const bookingData = bookingSnap.data() ?? {};
    const status = String(bookingData.status ?? '').trim();
    if (status && status !== 'cancelled' && status !== 'rejected') {
      return { ok: false, message: 'Duplicate booking is not allowed.', status };
    }
  }

  return {
    ok: true,
    message: 'Booking is valid.',
    bookingId: bookingRef.id,
    status: 'pending',
    departureAt: departureAt.toISOString(),
    cutoffAt: cutoffAt.toISOString(),
  };
}

export const validateBooking = onCall(async (request) => {
  const validation = await validateBookingInput(request.data as BookingInput);
  if (!validation.ok) {
    throw new HttpsError('failed-precondition', validation.message);
  }
  return validation;
});

export const createBooking = onCall(async (request) => {
  const userId = requireString((request.data as BookingInput).userId, 'userId');
  const areaId = requireString((request.data as BookingInput).areaId, 'areaId');
  const tripSlotId = requireString((request.data as BookingInput).tripSlotId, 'tripSlotId');

  return await firestore.runTransaction(async (transaction) => {
    const slotRef = firestore.collection('tripSlots').doc(tripSlotId);
    const bookingRef = firestore.collection('preBookings').doc(`${tripSlotId}_${userId}`);
    const [slotSnap, bookingSnap] = await Promise.all([
      transaction.get(slotRef),
      transaction.get(bookingRef),
    ]);

    if (!slotSnap.exists) {
      throw new HttpsError('not-found', 'Trip slot not found.');
    }

    const slotData = slotSnap.data() ?? {};
    const slotAreaId = String(slotData.areaId ?? '').trim();
    if (!slotAreaId || normalize(slotAreaId) !== normalize(areaId)) {
      throw new HttpsError('failed-precondition', 'Trip slot does not belong to this area.');
    }

    if (slotData.active !== true) {
      throw new HttpsError('failed-precondition', 'Trip slot is not active.');
    }

    const departureAt = toDate(slotData.departureAt);
    if (!departureAt) {
      throw new HttpsError('failed-precondition', 'Trip slot is missing departure time.');
    }

    const cutoffMinutes = readInt(slotData.cutoffMinutes, 30);
    const cutoffAt = new Date(departureAt.getTime() - Math.max(cutoffMinutes, 1) * 60 * 1000);
    if (Date.now() > cutoffAt.getTime()) {
      throw new HttpsError('failed-precondition', 'Booking cutoff has passed.');
    }

    const maxCapacity = readInt(slotData.maxCapacity, 0);
    const bookedCount = readInt(slotData.bookedCount, 0);
    if (maxCapacity > 0 && bookedCount >= maxCapacity) {
      throw new HttpsError('failed-precondition', 'Trip slot is full.');
    }

    if (bookingSnap.exists) {
      const bookingData = bookingSnap.data() ?? {};
      const status = String(bookingData.status ?? '').trim();
      if (status && status !== 'cancelled' && status !== 'rejected') {
        throw new HttpsError('already-exists', 'Duplicate booking is not allowed.');
      }
    }

    transaction.set(
      bookingRef,
      {
        userId,
        areaId,
        tripSlotId,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    );

    transaction.update(slotRef, {
      bookedCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      ok: true,
      message: 'Booking created.',
      bookingId: bookingRef.id,
      status: 'pending',
    };
  });
});

export const scheduledTripActivation = onSchedule('every 5 minutes', async () => {
  const now = admin.firestore.Timestamp.now();
  const next30Minutes = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 30 * 60 * 1000),
  );

  const slotsSnapshot = await firestore
    .collection('tripSlots')
    .where('active', '==', true)
    .where('departureAt', '>=', now)
    .where('departureAt', '<=', next30Minutes)
    .orderBy('departureAt')
    .get();

  for (const slotDoc of slotsSnapshot.docs) {
    const slotData = slotDoc.data();
    const tripRef = firestore.collection('activeTrips').doc(slotDoc.id);
    const tripSnap = await tripRef.get();
    if (tripSnap.exists) {
      continue;
    }

    const bookingsSnapshot = await firestore
      .collection('preBookings')
      .where('tripSlotId', '==', slotDoc.id)
      .where('status', 'in', ['pending', 'confirmed'])
      .get();

    if (bookingsSnapshot.empty) {
      continue;
    }

    const passengers = bookingsSnapshot.docs.map((bookingDoc) => {
      const bookingData = bookingDoc.data();
      return {
        bookingId: bookingDoc.id,
        userId: String(bookingData.userId ?? '').trim(),
        areaId: String(bookingData.areaId ?? slotData.areaId ?? '').trim(),
      };
    });

    const batch = firestore.batch();
    batch.set(tripRef, {
      tripSlotId: slotDoc.id,
      areaId: slotData.areaId,
      departureAt: slotData.departureAt,
      maxCapacity: slotData.maxCapacity ?? passengers.length,
      passengerCount: passengers.length,
      passengers,
      status: 'active',
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'preBookings',
    });

    for (const bookingDoc of bookingsSnapshot.docs) {
      batch.update(bookingDoc.ref, {
        status: 'activated',
        activatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        activeTripId: tripRef.id,
      });
    }

    batch.update(slotDoc.ref, {
      lastActivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      activeTripId: tripRef.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
});