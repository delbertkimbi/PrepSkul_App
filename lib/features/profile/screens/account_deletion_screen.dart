import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/supabase_service.dart';
import '../../support/screens/help_support_screen.dart';

/// A deletion request is reviewed by support; this screen never deletes data.
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});
  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _details = TextEditingController();
  String? _reason;
  bool _confirmed = false;
  bool _opening = false;
  String? _status;
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_opening || !_confirmed) return;
    setState(() {
      _opening = true;
      _status = null;
    });
    final user = SupabaseService.currentUser;
    final body =
        'Please review my account deletion request.\n\n'
        'Account ID: ${user?.id ?? "Not available"}\n'
        'Account email: ${user?.email ?? "Phone account"}\n'
        'Reason: ${_reason ?? "Prefer not to say"}\n'
        'Details: ${_details.text.trim()}\n\n'
        'I understand this is a request for manual review. Please contact me to confirm identity and explain the next steps.';
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: 'info@prepskul.com',
        query:
            'subject=${Uri.encodeComponent("Account deletion request")}&body=${Uri.encodeComponent(body)}',
      );
      final opened = await launchUrl(uri);
      if (mounted)
        setState(
          () => _status = opened
              ? 'Your email draft is ready. Send it in your email app to submit the request. Your account has not been deleted.'
              : 'Could not open email. Contact info@prepskul.com to request deletion.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _status =
              'Could not open email. Contact info@prepskul.com to request deletion.',
        );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delete account')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Before you go',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Need help with lessons, payments or your account? Our team can help. You can also continue with your deletion request.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              ),
              child: const Text('Talk to support'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Why are you leaving? (optional)',
              ),
              items:
                  const [
                        'Technical problems',
                        'Learning experience',
                        'Cost',
                        'Privacy',
                        'No longer needed',
                        'Prefer not to say',
                      ]
                      .map(
                        (reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _reason = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Anything we should know? (optional)',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Our team reviews deletion requests manually. We will confirm your identity and explain what happens to your account and learning data before processing it.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (value) => setState(() => _confirmed = value ?? false),
              title: const Text('I want to request account deletion'),
            ),
            FilledButton(
              onPressed: _confirmed && !_opening ? _request : null,
              child: Text(
                _opening ? 'Opening email…' : 'Prepare deletion request',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This opens an email draft to info@prepskul.com. You must send it to submit your request.',
              style: TextStyle(fontSize: 12),
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_status!),
              ),
          ],
        ),
      ),
    ),
  );
}
