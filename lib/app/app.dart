import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../features/auth/sign_in_page.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/add_vehicle_page.dart';
import '../features/onboarding/complete_vehicle_data_page.dart';
import '../features/onboarding/setup_preferences_page.dart';
import '../features/onboarding/welcome_page.dart';
import 'theme.dart';

class BensinKuApp extends StatelessWidget {
  const BensinKuApp({
    super.key,
    required this.config,
    required this.supabaseReady,
  });

  final AppConfig config;
  final bool supabaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BensinKu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: supabaseReady ? const _AuthGate() : const _ConfigMissingPage(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen(_onAuth);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onAuth(AuthState data) {
    if (!mounted) return;

    final newSession = data.session;
    final wasSignedIn = _session != null;
    final nowSignedIn = newSession != null;

    setState(() => _session = newSession);

    // When transitioning to signed-out: aggressively pop all pushed routes
    // so any cached HomeShell / ProfileTab / etc. don't linger on top of
    // the rebuilt SignInPage. Without this users get stuck on a stale
    // HomeShell with no data until they restart the app.
    if (wasSignedIn && !nowSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Navigator.of(context, rootNavigator: true);
        nav.popUntil((r) => r.isFirst);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return const SignInPage();
    // Key forces a fresh subtree on each session id so post-login data
    // fetches start clean instead of reusing whatever was cached for a
    // prior session.
    return _RegisteredGate(key: ValueKey(_session!.user.id));
  }
}

class _RegisteredGate extends StatefulWidget {
  const _RegisteredGate({super.key});

  @override
  State<_RegisteredGate> createState() => _RegisteredGateState();
}

class _RegisteredGateState extends State<_RegisteredGate> {
  // Bumped to force the FutureBuilder below to re-fetch vehicles after the
  // user completes a forced top-up form.
  int _refreshKey = 0;

  bool _hasName(SupabaseClient client) {
    final user = client.auth.currentUser;
    final raw = user?.userMetadata?['name'];
    final name = raw is String ? raw.trim() : '';
    return name.isNotEmpty;
  }

  bool _hasRequiredPreferences(SupabaseClient client) {
    final meta = client.auth.currentUser?.userMetadata;
    final usage = meta?['usage_profile'];
    final city = meta?['primary_city'];
    return usage is String &&
        usage.trim().isNotEmpty &&
        city is String &&
        city.trim().isNotEmpty;
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    // Step 1: must have a display name.
    if (!_hasName(client)) {
      return const WelcomePage();
    }

    final repo = SupabaseRepository.ofDefaultClient();
    return FutureBuilder(
      key: ValueKey('vehicles-$_refreshKey'),
      future: repo.listVehicles(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('BensinKu')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.error.toString()),
            ),
          );
        }

        final vehicles = snapshot.data;
        if (vehicles == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Step 2: must have at least one vehicle.
        if (vehicles.isEmpty) {
          return AddVehiclePage(
            goHomeOnComplete: true,
            onCompleted: _refresh,
          );
        }

        // Step 3: every vehicle must have complete reference data.
        final incomplete = vehicles
            .where((v) => !v.hasCompleteReferenceData)
            .toList();
        if (incomplete.isNotEmpty) {
          return CompleteVehicleDataPage(
            vehicle: incomplete.first,
            remainingCount: incomplete.length,
            onSaved: _refresh,
          );
        }

        // Step 4: must have completed required preferences.
        if (!_hasRequiredPreferences(client)) {
          return SetupPreferencesPage(onCompleted: _refresh);
        }

        return const HomeShell();
      },
    );
  }
}

class _ConfigMissingPage extends StatelessWidget {
  const _ConfigMissingPage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('BensinKu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supabase belum dikonfigurasi.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Jalankan app dengan dart-define berikut:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SelectableText(
                'flutter run --dart-define-from-file=supabase.defines.json\n\n'
                '# atau (manual)\n'
                'flutter run --dart-define=SUPABASE_URL=... \\\n+  --dart-define=SUPABASE_ANON_KEY=...\n',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Catatan: SUPABASE_ANON_KEY aman disimpan di client (Flutter). Jangan pernah pakai service_role key di app.',
            ),
          ],
        ),
      ),
    );
  }
}
