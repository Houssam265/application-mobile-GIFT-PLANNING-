import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:app_links/app_links.dart';
import 'core/constants/supabase_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/domain/notifications_notifier.dart';

void _handleDeepLink(Uri uri) {
  if (uri.scheme == 'giftplan') {
    if (uri.host == 'reset-password' || uri.host == 'reset-callback') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.router.go('/reset-password');
      });
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
    // L’email de reset envoie des tokens en fragment (#access_token=…), flux implicite.
    // Avec PKCE par défaut, le deep link est ignoré et la session n’est pas restaurée.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  final appLinks = AppLinks();

  appLinks.uriLinkStream.listen((uri) {
    _handleDeepLink(uri);
  });

  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    _handleDeepLink(initialUri);
  }

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
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(SupabaseConstants.oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);

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

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data == null) return;
      final listId = data['listId'] as String?;
      final eventType = data['event'] as String?;
      if (eventType == null) return;

      final productId = data['productId'] as String?;

      switch (eventType) {
        case 'join_request':
          if (listId == null) return;
          AppRouter.router.pushNamed(
            AppRouteName.participantsManage,
            pathParameters: {'id': listId},
          );
        case 'suggestion_new':
          if (listId == null) return;
          AppRouter.router.pushNamed(
            AppRouteName.suggestionsManage,
            pathParameters: {'id': listId},
          );
        case 'join_accepted':
        case 'join_refused':
        case 'suggestion_accepted':
        case 'suggestion_refused':
        case 'event_reminder':
        case 'list_auto_archived':
        case 'list_archived':
        case 'funding_incomplete_j1':
          if (listId == null) return;
          AppRouter.router.pushNamed(
            AppRouteName.listDetail,
            pathParameters: {'id': listId},
          );
        case 'contribution_new':
        case 'product_fully_funded':
        case 'product_funding_dropped':
          if (productId != null && productId.isNotEmpty) {
            AppRouter.router.pushNamed(
              AppRouteName.product,
              pathParameters: {'id': productId},
            );
          } else if (listId != null) {
            AppRouter.router.pushNamed(
              AppRouteName.listDetail,
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


  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        ref.read(notificationsNotifierProvider.notifier).bind();
      } else if (data.event == AuthChangeEvent.signedOut) {
        ref.read(notificationsNotifierProvider.notifier).unbind();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Supabase.instance.client.auth.currentUser != null) {
        ref.read(notificationsNotifierProvider.notifier).bind();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NotificationsUiState>(notificationsNotifierProvider, (previous, next) {
      final msg = next.pendingToast;
      if (msg != null && msg.isNotEmpty) {
        giftplanScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(notificationsNotifierProvider.notifier).clearPendingToast();
      }
    });

    return MaterialApp.router(
      title: 'GiftPlan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      scaffoldMessengerKey: giftplanScaffoldMessengerKey,
    );
  }
}