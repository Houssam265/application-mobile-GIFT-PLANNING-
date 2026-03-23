<<<<<<< Updated upstream
=======
import 'dart:async';

import 'package:flutter/foundation.dart';
>>>>>>> Stashed changes
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
<<<<<<< Updated upstream
=======
  if (kIsWeb) {
    usePathUrlStrategy();
  }
>>>>>>> Stashed changes

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

<<<<<<< Updated upstream
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
=======
  if (!kIsWeb) {
    await _initOneSignal();
  }

  runApp(const ProviderScope(child: App()));
}

/// Clé globale pour les SnackBars (toasts GP-19) au-dessus des routes.
final GlobalKey<ScaffoldMessengerState> giftplanScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> _initOneSignal() async {
  try {
    // Initialisation de OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(SupabaseConstants.oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);

    // Écoute des changements d'état d'authentification pour OneSignal
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        if (session?.user != null) {
          final userId = session!.user.id;
          OneSignal.login(userId);

          final playerId = OneSignal.User.pushSubscription.id;
          if (playerId != null && playerId.isNotEmpty) {
            try {
              await Supabase.instance.client
                  .from('utilisateurs')
                  .update({'player_id': playerId})
                  .eq('id', userId);
            } catch (e) {
              debugPrint('Erreur stockage playerId: $e');
            }
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
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
          debugPrint('Erreur maj playerId pushSubscription: $e');
        }
      }
    });

    // Navigation au clic sur notification push OneSignal.
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null) {
        final listId = data['listId'] as String?;
        final eventType = data['event'] as String?;

        if (listId != null && eventType == 'join_request') {
          AppRouter.router.pushNamed(
            AppRouteName.participantsManage,
            pathParameters: {'id': listId},
          );
        }
      }
    });
  } on MissingPluginException catch (e) {
    debugPrint('OneSignal indisponible sur cette plateforme: $e');
  } catch (e) {
    debugPrint('Erreur initialisation OneSignal: $e');
  }
}

class App extends ConsumerStatefulWidget {
>>>>>>> Stashed changes
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