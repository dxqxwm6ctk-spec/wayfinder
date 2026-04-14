# Pre-Booking Return Trips

## Firestore Schema Additions

### `tripSlots/{tripSlotId}`
- `areaId`: string
- `active`: boolean
- `departureAt`: timestamp
- `maxCapacity`: number
- `bookedCount`: number
- `cutoffMinutes`: number
- `createdAt`: timestamp
- `updatedAt`: timestamp
- `lastActivatedAt`: timestamp
- `activeTripId`: string

### `preBookings/{tripSlotId}_{userId}`
- `userId`: string
- `areaId`: string
- `tripSlotId`: string
- `status`: `pending | confirmed | activated | cancelled | rejected`
- `createdAt`: timestamp
- `updatedAt`: timestamp
- `activatedAt`: timestamp
- `activeTripId`: string

### `activeTrips/{tripSlotId}`
- `tripSlotId`: string
- `areaId`: string
- `departureAt`: timestamp
- `maxCapacity`: number
- `passengerCount`: number
- `passengers`: array of `{ bookingId, userId, areaId }`
- `status`: `active`
- `activatedAt`: timestamp
- `createdAt`: timestamp
- `source`: `preBookings`

## Example Queries

### Student booking screen
```dart
FirebaseFirestore.instance
  .collection('tripSlots')
  .where('areaId', isEqualTo: areaId)
  .where('active', isEqualTo: true)
  .orderBy('departureAt')
  .snapshots();
```

### Student's current bookings
```dart
FirebaseFirestore.instance
  .collection('preBookings')
  .where('userId', isEqualTo: userId)
  .where('areaId', isEqualTo: areaId)
  .orderBy('createdAt', descending: true)
  .snapshots();
```

### Scheduled activation lookup
```ts
firestore.collection('tripSlots')
  .where('active', '==', true)
  .where('departureAt', '>=', now)
  .where('departureAt', '<=', next30Minutes)
  .orderBy('departureAt')
```

## Integration Points

- The student page uses the current user's `defaultPickupArea` as the `areaId` source.
- Booking creation is isolated in `lib/core/services/trip_booking_service.dart`.
- The student booking UI is embedded in the existing request screen, so no navigation redesign is needed.
- `scheduledTripActivation` creates `activeTrips` only when bookings exist.
- Existing collections such as `users`, `zones`, and `rideRequests` stay untouched for backward compatibility.

## Cloud Functions

- `validateBooking`
- `createBooking`
- `scheduledTripActivation`
