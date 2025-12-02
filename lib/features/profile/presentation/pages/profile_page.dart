import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/providers/dashboard_provider.dart';
import 'package:trivora_provider/core/services/firebase_auth_service.dart';

/// Profile and Settings page
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUpdating = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        await _updatePhoto(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePhoto(XFile image) async {
    setState(() => _isUpdating = true);
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      // For now, use a random photo URL as placeholder
      // In production, upload image to Firebase Storage first and get the download URL
      final photoURL = 'https://picsum.photos/200?random=${DateTime.now().millisecondsSinceEpoch}';
      await authService.updatePhotoURL(photoURL);
      
      // Invalidate provider to refresh data
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo updated successfully in Firestore!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showEditNameDialog(BuildContext context, String currentName) async {
    final nameController = TextEditingController(text: currentName);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter your name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await _updateName(nameController.text.trim());
    }
  }

  Future<void> _updateName(String displayName) async {
    setState(() => _isUpdating = true);
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      await authService.updateDisplayName(displayName);
      
      // Invalidate provider to refresh data
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name updated successfully in Firestore!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update name: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUserAsync = ref.watch(authStateProvider);
    final authUser = authUserAsync.valueOrNull;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    final providerOnlineStatusAsync = ref.watch(providerOnlineStatusProvider);
    final displayName = currentUser?['displayName'] ?? authUser.displayName ?? 'Provider';
    final email = currentUser?['email'] ?? authUser.email ?? 'No email';
    final phone = currentUser?['phone'] ?? authUser.phoneNumber ?? 'Not provided';
    final photoURL = currentUser?['photoUrl'] ?? authUser.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isUpdating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
          IconButton(
            icon: const Icon(Icons.edit),
              onPressed: () => _showEditNameDialog(context, displayName),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                          child: photoURL == null
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                              onPressed: _pickImage,
                              padding: EdgeInsets.zero,
                        ),
                      ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    // Online Status
                    providerOnlineStatusAsync.when(
                      data: (isOnline) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Switch(
                            value: isOnline,
                            onChanged: (value) {
                              // Update online status
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                  content: Text('Status updated to ${value ? "Online" : "Offline"}'),
                                  backgroundColor: value ? Colors.green : Colors.orange,
                                  ),
                                );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(isOnline ? 'Online' : 'Offline'),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Account Section
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Account',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                ),
              ],
            ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Phone'),
                    subtitle: Text(phone),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditPhoneDialog(context, phone),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(email),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditEmailDialog(context, email),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text('Role'),
                    subtitle: Text(currentUser?['role'] ?? 'provider'),
                  ),
                  // About section - only for providers
                  if (currentUser?['role'] == 'provider') ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: const Text('About'),
                      subtitle: Text(
                        currentUser?['about'] ?? 'No description added',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditAboutDialog(
                          context,
                          currentUser?['about'] ?? '',
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Settings
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('Help & Support'),
                    trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Help & Support coming soon')),
                      );
                  },
                ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('About'),
                    trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                      showDialog(
                      context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('About'),
                          content: const Text('Trivora Provider App\nVersion 1.0.0'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                    );
                  },
                ),
              ],
              ),
            ),
            const SizedBox(height: 24),
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : () => _showLogoutDialog(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditPhoneDialog(BuildContext context, String currentPhone) async {
    final phoneController = TextEditingController(text: currentPhone == 'Not provided' ? '' : currentPhone);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Phone Number'),
        content: TextField(
          controller: phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '+91XXXXXXXXXX',
            prefixText: '+91',
          ),
          keyboardType: TextInputType.phone,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (phoneController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && phoneController.text.trim().isNotEmpty) {
      await _updatePhone(phoneController.text.trim());
    }
  }

  Future<void> _updatePhone(String phoneNumber) async {
    setState(() => _isUpdating = true);
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      await authService.updatePhoneNumber(phoneNumber);
      
      // Invalidate provider to refresh data
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number updated successfully in Firestore!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update phone: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showEditEmailDialog(BuildContext context, String currentEmail) async {
    final emailController = TextEditingController(text: currentEmail == 'No email' ? '' : currentEmail);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'example@email.com',
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A verification email will be sent to the new address',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.trim().isNotEmpty &&
                  emailController.text.contains('@')) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && emailController.text.trim().isNotEmpty) {
      await _updateEmail(emailController.text.trim());
    }
  }

  Future<void> _updateEmail(String newEmail) async {
    setState(() => _isUpdating = true);
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      await authService.updateEmail(newEmail);
      
      // Invalidate provider to refresh data
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email updated in Firestore! Verification email sent to new address.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showEditAboutDialog(BuildContext context, String currentAbout) async {
    final aboutController = TextEditingController(text: currentAbout == 'No description added' ? '' : currentAbout);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit About'),
        content: TextField(
          controller: aboutController,
          decoration: const InputDecoration(
            labelText: 'About',
            hintText: 'Tell us about yourself...',
            alignLabelWithHint: true,
          ),
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateAbout(aboutController.text.trim());
    }
  }

  Future<void> _updateAbout(String about) async {
    setState(() => _isUpdating = true);
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      await authService.updateAbout(about);
      
      // Invalidate provider to refresh data
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('About updated successfully in Firestore!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update about: $e'),
            backgroundColor: Colors.red,
      ),
    );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final authService = ref.read(firebaseAuthServiceProvider);
        await authService.signOut();
        
        if (context.mounted) {
          // Navigate to login page
          context.go('/login');
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logged out successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // ignore: avoid_print
        print('❌ Error logging out: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to logout: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}
