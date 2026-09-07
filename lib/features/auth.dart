import 'package:flutter/material.dart';
import '../app/scope.dart';
import '../core/theme.dart';
import '../data/accounts.dart';
import '../l10n/strings.dart';
import '../shared/widgets.dart';

/// Signing up and signing in.
///
/// One screen with two modes, because the difference between them is two
/// fields and a verb, and a supporter who taps the wrong one should not have
/// to go anywhere to correct it.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool creating = true, busy = false, revealPassword = false;
  String? errorKey;
  final identity = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    identity.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final accounts = AppScope.of(context).accounts;
    if (accounts == null) return;
    setState(() {
      busy = true;
      errorKey = null;
    });
    try {
      if (creating) {
        await accounts.signUp(
          username: identity.text,
          email: email.text,
          password: password.text,
        );
      } else {
        await accounts.signIn(
          usernameOrEmail: identity.text,
          password: password.text,
        );
      }
      // The app listens to the gateway, so a successful call re-routes on its
      // own. Nothing to navigate here.
    } on AccountFailure catch (e) {
      if (mounted) setState(() => errorKey = e.messageKey);
    } catch (_) {
      if (mounted) setState(() => errorKey = 'authFailed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
        children: [
          const Text(
            'jüri',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -3.5,
            ),
          ),
          const SizedBox(height: 28),
          Headline(Tr.t('authWelcome'), size: 52),
          const SizedBox(height: 14),
          Text(
            Tr.t('authWelcomeBody'),
            style: const TextStyle(
              color: JuriTheme.muted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 30),
          _field(
            key: const Key('authIdentity'),
            controller: identity,
            label: creating ? Tr.t('username') : Tr.t('usernameOrEmail'),
            hint: creating ? Tr.t('usernameHint') : null,
            autofill: creating
                ? const [AutofillHints.newUsername]
                : const [AutofillHints.username],
          ),
          if (creating) ...[
            const SizedBox(height: 16),
            _field(
              key: const Key('authEmail'),
              controller: email,
              label: Tr.t('email'),
              hint: Tr.t('emailWhy'),
              keyboardType: TextInputType.emailAddress,
              autofill: const [AutofillHints.email],
            ),
          ],
          const SizedBox(height: 16),
          _field(
            key: const Key('authPassword'),
            controller: password,
            label: Tr.t('password'),
            hint: creating ? Tr.t('passwordHint') : null,
            obscure: !revealPassword,
            autofill: creating
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            trailing: IconButton(
              onPressed: () =>
                  setState(() => revealPassword = !revealPassword),
              icon: Icon(
                revealPassword ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: JuriTheme.muted,
              ),
            ),
          ),
          if (errorKey != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: JuriTheme.elevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JuriTheme.gold.withValues(alpha: .4)),
              ),
              child: Text(
                Tr.t(errorKey!),
                key: const Key('authError'),
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 26),
          FilledButton(
            key: const Key('authSubmit'),
            onPressed: busy ? null : _submit,
            child: busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: JuriTheme.background,
                    ),
                  )
                : Text(Tr.t(creating ? 'signUp' : 'signIn')),
          ),
          const SizedBox(height: 10),
          TextButton(
            key: const Key('authToggle'),
            onPressed: busy
                ? null
                : () => setState(() {
                    creating = !creating;
                    errorKey = null;
                  }),
            child: Text(
              Tr.t(creating ? 'haveAccount' : 'noAccount'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    List<String>? autofill,
    Widget? trailing,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 7),
      TextField(
        key: key,
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofill,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(suffixIcon: trailing),
      ),
      if (hint != null) ...[
        const SizedBox(height: 6),
        Text(
          hint,
          style: const TextStyle(fontSize: 10, color: JuriTheme.muted),
        ),
      ],
    ],
  );
}
