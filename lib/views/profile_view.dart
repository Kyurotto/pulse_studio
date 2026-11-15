import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/app_theme.dart';
import 'accounts_view.dart';
import 'settings_view.dart';

/// Full-screen account overview reached from the left drawer.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ProfileView());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceOf(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimaryOf(context),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'View Profile',
          style: TextStyle(
            color: AppTheme.textPrimaryOf(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.borderOf(context)),
        ),
      ),
      body: StreamBuilder<Object?>(
        stream: AuthService.instance.authChanges,
        initialData: AuthService.instance.currentUser,
        builder: (context, snapshot) {
          final displayName = AuthService.instance.userDisplayName;
          final email = AuthService.instance.userEmail;
          final backupEmail = AuthService.instance.userBackupEmail;
          final phone = AuthService.instance.userPhoneNumber;
          final role = AuthService.instance.userRole;
          final initials = AuthService.instance.userInitials;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceOf(context),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.borderOf(context)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryOf(context).withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email.isEmpty ? 'No email on file' : email,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOf(context).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryOf(context).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              role.isEmpty ? 'LISTENER' : role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: role == 'admin'
                                    ? Colors.amber
                                    : AppTheme.primaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceOf(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.borderOf(context)),
                      ),
                      child: Column(
                        children: [
                          _ProfileInfoRow(
                            icon: Icons.alternate_email_rounded,
                            label: 'Primary email',
                            value: email.isEmpty ? 'Not set' : email,
                          ),
                          Divider(height: 1, color: AppTheme.borderOf(context)),
                          _ProfileInfoRow(
                            icon: Icons.mark_email_read_outlined,
                            label: 'Backup email',
                            value: backupEmail.isEmpty
                                ? 'Not set'
                                : backupEmail,
                          ),
                          Divider(height: 1, color: AppTheme.borderOf(context)),
                          _ProfileInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone number',
                            value: phone.isEmpty ? 'Not set' : phone,
                          ),
                          Divider(height: 1, color: AppTheme.borderOf(context)),
                          _ProfileInfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Account type',
                            value:
                                '${role.isEmpty ? 'Listener' : role} · local account',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          SettingsView.show(context, openProfileEdit: true),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Profile'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryOf(context),
                        foregroundColor: AppTheme.isDark(context) ? Colors.black87 : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).push(AccountsView.route()),
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text('Manage Accounts'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimaryOf(context),
                        side: BorderSide(color: AppTheme.borderOf(context)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.cardSurfaceOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
