import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  // Initialisation de OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(SupabaseConstants.oneSignalAppId);
  await OneSignal.Notifications.requestPermission(true);

  // Écoute des changements d'état d'authentification pour OneSignal
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.userUpdated) {
      if (session?.user != null) {
        final userId = session!.user.id;
        // Au login : appel OneSignal.login(userId) pour lier userId Supabase
        OneSignal.login(userId);

        // Stocker playerId dans la table profiles (utilisateurs)
        final playerId = OneSignal.User.pushSubscription.id;
        if (playerId != null && playerId.isNotEmpty) {
          try {
            await Supabase.instance.client
                .from('utilisateurs')
                .update({'player_id': playerId})
                .eq('id', userId);
          } catch (e) {
            debugPrint("Erreur stockage playerId: $e");
          }
        }
      }
    } else if (event == AuthChangeEvent.signedOut) {
      // Au logout : OneSignal.logout()
      OneSignal.logout();
    }
  });

  // Listener si le playerId est attribué de manière asynchrone après le login
  OneSignal.User.pushSubscription.addObserver((state) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final playerId = state.current.id;
    if (currentUserId != null && playerId != null && playerId.isNotEmpty) {
      try {
        await Supabase.instance.client
            .from('utilisateurs')
            .update({'player_id': playerId})
            .eq('id', currentUserId);
      } catch (e) {
        debugPrint("Erreur maj playerId pushSubscription: $e");
      }
    }
  });

  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GiftPlan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}