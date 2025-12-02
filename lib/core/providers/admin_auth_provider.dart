import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/services/admin_auth_service.dart';

/// Admin auth state stream provider
final adminAuthStateProvider = StreamProvider<User?>((ref) {
  final adminAuthService = ref.read(adminAuthServiceProvider);
  return adminAuthService.authStateChanges;
});

/// Current admin user provider
final currentAdminUserProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  final adminAuthService = ref.read(adminAuthServiceProvider);
  
  await for (final authState in adminAuthService.authStateChanges) {
    if (authState == null) {
      yield null;
      continue;
    }

    final adminData = await adminAuthService.getAdminData(authState.uid);
    
    // Verify admin is active
    if (adminData != null && adminData['isActive'] == true) {
      yield adminData;
    } else {
      yield null;
    }
  }
});

/// Check if current user is admin
final isAdminProvider = FutureProvider<bool>((ref) async {
  final adminAuthService = ref.read(adminAuthServiceProvider);
  return await adminAuthService.isAdmin();
});

