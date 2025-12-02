/// App configuration and business rules
class AppConfig {
  // Firebase Collections - Role-based structure
  static const String usersCollection = 'users'; // Regular users/customers
  static const String providersCollection = 'providers'; // Service providers
  static const String adminsCollection = 'admins'; // Admin users
  
  // Provider-specific collections
  static const String providerServicesCollection = 'provider_services';
  static const String providerBookingsCollection = 'provider_bookings';
  static const String providerPaymentsCollection = 'provider_payments';
  static const String providerWalletsCollection = 'provider_wallets';
  
  // General collections
  static const String bookingsCollection = 'bookings';
  static const String paymentsCollection = 'payments';
  static const String payoutsCollection = 'payouts';
  static const String walletsCollection = 'wallets';
  static const String chatsCollection = 'chats';
  static const String notificationsCollection = 'notifications';
  static const String serviceCategoriesCollection = 'provider_services'; // Service categories stored in provider_services collection
  
  // User roles
  static const String roleProvider = 'provider';
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';
}
