import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/lists/presentation/list_create_screen.dart';
import '../../features/lists/presentation/list_detail_screen.dart';
import '../../features/products/domain/product_model.dart';
import '../../features/products/presentation/add_product_screen.dart';
import '../../features/lists/presentation/participants_manage_screen.dart';
import 'go_router_refresh_stream.dart';

/// Noms centralisés des routes principales de l'application.
class AppRouteName {
  static const login = 'login';
  static const register = 'register';
  static const forgotPassword = 'forgot-password';
  static const resetPassword = 'reset-password';

  static const home = 'home';

  // Profil & compte
  static const profile = 'profile';

  // Notifications
  static const notificationsCenter = 'notifications-center';

  // Listes
  static const listsDashboard = 'lists-dashboard';
  static const listCreate = 'list-create';
  static const listDetail = 'list-detail';
  static const listEdit = 'list-edit';
  static const listsArchived = 'lists-archived';

  // Produits
  static const productAdd = 'product-add';
  static const productEdit = 'product-edit';
  static const product = 'product';

  // Contributions
  static const contribute = 'contribute';
  static const contributionsHistory = 'contributions-history';

  // Participants & invitations
  static const participantsManage = 'participants-manage';
  static const joinRequests = 'join-requests';

  // Deep link public
  static const join = 'join';

  // Admin
  static const adminDashboard = 'admin-dashboard';
  static const adminUsers = 'admin-users';
  static const adminLists = 'admin-lists';
  static const adminStats = 'admin-stats';
  static const adminLogs = 'admin-logs';
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login', // Remis sur /login par défaut
    // Rafraîchir l'arbre de routage automatiquement à chaque changement d'état d'auth (login / logout)
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    routes: [
      // ── Auth ────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: AppRouteName.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: AppRouteName.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: AppRouteName.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: AppRouteName.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // ── Dashboard / Home (utilisateur connecté) ─────────────
      GoRoute(
        path: '/home',
        name: AppRouteName.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/dashboard/lists',
        name: AppRouteName.listsDashboard,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Mes listes / Listes rejointes / Archivées — GP-17')),
        ),
      ),

      // ── Profil utilisateur ─────────────────────────────────
      GoRoute(
        path: '/profile',
        name: AppRouteName.profile,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Profil utilisateur — GP-06 / GP-07')),
        ),
      ),

      // ── Centre de notifications ────────────────────────────
      GoRoute(
        path: '/notifications',
        name: AppRouteName.notificationsCenter,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Centre de notifications — GP-09 / GP-10 / GP-19')),
        ),
      ),

      // ── Listes de souhaits ─────────────────────────────────
      GoRoute(
        path: '/list/new',
        name: AppRouteName.listCreate,
        builder: (context, state) => const ListCreateScreen(),
      ),
      GoRoute(
        path: '/list/:id',
        name: AppRouteName.listDetail,
        builder: (context, state) {
          final listId = state.pathParameters['id'] ?? '';
          return ListDetailScreen(listId: listId);
        },
      ),
      GoRoute(
        path: '/list/:id/edit',
        name: AppRouteName.listEdit,
        builder: (context, state) {
          final listId = state.pathParameters['id'] ?? '';
          return Scaffold(
            body: Center(
              child: Text('Éditer Liste $listId — GP-14 / GP-15'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/lists/archived',
        name: AppRouteName.listsArchived,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Listes archivées — GP-15')),
        ),
      ),

      // ── Produits ───────────────────────────────────────────
      GoRoute(
        path: '/list/:listId/product/new',
        name: AppRouteName.productAdd,
        builder: (context, state) {
          final listId = state.pathParameters['listId'] ?? '';
          return AddProductScreen(listId: listId);
        },
      ),
      GoRoute(
        path: '/list/:listId/product/:id/edit',
        name: AppRouteName.productEdit,
        builder: (context, state) {
          final listId = state.pathParameters['listId'] ?? '';
          final product = state.extra as ProductModel?;
          return AddProductScreen(
            listId: listId,
            existingProduct: product,
          );
        },
      ),
      GoRoute(
        path: '/product/:id',
        name: AppRouteName.product,
        builder: (context, state) {
          final productId = state.pathParameters['id'] ?? '';
          return Scaffold(
            body: Center(
              child: Text('Produit $productId — GP-21 / GP-22'),
            ),
          );
        },
      ),

      // ── Contributions ───────────────────────────────────────
      GoRoute(
        path: '/product/:id/contribute',
        name: AppRouteName.contribute,
        builder: (context, state) {
          final productId = state.pathParameters['id'] ?? '';
          return Scaffold(
            body: Center(
              child: Text('Contribuer au produit $productId — GP-27 / GP-28'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/contributions/history',
        name: AppRouteName.contributionsHistory,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Historique des contributions — GP-29')),
        ),
      ),

      GoRoute(
        path: '/list/:id/participants',
        name: AppRouteName.participantsManage,
        builder: (context, state) {
          final listId = state.pathParameters['id'] ?? '';
          return ParticipantsManageScreen(listId: listId);
        },
      ),
      GoRoute(
        path: '/list/:id/join-requests',
        name: AppRouteName.joinRequests,
        builder: (context, state) {
          final listId = state.pathParameters['id'] ?? '';
          return Scaffold(
            body: Center(
              child: Text('Demandes d’adhésion pour la liste $listId — GP-32 / GP-33'),
            ),
          );
        },
      ),

      // ── Deep link invitation / aperçu public ────────────────
      GoRoute(
        path: '/join/:code',
        name: AppRouteName.join,
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return Scaffold(
            body: Center(
              child: Text('Aperçu liste — code: $code — GP-16 / GP-32'),
            ),
          );
        },
      ),

      // ── Tableau de bord Administrateur ──────────────────────
      GoRoute(
        path: '/admin',
        name: AppRouteName.adminDashboard,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Admin Dashboard — GP-37 / GP-38 / GP-39')),
        ),
      ),
      GoRoute(
        path: '/admin/users',
        name: AppRouteName.adminUsers,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Admin — Gestion utilisateurs — GP-37')),
        ),
      ),
      GoRoute(
        path: '/admin/lists',
        name: AppRouteName.adminLists,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Admin — Gestion listes — GP-38')),
        ),
      ),
      GoRoute(
        path: '/admin/stats',
        name: AppRouteName.adminStats,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Admin — Statistiques & graphiques — GP-38')),
        ),
      ),
      GoRoute(
        path: '/admin/logs',
        name: AppRouteName.adminLogs,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Admin — Journal d’activité — GP-39')),
        ),
      ),
    ],

    /// Guards globaux d'authentification & rôle (user/admin).
    redirect: (context, state) {
      final uri = state.uri;
      final location = uri.path;

      // Définir quelles routes sont publiques, ou liées au processus de connexion classique
      final isPublicAuthRoute =
          location == '/login' || location == '/register' || location == '/forgot-password';
      
      final isResetPasswordRoute = location == '/reset-password';
      final isJoinPreview = location.startsWith('/join/');

      final user = Supabase.instance.client.auth.currentUser;

      // ── CAS 1 : Utilisateur NON connecté ──
      if (user == null) {
        // Autoriser l'accès aux pages publiques d'authentification et de preview Join
        if (isPublicAuthRoute || isJoinPreview || isResetPasswordRoute) {
          return null; 
        }

        // Pour toute autre route privée, on redirige vers le login en retenant la route d'origine
        final from = uri.toString();
        if (from == '/login') return null; // Sécurité supplémentaire
        return '/login?redirect=$from';
      }

      // ── CAS 2 : Utilisateur CONNECTÉ ──
      final role = (user.userMetadata?['role'] as String?) ?? 'user';

      // S'il est connecté ET qu'il arrive sur /reset-password (suite au clic sur le mail de Supabase)
      // On le laisse accéder à la page pour modifier son mot de passe, on ne le renvoie pas sur /home !
      if (isResetPasswordRoute) {
        return null;
      }

      // S'il est connecté mais qu'il tape l'URL de login/register/forgot-password, on l'envoie sur home
      if (isPublicAuthRoute) {
        if (role == 'admin') return '/admin';
        return '/home';
      }

      // Redirection spécifique pour les admins qui tentent d'aller sur la home standard
      if (role == 'admin' && location == '/home') {
        return '/admin';
      }

      return null;
    },
  );
}