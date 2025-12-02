import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/language_service.dart';
import 'package:trivora_provider/core/services/notification_service.dart';
import 'package:trivora_provider/core/config/app_config.dart';

/// Settings Page - Manage provider settings
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final currentLanguage = ref.watch(currentLanguageProvider);
    
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view settings')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _buildSection(
            context,
            title: 'Account',
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.person,
                title: 'Profile Settings',
                subtitle: 'Update your personal information',
                onTap: () {
                  context.push('/profile');
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () {
                  _showNotificationsSettings(context, ref);
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.lock,
                title: 'Privacy & Security',
                subtitle: 'Manage your privacy and security settings',
                onTap: () {
                  context.push('/settings/privacy-security');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Services Section
          _buildSection(
            context,
            title: 'Services',
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.build,
                title: 'My Services',
                subtitle: 'Manage your services',
                onTap: () {
                  context.push('/services');
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.payment,
                title: 'Payment Methods',
                subtitle: 'Manage payment options',
                onTap: () {
                  context.push('/settings/payment-methods');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // App Section
          _buildSection(
            context,
            title: 'App',
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.language,
                title: 'Language',
                subtitle: currentLanguage.name,
                onTap: () {
                  _showLanguageSettings(context, ref);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // About Section
          _buildSection(
            context,
            title: 'About',
            children: [
              // Add about items here if needed
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showNotificationsSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _NotificationsSettingsDialog(),
    );
  }

  void _showLanguageSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _LanguageSelectionDialog(),
    );
  }
}

class _NotificationsSettingsDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NotificationsSettingsDialog> createState() => _NotificationsSettingsDialogState();
}

class _NotificationsSettingsDialogState extends ConsumerState<_NotificationsSettingsDialog> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _inAppNotifications = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) return;

    try {
      // Try to get from Firestore directly
      final doc = await FirebaseFirestore.instance
          .collection(AppConfig.providersCollection)
          .doc(authUser.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data() ?? {};
        final notificationPrefs = data['notificationPreferences'] as Map<String, dynamic>?;
        
        if (notificationPrefs != null) {
          setState(() {
            _pushNotifications = notificationPrefs['push'] as bool? ?? true;
            _emailNotifications = notificationPrefs['email'] as bool? ?? true;
            _inAppNotifications = notificationPrefs['inApp'] as bool? ?? true;
          });
          return;
        }
      }
      
      // Fallback to defaults
      setState(() {
        _pushNotifications = true;
        _emailNotifications = true;
        _inAppNotifications = true;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error loading notification preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.updateNotificationPreferences(
        authUser.uid,
        {
          'push': _pushNotifications,
          'email': _emailNotifications,
          'inApp': _inAppNotifications,
        },
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification preferences saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notifications'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications on your device'),
              value: _pushNotifications,
              onChanged: _isLoading ? null : (value) {
                setState(() {
                  _pushNotifications = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive notifications via email'),
              value: _emailNotifications,
              onChanged: _isLoading ? null : (value) {
                setState(() {
                  _emailNotifications = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('In-App Notifications'),
              subtitle: const Text('Show notifications within the app'),
              value: _inAppNotifications,
              onChanged: _isLoading ? null : (value) {
                setState(() {
                  _inAppNotifications = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _savePreferences,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _LanguageSelectionDialog extends ConsumerWidget {
  const _LanguageSelectionDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(currentLanguageProvider);
    const availableLanguages = AppLanguage.values;

    return AlertDialog(
      title: const Text('Select Language'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: availableLanguages.map((language) {
          return RadioListTile<AppLanguage>(
            title: Text(language.name),
            subtitle: Text(language.code.toUpperCase()),
            value: language,
            groupValue: currentLanguage,
            onChanged: (value) async {
              if (value != null) {
                try {
                  await ref.read(currentLanguageProvider.notifier).changeLanguage(value);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Language changed to ${value.name}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error changing language: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
