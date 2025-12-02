import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/firebase_auth_service.dart';
import 'package:trivora_provider/core/services/privacy_settings_service.dart';

/// Privacy & Security Page
class PrivacySecurityPage extends ConsumerStatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  ConsumerState<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends ConsumerState<PrivacySecurityPage> {
  bool _showProfileToPublic = true;
  bool _allowDirectMessages = true;
  bool _shareLocation = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) return;

    try {
      final privacyService = ref.read(privacySettingsServiceProvider);
      final settings = await privacyService.getPrivacySettings(authUser.uid);
      
      if (mounted) {
        setState(() {
          _showProfileToPublic = settings['showProfileToPublic'] as bool? ?? true;
          _allowDirectMessages = settings['allowDirectMessages'] as bool? ?? true;
          _shareLocation = settings['shareLocation'] as bool? ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading privacy settings: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view privacy settings')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy Settings
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Privacy Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Show Profile to Public'),
                  subtitle: const Text('Allow customers to view your profile'),
                  value: _showProfileToPublic,
                  onChanged: _isLoading ? null : (value) {
                    setState(() {
                      _showProfileToPublic = value;
                    });
                    _savePrivacySettings();
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Allow Direct Messages'),
                  subtitle: const Text('Let customers send you messages'),
                  value: _allowDirectMessages,
                  onChanged: _isLoading ? null : (value) {
                    setState(() {
                      _allowDirectMessages = value;
                    });
                    _savePrivacySettings();
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Share Location'),
                  subtitle: const Text('Share your location with customers for better service'),
                  value: _shareLocation,
                  onChanged: _isLoading ? null : (value) {
                    setState(() {
                      _shareLocation = value;
                    });
                    _savePrivacySettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Settings
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Security',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your account password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showChangePasswordDialog(context);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sign Out'),
                  subtitle: const Text('Sign out from your account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _handleSignOut(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePrivacySettings() async {
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final privacyService = ref.read(privacySettingsServiceProvider);
      await privacyService.updatePrivacySettings(
        authUser.uid,
        {
          'showProfileToPublic': _showProfileToPublic,
          'allowDirectMessages': _allowDirectMessages,
          'shareLocation': _shareLocation,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    helperText: 'Password must be at least 6 characters',
                  ),
                  obscureText: true,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  enabled: !isLoading,
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                // Validate inputs
                if (oldPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your current password'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a new password'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (oldPasswordController.text == newPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New password must be different from current password'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Show loading
                setState(() {
                  isLoading = true;
                });

                try {
                  final authService = ref.read(firebaseAuthServiceProvider);
                  await authService.changePassword(
                    currentPassword: oldPasswordController.text,
                    newPassword: newPasswordController.text,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Password changed successfully'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    setState(() {
                      isLoading = false;
                    });

                    String errorMessage = 'Failed to change password';
                    if (e.toString().contains('wrong-password')) {
                      errorMessage = 'Current password is incorrect';
                    } else if (e.toString().contains('weak-password')) {
                      errorMessage = 'Password is too weak. Please choose a stronger password';
                    } else if (e.toString().contains('requires-recent-login')) {
                      errorMessage = 'Please logout and login again to change password';
                    } else {
                      errorMessage = e.toString().replaceFirst('Exception: ', '');
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ $errorMessage'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change'),
            ),
          ],
        ),
      ),
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    if (!mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final authService = ref.read(firebaseAuthServiceProvider);
        await authService.signOut();
        if (mounted) {
          router.go('/login');
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

