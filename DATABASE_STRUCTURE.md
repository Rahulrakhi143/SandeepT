# Database Structure - Role-Based Authentication

## Overview
This app uses **role-based authentication** where all authenticated users are **providers** (service providers). The database is structured to separate providers from regular users.

## Database Collections

### 1. `providers` Collection
**Purpose**: Stores all provider accounts (this app is provider-only)

**Document Structure**:
```javascript
{
  userId: "firebase_auth_uid",
  email: "provider@example.com",
  phone: "+919876543210",
  displayName: "Provider Name",
  photoUrl: "https://...",
  role: "provider", // Always "provider" for this app
  about: "Provider description/bio",
  isOnline: true/false,
  isVerified: true/false,
  rating: 4.5,
  totalBookings: 150,
  completedBookings: 120,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  isEmailVerified: true/false,
  isPhoneVerified: true/false,
  emailPendingVerification: true/false
}
```

### 2. Subcollections under `providers/{providerId}/`

#### `services` Subcollection
**Purpose**: Provider's services
```javascript
{
  id: "service_id",
  providerId: "provider_uid",
  serviceName: "Plumbing",
  description: "Professional plumbing service",
  basePrice: 500,
  duration: 60,
  category: "Plumbing",
  isActive: true,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

#### `bookings` Subcollection
**Purpose**: Bookings for this provider
```javascript
{
  id: "booking_id",
  providerId: "provider_uid",
  customerId: "customer_uid",
  customerName: "Customer Name",
  customerPhone: "+919876543210",
  serviceName: "Plumbing",
  status: "pending|accepted|completed|cancelled",
  amount: 1500,
  scheduledDate: Timestamp,
  address: "Customer address",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

#### `payments` Subcollection
**Purpose**: Payment records for this provider
```javascript
{
  id: "payment_id",
  providerId: "provider_uid",
  bookingId: "booking_id",
  amount: 1500,
  platformFee: 150,
  providerEarning: 1350,
  status: "completed",
  paymentMethod: "razorpay|cod",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

#### `wallet` Subcollection
**Purpose**: Wallet balance for this provider
```javascript
{
  balance: 5000.0,
  pendingBalance: 500.0,
  totalEarnings: 10000.0,
  lastUpdated: Timestamp
}
```

### 3. `users` Collection (Legacy/Reserved)
**Purpose**: Reserved for regular users/customers (not used in this provider app)
- This collection is kept for future expansion or if you need to support regular users

## Role-Based Access Control

### Provider Role
- All authenticated users in this app are providers
- Providers can:
  - Manage their own services
  - View and manage their bookings
  - Update their profile (name, photo, phone, email, about)
  - View their earnings and payments
  - Access provider-specific features

### Access Rules
- Providers can only access their own data
- All queries filter by `providerId` or `userId`
- Services, bookings, and payments are scoped to the provider's subcollections

## Data Flow

1. **Sign Up**: Creates document in `providers` collection
2. **Sign In**: Retrieves document from `providers` collection
3. **Profile Update**: Updates document in `providers` collection
4. **Services**: Stored in `providers/{providerId}/services`
5. **Bookings**: Stored in `providers/{providerId}/bookings`
6. **Payments**: Stored in `providers/{providerId}/payments`

## Migration Notes

- Existing users in `users` collection with `role: 'provider'` will be automatically migrated to `providers` collection
- All new signups go directly to `providers` collection
- The app checks `providers` collection first, then falls back to `users` for migration

## Security Rules (Recommended)

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Providers collection
    match /providers/{providerId} {
      // Provider can read/write their own document
      allow read, write: if request.auth != null && request.auth.uid == providerId;
      
      // Services subcollection
      match /services/{serviceId} {
        allow read, write: if request.auth != null && request.auth.uid == providerId;
      }
      
      // Bookings subcollection
      match /bookings/{bookingId} {
        allow read, write: if request.auth != null && request.auth.uid == providerId;
      }
      
      // Payments subcollection
      match /payments/{paymentId} {
        allow read, write: if request.auth != null && request.auth.uid == providerId;
      }
      
      // Wallet subcollection
      match /wallet/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == providerId;
      }
    }
  }
}
```

