import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../data/repository.dart';
import '../features/auth/sign_in_page.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/add_vehicle_page.dart';
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
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, _) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const SignInPage();
        return const _RegisteredGate();
      },
    );
  }
}

class _RegisteredGate extends StatelessWidget {
  const _RegisteredGate();

  bool _hasName(SupabaseClient client) {
    final user = client.auth.currentUser;
    final raw = user?.userMetadata?['name'];
    final name = raw is String ? raw.trim() : '';
    return name.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    if (!_hasName(client)) {
      return const WelcomePage();
    }

    final repo = SupabaseRepository.ofDefaultClient();
    return FutureBuilder(
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

        if (vehicles.isEmpty) {
          return const AddVehiclePage(goHomeOnComplete: true);
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
