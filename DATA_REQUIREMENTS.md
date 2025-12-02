# Data Requirements Documentation

This document outlines all data structures and requirements for the Trivora Provider App, organized by user roles (Admin, Provider, and User/Customer).

---

## 📋 Table of Contents

1. [Admin Data Requirements](#admin-data-requirements)
2. [Provider Data Requirements](#provider-data-requirements)
3. [User (Customer) Data Requirements](#user-customer-data-requirements)
4. [Shared Data Structures](#shared-data-structures)
5. [Firebase Collections](#firebase-collections)

---

## 👑 Admin Data Requirements

### Firebase Authentication
- **Email**: Admin email address (required)
- **Password**: Admin password (required, min 6 characters)
- **Display Name**: Admin's display name

### Firestore Collection: `admins`
**Document ID**: Firebase Auth UID

```json
{
  "email": "string (required)",
  "displayName": "string (required)",
  "role": "admin (required)",
  "isActive": "boolean (required, default: true)",
  "createdAt": "Timestamp (required)",
  "updatedAt": "Timestamp (required)",
  "lastLoginAt": "Timestamp (optional)"
}
```

### Admin Capabilities
- View all providers
- View all users (customers)
- View all bookings across all providers
- View all payments and transactions
- Suspend/Activate providers and users
- View dashboard statistics
- Manage admin accounts (restricted - cannot create new admins)

### Default Admin Accounts
1. **Admin Sandeep**
   - Email: `chouhansandeep14209@gmail.com`
   - Password: `12345678`

2. **Admin Manager**
   - Email: `admin@trivora.com`
   - Password: `admin123`

3. **Super Admin**
   - Email: `superadmin@trivora.com`
   - Password: `super123`

---

## 🔧 Provider Data Requirements

### Firebase Authentication
- **Email**: Provider email address (required)
- **Password**: Provider password (required, min 6 characters)
- **Phone**: Provider phone number (optional, for OTP)
- **Display Name**: Provider's display name

### Firestore Collection: `providers`
**Document ID**: Firebase Auth UID

```json
{
  "userId": "string (required, same as document ID)",
  "email": "string (required)",
  "phone": "string (optional)",
  "displayName": "string (required)",
  "photoUrl": "string (optional, URL)",
  "role": "provider (required)",
  "about": "string (optional, provider description)",
  "isActive": "boolean (required, default: true)",
  "isOnline": "boolean (required, default: false)",
  "isVerified": "boolean (required, default: false)",
  "rating": "number (optional, 0.0 to 5.0)",
  "totalBookings": "number (optional, default: 0)",
  "completedBookings": "number (optional, default: 0)",
  "createdAt": "Timestamp (required)",
  "updatedAt": "Timestamp (required)"
}
```

### Provider Sub-collections

#### 1. Services: `providers/{providerId}/services`
**Document ID**: Service ID

```json
{
  "id": "string (required)",
  "providerId": "string (required)",
  "serviceName": "string (required)",
  "description": "string (optional)",
  "basePrice": "number (required, in INR)",
  "duration": "number (required, in minutes)",
  "category": "string (required, e.g., 'Plumbing', 'Electrical')",
  "isActive": "boolean (required, default: true)",
  "createdAt": "Timestamp (required)",
  "updatedAt": "Timestamp (required)"
}
```

#### 2. Bookings: `providers/{providerId}/bookings`
**Document ID**: Booking ID

```json
{
  "id": "string (required)",
  "providerId": "string (required)",
  "customerId": "string (required)",
  "customerName": "string (required)",
  "customerPhone": "string (required)",
  "serviceName": "string (required)",
  "serviceId": "string (required)",
  "status": "string (required: 'pending', 'accepted', 'in_progress', 'completed', 'cancelled')",
  "amount": "number (required, in INR)",
  "baseAmount": "number (required, in INR)",
  "finalAmount": "number (optional, calculated amount)",
  "paymentMethod": "string (required: 'cod', 'razorpay', 'upi')",
  "paymentStatus": "string (required: 'paid', 'unpaid')",
  "scheduledDate": "Timestamp (required)",
  "scheduledDuration": "number (optional, in minutes)",
  "scheduledDurationMinutes": "number (optional)",
  "actualDurationMinutes": "number (optional)",
  "serviceStartTime": "Timestamp (optional, when status is 'in_progress' or 'completed')",
  "serviceEndTime": "Timestamp (optional, when status is 'completed')",
  "address": "string (required, customer address)",
  "startOtp": {
    "otpHash": "string (SHA256 hash)",
    "createdAt": "Timestamp",
    "expiresAt": "Timestamp (10 minutes from creation)",
    "used": "boolean",
    "resendCount": "number (max 3)",
    "verifiedAt": "Timestamp (optional)"
  },
  "completionOtp": {
    "otpHash": "string (SHA256 hash)",
    "createdAt": "Timestamp",
    "expiresAt": "Timestamp (10 minutes from creation)",
    "used": "boolean",
    "resendCount": "number (max 3)",
    "verifiedAt": "Timestamp (optional)"
  },
  "createdAt": "Timestamp (required)",
  "updatedAt": "Timestamp (required)"
}
```

#### 3. Payments: `providers/{providerId}/payments`
**Document ID**: Payment ID

```json
{
  "id": "string (required)",
  "providerId": "string (required)",
  "bookingId": "string (required)",
  "customerId": "string (required)",
  "amount": "number (required, total amount in INR)",
  "platformFee": "number (required, 10% of amount)",
  "providerEarning": "number (required, amount - platformFee)",
  "status": "string (required: 'pending', 'completed', 'failed')",
  "paymentMethod": "string (required: 'cod', 'razorpay', 'upi')",
  "paidAt": "Timestamp (optional)",
  "createdAt": "Timestamp (required)",
  "updatedAt": "Timestamp (required)"
}
```

#### 4. Wallet: `providers/{providerId}/wallet/balance`
**Document ID**: `balance` (single document)

```json
{
  "balance": "number (required, available balance in INR)",
  "pendingBalance": "number (required, pending earnings in INR)",
  "totalEarnings": "number (required, total earnings in INR)",
  "lastUpdated": "Timestamp (required)"
}
```

#### 5. Payment Methods: `providers/{providerId}/paymentMethods`
**Document ID**: Payment method ID (e.g., `cod`, `razorpay`, `upi`)

```json
{
  "methodId": "string (required)",
  "methodName": "string (required)",
  "isEnabled": "boolean (required, default: true)",
  "updatedAt": "Timestamp (required)"
}
```

### Provider Capabilities
- Create, update, and delete services
- View and manage bookings (accept, reject, start, complete)
- Generate and verify OTPs for service start and completion
- View earnings and wallet balance
- Update profile (name, photo, phone, email, about)
- Manage payment method preferences
- View calendar with bookings
- Upload documents (Aadhar, etc.)
- Change password
- Enable/disable 2FA
- Manage notification preferences
- Change language (English/Hindi)

---

## 👤 User (Customer) Data Requirements

### Firebase Authentication
- **Email**: User email address (required)
- **Password**: User password (required, min 6 characters)
- **Phone**: User phone number (optional, for OTP)
- **Display Name**: User's display name

### Firestore Collection: `users`
**Document ID**: Firebase Auth UID

```json
{
  "userId": "string (required, same as document ID)",
  "email": "string (required)",
  "phone": "string (optional)",
  "displayName": "string (required)",
  "photoUrl": "string (optional, URL)",
  "role": "user (required)",
  "isActive": "boolean (required, default: true)",
  "isVerified": "boolean (required, default: false)",
  "createdAt": "Timestamp (required)",
  "updatedAt": "Timestamp (required)"
}
```

### User Capabilities
- Browse providers and services
- Create bookings
- View booking history
- Receive OTPs for service start and completion
- Make payments (COD, Online, UPI)
- View invoices
- Update profile
- Manage notifications
- Contact support

---

## 📊 Shared Data Structures

### Notifications: `notifications`
**Document ID**: Notification ID

```json
{
  "id": "string (required)",
  "userId": "string (required, provider or user ID)",
  "type": "string (required: 'booking_created', 'booking_accepted', 'booking_completed', 'payment_received', 'service_start_otp', 'service_completion_otp')",
  "title": "string (required)",
  "body": "string (required)",
  "read": "boolean (required, default: false)",
  "data": {
    "bookingId": "string (optional)",
    "paymentId": "string (optional)",
    "otp": "string (optional, plain OTP for user display)"
  },
  "createdAt": "Timestamp (required)"
}
```

### Documents: `providers/{providerId}/documents`
**Document ID**: Document ID

```json
{
  "id": "string (required)",
  "providerId": "string (required)",
  "documentType": "string (required: 'aadhar', 'pan', 'license', 'other')",
  "documentName": "string (required)",
  "fileUrl": "string (required, Storage URL)",
  "uploadedAt": "Timestamp (required)",
  "verified": "boolean (required, default: false)",
  "verifiedAt": "Timestamp (optional)"
}
```

---

## 🗂️ Firebase Collections Summary

### Root Collections
1. **`admins`** - Admin user accounts
2. **`providers`** - Provider user accounts
3. **`users`** - Customer user accounts
4. **`notifications`** - All notifications for providers and users

### Provider Sub-collections
- `providers/{providerId}/services` - Provider's services
- `providers/{providerId}/bookings` - Provider's bookings
- `providers/{providerId}/payments` - Provider's payment records
- `providers/{providerId}/wallet` - Provider's wallet (single document: `balance`)
- `providers/{providerId}/paymentMethods` - Provider's payment method preferences
- `providers/{providerId}/documents` - Provider's uploaded documents

---

## 🔐 Authentication Requirements

### All Roles
- **Email/Password Authentication**: Required for all users
- **Google Sign In**: Optional (for providers and users)
- **Phone OTP**: Optional (for providers and users)
- **2FA (Two-Factor Authentication)**: Optional (for providers)

### Role-Based Access Control
- **Admin**: Can only access admin routes (`/admin/*`)
- **Provider**: Can only access provider routes (dashboard, bookings, services, etc.)
- **User**: Can only access user routes (browse, book, etc.)

---

## 📝 Data Validation Rules

### Email
- Must be valid email format
- Must be unique per role (admin, provider, user can have same email in different collections)

### Phone
- Format: `+91XXXXXXXXXX` (Indian format)
- Optional for all roles

### Password
- Minimum 6 characters
- No maximum limit (Firebase default)

### Rating
- Range: 0.0 to 5.0
- Decimal precision: 1 decimal place

### Amounts (Money)
- All amounts in INR (Indian Rupees)
- Stored as `double` or `number` in Firestore
- Platform fee: 10% of booking amount

### OTP
- 6-digit random number
- SHA256 hashed before storage
- Expires in 10 minutes
- Max 3 resend attempts per OTP
- Deleted after successful verification

### Booking Status Flow
```
pending → accepted → in_progress → completed
                ↓
           cancelled
```

### Payment Status
- `unpaid`: Payment not yet received
- `paid`: Payment completed (for COD, this happens after OTP verification)

---

## 🚀 Data Seeding

Use the script `lib/scripts/seed_firebase_dummy_data.dart` to populate Firebase with dummy data:

```bash
# Run the seeding script
dart lib/scripts/seed_firebase_dummy_data.dart
```

Or use the UI:
- Admin Dashboard → Quick Actions → "Seed Dummy Data"
- Navigate to `/seed-dummy-data` route

### Seeded Data Includes:
- **3 Admin accounts** (with credentials)
- **8 Provider accounts** (6 active, 2 inactive)
- **10 User accounts** (8 active, 2 inactive)
- **3-6 Services per provider**
- **100+ Bookings** with various statuses
- **Payment records** for completed bookings
- **Wallet balances** for all providers
- **20 Notifications** for various events

---

## 📌 Important Notes

1. **Admin Account Creation**: Admins cannot create other admin accounts through the UI. Admin accounts must be created manually or via script.

2. **OTP Security**: 
   - OTPs are hashed (SHA256) before storage
   - Plain OTP is only sent via notifications to users
   - OTPs expire after 10 minutes
   - Used OTPs are deleted from Firestore

3. **Payment Calculation**:
   - Base amount: Service base price
   - Extra amount: Calculated if service duration exceeds scheduled duration
   - Final amount: Base amount + Extra amount
   - Platform fee: 10% of final amount
   - Provider earning: Final amount - Platform fee

4. **Data Ownership**:
   - Providers can only access their own services, bookings, payments, and wallet
   - Users can only access their own bookings and profile
   - Admins can access all data across all providers and users

5. **Real-time Updates**:
   - All data uses Firestore streams for real-time updates
   - Bookings, payments, and notifications update in real-time

---

## 🔄 Data Synchronization

- All data is stored in Firebase Firestore
- Firebase Authentication handles user authentication
- Firebase Storage handles file uploads (documents, profile photos)
- Firebase Cloud Messaging (FCM) handles push notifications
- All timestamps use `FieldValue.serverTimestamp()` for consistency

---

**Last Updated**: 2024
**Version**: 1.0

