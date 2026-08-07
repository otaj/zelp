import 'package:flutter/material.dart';

/// Email/password form and optional pairing-keys checkbox for Settings.
class SettingsAccountForm extends StatelessWidget {
  const SettingsAccountForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.fetchKeys,
    required this.enabled,
    required this.onToggleObscurePassword,
    required this.onFetchKeysChanged,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool fetchKeys;
  final bool enabled;
  final VoidCallback onToggleObscurePassword;
  final ValueChanged<bool> onFetchKeysChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            TextFormField(
              controller: emailController,
              enabled: enabled,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your Amazfit email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              enabled: enabled,
              obscureText: obscurePassword,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: onToggleObscurePassword,
                  icon: Icon(
                    obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your password';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: fetchKeys,
        onChanged: enabled ? (bool? value) => onFetchKeysChanged(value ?? false) : null,
        title: const Text('Also fetch Bluetooth pairing keys'),
        subtitle: const Text(
          'Optional — shown here for Gadgetbridge and similar apps',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    ],
  );
}
