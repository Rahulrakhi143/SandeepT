import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Backend service that provides mock data and business logic
class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  final Random _random = Random();
  
  // In-memory data storage - using Map to store per user
  final Map<String, List<Map<String, dynamic>>> _userBookings = {};
  final Map<String, List<Map<String, dynamic>>> _userServices = {};
  final Map<String, List<Map<String, dynamic>>> _userPayments = {};
  
  // Initialize with random data for a specific user
  void initializeData(String userId) {
    if (!_userBookings.containsKey(userId)) {
      _userBookings[userId] = [];
      _generateRandomBookings(userId);
    }
    if (!_userServices.containsKey(userId)) {
      _userServices[userId] = [];
      _generateRandomServices(userId);
    }
    if (!_userPayments.containsKey(userId)) {
      _userPayments[userId] = [];
      _generateRandomPayments(userId);
    }
  }

  // ==================== BOOKINGS ====================
  
  List<Map<String, dynamic>> getBookings(String userId, {String? status}) {
    initializeData(userId);
    var bookings = _userBookings[userId]!.where((b) => b['providerId'] == userId).toList();
    if (status != null && status != 'all') {
      bookings = bookings.where((b) => b['status'] == status).toList();
    }
    // Sort by scheduled date (upcoming first)
    bookings.sort((a, b) {
      final dateA = a['scheduledDate'] as DateTime;
      final dateB = b['scheduledDate'] as DateTime;
      return dateA.compareTo(dateB);
    });
    return bookings;
  }

  Map<String, dynamic>? getBooking(String bookingId, String userId) {
    try {
      final booking = _userBookings[userId]?.firstWhere((b) => b['id'] == bookingId);
      // Verify ownership
      if (booking != null && booking['providerId'] == userId) {
        return booking;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> acceptBooking(String bookingId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final bookings = _userBookings[userId];
    if (bookings == null) return;
    
    final index = bookings.indexWhere((b) => b['id'] == bookingId && b['providerId'] == userId);
    if (index != -1) {
      bookings[index]['status'] = 'accepted';
      bookings[index]['acceptedAt'] = DateTime.now();
      bookings[index]['updatedAt'] = DateTime.now();
    }
  }

  Future<void> rejectBooking(String bookingId, String userId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final bookings = _userBookings[userId];
    if (bookings == null) return;
    
    final index = bookings.indexWhere((b) => b['id'] == bookingId && b['providerId'] == userId);
    if (index != -1) {
      bookings[index]['status'] = 'rejected';
      bookings[index]['rejectionReason'] = reason;
      bookings[index]['rejectedAt'] = DateTime.now();
      bookings[index]['updatedAt'] = DateTime.now();
    }
  }

  Future<void> updateBookingStatus(String bookingId, String userId, String status) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final bookings = _userBookings[userId];
    if (bookings == null) return;
    
    final index = bookings.indexWhere((b) => b['id'] == bookingId && b['providerId'] == userId);
    if (index != -1) {
      bookings[index]['status'] = status;
      bookings[index]['updatedAt'] = DateTime.now();
    }
  }

  Future<void> completeBooking(String bookingId, String userId) async {
    await updateBookingStatus(bookingId, userId, 'completed');
    final bookings = _userBookings[userId];
    if (bookings != null) {
      try {
        final booking = bookings.firstWhere((b) => b['id'] == bookingId);
        booking['completedAt'] = DateTime.now();
      } catch (e) {
        // Booking not found, ignore
      }
    }
  }

  // ==================== SERVICES ====================
  
  List<Map<String, dynamic>> getServices(String userId) {
    initializeData(userId);
    return _userServices[userId]!
        .where((s) => s['providerId'] == userId && s['isActive'] == true)
        .toList()
      ..sort((a, b) {
        final dateA = a['createdAt'] as DateTime;
        final dateB = b['createdAt'] as DateTime;
        return dateB.compareTo(dateA); // Newest first
      });
  }

  Map<String, dynamic>? getService(String serviceId, String userId) {
    try {
      final service = _userServices[userId]?.firstWhere((s) => s['id'] == serviceId);
      // Verify ownership
      if (service != null && service['providerId'] == userId) {
        return service;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String> addService(String userId, Map<String, dynamic> serviceData) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Validate required fields
    if (serviceData['serviceName'] == null || (serviceData['serviceName'] as String).isEmpty) {
      throw Exception('Service name is required');
    }
    if (serviceData['basePrice'] == null || (serviceData['basePrice'] as num) <= 0) {
      throw Exception('Valid price is required');
    }
    
    initializeData(userId);
    final service = {
      'id': 'service_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      'providerId': userId,
      'serviceName': serviceData['serviceName'],
      'description': serviceData['description'] ?? 'Professional ${serviceData['serviceName']} service',
      'basePrice': serviceData['basePrice'],
      'duration': serviceData['duration'] ?? 60,
      'category': serviceData['category'] ?? 'General',
      'isActive': true,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    };
    _userServices[userId]!.add(service);
    return service['id'];
  }

  Future<void> updateService(String serviceId, String userId, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final services = _userServices[userId];
    if (services == null) {
      throw Exception('Services not found');
    }
    
    final index = services.indexWhere((s) => s['id'] == serviceId && s['providerId'] == userId);
    if (index == -1) {
      throw Exception('Service not found or you do not have permission to edit it');
    }
    
    // Validate required fields if provided
    if (data.containsKey('serviceName')) {
      final serviceName = data['serviceName'];
      if (serviceName is String && serviceName.isEmpty) {
        throw Exception('Service name cannot be empty');
      }
    }
    if (data.containsKey('basePrice')) {
      final basePrice = data['basePrice'];
      if (basePrice is num && basePrice <= 0) {
        throw Exception('Price must be greater than 0');
      }
    }
    
    services[index] = {
      ...services[index],
      ...data,
      'updatedAt': DateTime.now(),
    };
  }

  Future<void> deleteService(String serviceId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final services = _userServices[userId];
    if (services == null) {
      throw Exception('Services not found');
    }
    
    final index = services.indexWhere((s) => s['id'] == serviceId && s['providerId'] == userId);
    if (index == -1) {
      throw Exception('Service not found or you do not have permission to delete it');
    }
    
    // Soft delete - mark as inactive
    services[index]['isActive'] = false;
    services[index]['deletedAt'] = DateTime.now();
    services[index]['updatedAt'] = DateTime.now();
  }

  Future<void> toggleServiceStatus(String serviceId, String userId, bool isActive) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final services = _userServices[userId];
    if (services == null) return;
    
    final index = services.indexWhere((s) => s['id'] == serviceId && s['providerId'] == userId);
    if (index != -1) {
      services[index]['isActive'] = isActive;
      services[index]['updatedAt'] = DateTime.now();
    }
  }

  // ==================== PAYMENTS ====================
  
  List<Map<String, dynamic>> getPayments(String userId, {DateTime? startDate, DateTime? endDate}) {
    initializeData(userId);
    var payments = _userPayments[userId]!.where((p) => p['providerId'] == userId).toList();
    
    if (startDate != null) {
      payments = payments.where((p) {
        final date = p['createdAt'] as DateTime;
        return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
      }).toList();
    }
    
    if (endDate != null) {
      payments = payments.where((p) {
        final date = p['createdAt'] as DateTime;
        return date.isBefore(endDate);
      }).toList();
    }
    
    // Sort by date (newest first)
    payments.sort((a, b) {
      final dateA = a['createdAt'] as DateTime;
      final dateB = b['createdAt'] as DateTime;
      return dateB.compareTo(dateA);
    });
    
    return payments;
  }

  double getWalletBalance(String userId) {
    initializeData(userId);
    final completedPayments = _userPayments[userId]!
        .where((p) => p['providerId'] == userId && p['status'] == 'completed')
        .toList();
    return completedPayments.fold(0.0, (sum, p) => sum + (p['providerEarning'] as num).toDouble());
  }

  // ==================== STATISTICS ====================
  
  Map<String, dynamic> getDashboardStats(String userId) {
    initializeData(userId);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    final bookings = _userBookings[userId]!;
    final payments = _userPayments[userId]!;
    
    final activeBookings = bookings.where((b) =>
      b['providerId'] == userId &&
      ['pending', 'accepted', 'confirmed', 'in_progress'].contains(b['status'])
    ).length;
    
    final todayPayments = payments.where((p) {
      final date = p['createdAt'] as DateTime;
      return p['providerId'] == userId &&
          p['status'] == 'completed' &&
          date.isAfter(startOfDay);
    }).toList();
    
    final todayEarnings = todayPayments.fold(0.0, (sum, p) => sum + (p['providerEarning'] as num).toDouble());
    
    return {
      'activeBookings': activeBookings,
      'todayEarnings': todayEarnings,
      'totalBookings': bookings.where((b) => b['providerId'] == userId).length,
      'rating': 4.5 + (_random.nextDouble() * 0.5), // 4.5 to 5.0
    };
  }

  // ==================== RANDOM DATA GENERATION ====================
  
  void _generateRandomBookings(String userId) {
    final List<String> serviceNames = ['Plumbing', 'Electrical', 'Cleaning', 'Carpentry', 'Painting'];
    final List<String> customerNames = ['Alice', 'Bob', 'Charlie', 'David', 'Emma', 'Frank', 'Grace', 'Henry'];
    final List<String> statuses = ['pending', 'accepted', 'completed', 'cancelled'];
    final List<String> addresses = [
      '123 Main St, City',
      '456 Park Ave, City',
      '789 Oak Rd, City',
      '321 Elm St, City',
    ];

    final bookings = <Map<String, dynamic>>[];
    for (int i = 0; i < 15; i++) {
      final status = statuses[_random.nextInt(statuses.length)];
      final scheduledDate = DateTime.now().add(Duration(days: _random.nextInt(30) - 10));
      final createdAt = scheduledDate.subtract(Duration(days: _random.nextInt(5) + 1));
      
      bookings.add({
        'id': 'booking_${userId}_${DateTime.now().millisecondsSinceEpoch}_$i',
        'providerId': userId,
        'customerId': 'customer_${_random.nextInt(1000)}',
        'customerName': customerNames[_random.nextInt(customerNames.length)],
        'customerPhone': '+91${9000000000 + _random.nextInt(999999999)}',
        'serviceName': serviceNames[_random.nextInt(serviceNames.length)],
        'status': status,
        'amount': 500 + _random.nextInt(2000),
        'scheduledDate': scheduledDate,
        'address': addresses[_random.nextInt(addresses.length)],
        'createdAt': createdAt,
        'updatedAt': createdAt,
        if (status == 'accepted') 'acceptedAt': createdAt,
        if (status == 'completed') 'completedAt': scheduledDate,
      });
    }
    _userBookings[userId] = bookings;
  }

  void _generateRandomServices(String userId) {
    final List<String> serviceNames = ['Plumbing', 'Electrical', 'Cleaning', 'Carpentry', 'Painting'];
    final List<String> categories = ['Plumbing', 'Electrical', 'Cleaning', 'Carpentry', 'Painting', 'AC Repair'];

    final services = <Map<String, dynamic>>[];
    for (int i = 0; i < 5; i++) {
      final serviceName = serviceNames[_random.nextInt(serviceNames.length)];
      services.add({
        'id': 'service_${userId}_${DateTime.now().millisecondsSinceEpoch}_$i',
        'providerId': userId,
        'serviceName': serviceName,
        'description': 'Professional $serviceName service by expert',
        'basePrice': 200 + _random.nextInt(1000),
        'duration': 30 + _random.nextInt(90),
        'category': categories[_random.nextInt(categories.length)],
        'isActive': true,
        'createdAt': DateTime.now().subtract(Duration(days: _random.nextInt(30))),
        'updatedAt': DateTime.now().subtract(Duration(days: _random.nextInt(30))),
      });
    }
    _userServices[userId] = services;
  }

  void _generateRandomPayments(String userId) {
    final List<String> paymentMethods = ['Cash', 'Online', 'razorpay', 'cod'];
    final bookings = _userBookings[userId] ?? [];

    final payments = <Map<String, dynamic>>[];
    for (int i = 0; i < 10; i++) {
      final amount = 500 + _random.nextInt(3000);
      final platformFee = amount * 0.1; // 10% platform fee
      final providerEarning = amount - platformFee;
      final createdAt = DateTime.now().subtract(Duration(days: _random.nextInt(30)));
      
      payments.add({
        'id': 'payment_${userId}_${DateTime.now().millisecondsSinceEpoch}_$i',
        'providerId': userId,
        'bookingId': bookings.isNotEmpty ? bookings[_random.nextInt(bookings.length)]['id'] : 'booking_$i',
        'amount': amount,
        'platformFee': platformFee,
        'providerEarning': providerEarning,
        'status': 'completed',
        'paymentMethod': paymentMethods[_random.nextInt(paymentMethods.length)],
        'createdAt': createdAt,
        'updatedAt': createdAt,
      });
    }
    _userPayments[userId] = payments;
  }
}

final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService();
});
