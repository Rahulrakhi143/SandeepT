# 🚀 Trivora Provider App - Complete Implementation Roadmap

This document provides a comprehensive roadmap for building the complete Trivora Provider App according to specifications.

## ✅ Foundation Complete

- ✅ Project structure
- ✅ Theme system (light theme, white + light blue)
- ✅ Firebase configuration setup
- ✅ Security rules (Firestore & Storage)
- ✅ Core data models (User, Provider)
- ✅ Router setup
- ✅ Riverpod state management setup

## 📋 Implementation Checklist

### Phase 1: Authentication & Onboarding (MVP) ⏳ IN PROGRESS

#### Authentication Service
- [ ] Phone OTP service (`lib/core/services/auth_service.dart`)
  - Send OTP
  - Verify OTP
  - Auto-retrieval handling
  
- [ ] Email/Password authentication
- [ ] Google Sign-In integration
- [ ] Auth state management with Riverpod

#### Auth UI Pages
- [ ] Login page (`lib/features/auth/presentation/pages/login_page.dart`)
  - Phone OTP tab (primary)
  - Email/Password tab
  - Google Sign-In button
  - Modern UI with animations

- [ ] Signup page (`lib/features/auth/presentation/pages/signup_page.dart`)
  - Phone OTP flow
  - Email/Password registration
  - Auto-assign provider role

- [ ] Phone OTP verification page
  - OTP input (6 digits)
  - Auto-fill handling
  - Resend OTP

#### Provider Onboarding
- [ ] Multi-step onboarding flow
  - Step 1: Basic info (name, phone, email)
  - Step 2: Profession selection (multi-select)
  - Step 3: Address & location
  - Step 4: Document upload
    - Aadhar (mandatory)
    - PAN (optional)
    - Photo (mandatory)
  - Step 5: Bank details
  - Step 6: Review & submit

- [ ] Document upload widget
  - Image picker
  - PDF picker
  - Upload to Firebase Storage
  - Progress indicator

### Phase 2: Navigation & Dashboard (MVP)

#### Responsive Navigation
- [ ] Platform detection utility
- [ ] Bottom navigation (mobile)
  - Dashboard
  - Bookings
  - Map/Live
  - Earnings
  - Account

- [ ] Sidebar navigation (web)
  - Dashboard
  - Bookings
  - Calendar
  - Earnings
  - Documents
  - Settings

#### Dashboard Page
- [ ] Earnings graph (fl_chart)
  - Daily/Weekly/Monthly views
  - Line/Bar charts

- [ ] Quick stats cards
  - Active bookings
  - Today's earnings
  - Rating
  - Total bookings

- [ ] Upcoming bookings list
  - Next 5 bookings
  - Quick actions

- [ ] Online/Offline toggle
  - Rive animation
  - Update provider status

- [ ] Notifications section
  - Recent notifications
  - Unread count

### Phase 3: Booking Management (MVP)

#### Booking Models
- [ ] Booking model (`lib/shared/models/booking_model.dart`)
  - Status enum
  - Pricing breakdown
  - Address details
  - Service references

#### Booking Pages
- [ ] Bookings list page
  - Filters: All, Pending, Accepted, In Progress, Completed, Cancelled
  - Search functionality
  - Pull to refresh
  - Pagination

- [ ] Booking detail page
  - User information
  - Service details
  - Pricing breakdown
  - Address with map
  - Action buttons
    - Accept/Reject
    - Mark Started
    - Mark Completed
    - Cancel (with reason)

- [ ] Booking card widget
  - Reusable card component
  - Status badge
  - Quick info

#### Booking Actions
- [ ] Accept booking
  - Update status in Firestore
  - Send notification
  - Update provider availability

- [ ] Reject booking
  - Add rejection reason
  - Handle penalty logic
  - Notify user

- [ ] Status updates
  - Started
  - Completed
  - Cancelled

### Phase 4: Services Management (MVP)

#### Service Models
- [ ] Service template model
- [ ] Provider service model
  - Pricing
  - Add-ons
  - Availability

#### Service Pages
- [ ] Services list page
  - Provider's services
  - Enable/disable toggle
  - Edit/Delete actions

- [ ] Add service page
  - Select category
  - Set base price
  - Add add-ons
  - Upload images
  - Set duration

- [ ] Edit service page
  - Pre-fill existing data
  - Update pricing
  - Modify add-ons

- [ ] Service categories
  - Load from Firestore
  - Admin-managed templates

### Phase 5: Location & Maps (MVP)

#### Location Service
- [ ] Location permission handling
- [ ] Location tracking
  - Update every 5-10 seconds
  - Background tracking (opt-in)
  - Battery-aware cadence

- [ ] Location storage
  - Save to location_logs collection
  - 30-day retention policy

#### Map Integration
- [ ] Google Maps setup
- [ ] Map page
  - Provider location
  - User location (for accepted bookings)
  - Route display
  - ETA calculation

- [ ] Location sharing
  - Share for accepted bookings
  - Real-time updates

### Phase 6: Chat System (MVP)

#### Chat Models
- [ ] Chat room model
- [ ] Message model
  - Text
  - Images
  - Timestamps
  - Read status

#### Chat Pages
- [ ] Chat list page
  - Booking-specific rooms
  - Unread indicators
  - Last message preview

- [ ] Chat detail page
  - Message list
  - Text input
  - Image upload
  - Typing indicators
  - Message status (sent, delivered, read)

#### Chat Features
- [ ] Real-time messaging
  - Firestore streams
  - Message history (30 days)

- [ ] Image upload
  - Image picker
  - Upload to Storage
  - Display in chat

### Phase 7: Payments Integration (MVP)

#### Payment Service
- [ ] Razorpay service
  - Web checkout integration
  - Native SDK (Android/iOS)
  - Payment verification

#### Payment Pages
- [ ] Payment page
  - Payment method selection
  - Razorpay checkout

- [ ] COD confirmation page
  - OTP input
  - Photo proof upload
  - Confirm payment

#### Payment Flow
- [ ] Web payment
  - Razorpay Checkout
  - Server-side verification

- [ ] Native payment
  - Android/iOS SDK
  - Payment verification

- [ ] COD flow
  - Provider confirms payment
  - OTP/Photo proof
  - Mark as paid

### Phase 8: Earnings & Wallet (MVP)

#### Earnings Dashboard
- [ ] Earnings graph
  - Daily/Weekly/Monthly
  - Platform commission breakdown
  - Net earnings

- [ ] Earnings breakdown
  - Provider price
  - Platform fee (15%)
  - Taxes
  - Total

#### Wallet Page
- [ ] Wallet balance
- [ ] Transaction history
  - Earnings
  - Payouts
  - Deductions
  - Bonuses

- [ ] Payout information
  - Pending payouts
  - Completed payouts
  - Payout schedule (weekly)

### Phase 9: Profile & Settings (MVP)

#### Profile Page
- [ ] Edit profile
  - Name
  - Phone
  - Email
  - Photo

#### Settings Page
- [ ] Availability settings
  - Set working hours
  - Block dates
  - Shift management

- [ ] Notification preferences
  - Push notifications
  - Email notifications
  - In-app notifications

- [ ] Bank details
  - Edit bank info
  - Update UPI ID

#### Documents Page
- [ ] Document upload/update
  - Aadhar
  - PAN
  - Photo
- [ ] Verification status
- [ ] Document viewer

### Phase 10: Calendar/Schedule (MVP)

#### Calendar Page
- [ ] Calendar view
  - Monthly view
  - Daily view
  - Upcoming bookings

- [ ] Booking management
  - View booking details
  - Block availability
  - Set working hours

### Phase 11: Notifications (MVP)

#### Notification Service
- [ ] FCM setup
- [ ] Push notification handling
- [ ] In-app notifications
  - Firestore collection
  - Real-time updates

#### Notification Types
- [ ] Booking confirmed
- [ ] Service started
- [ ] Payment received
- [ ] Payout processed
- [ ] System notifications

### Phase 12: Cloud Functions (MVP)

#### Auto-assign Function
- [ ] Find nearest providers
- [ ] Sequential ping (top 5)
- [ ] Timeout handling (20s)
- [ ] Radius expansion (+5 km)
- [ ] Admin notification

#### Commission Calculation
- [ ] Calculate platform fee (15%)
- [ ] Calculate taxes (18% GST)
- [ ] Create invoice
- [ ] Update booking pricing

#### Payout Processing
- [ ] Weekly scheduled function
- [ ] Process payouts
- [ ] Razorpay Payouts API
- [ ] Update wallet balances

#### Penalty Enforcement
- [ ] Provider cancellation penalty
- [ ] Deduct from wallet
- [ ] Update payout amounts

### Phase 13: Admin Panel (Web)

#### Admin Dashboard
- [ ] Provider management
  - List providers
  - Approve/Reject
  - Suspend/Block
  - View documents

- [ ] Booking management
  - View all bookings
  - Manual assignment
  - Cancellation handling

- [ ] Analytics
  - Revenue dashboard
  - Booking statistics
  - Provider performance

### Phase 14: Polish & Testing

#### Rive Animations
- [ ] Online/Offline toggle animation
- [ ] Onboarding animations
- [ ] Loading states

#### Testing
- [ ] Unit tests
- [ ] Widget tests
- [ ] Integration tests

#### Documentation
- [ ] API documentation
- [ ] Deployment guide
- [ ] User guide

---

## 🎯 Priority Order for Implementation

1. **Authentication & Onboarding** - Foundation for everything
2. **Dashboard & Navigation** - Core UI structure
3. **Booking Management** - Core business logic
4. **Services CRUD** - Provider capabilities
5. **Payments Integration** - Revenue flow
6. **Location & Maps** - Service delivery
7. **Chat System** - Communication
8. **Earnings & Wallet** - Provider financials
9. **Cloud Functions** - Backend logic
10. **Admin Panel** - Management tools

---

**Current Status:** Building Authentication System

**Next:** Complete auth service and UI pages



