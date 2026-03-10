import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
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
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Mot de passe oublié — GP-05')),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        name: AppRouteName.resetPassword,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Réinitialisation mot de passe (deep link) — GP-05')),
        ),
      ),

      // ── Dashboard / Home (utilisateur connecté) ─────────────
      GoRoute(
        path: '/home',
        name: AppRouteName.home,
        builder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Dashboard — GP-17'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Se déconnecter'),
                )
              ],
            ),
          ),
        ),
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
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Créer une liste — GP-13')),
        ),
      ),
      GoRoute(
        path: '/list/:id',
        name: AppRouteName.listDetail,
        builder: (context, state) {
          final listId = state.pathParameters['id'] ?? '';
          return Scaffold(
            body: Center(
              child: Text('Détail Liste $listId — GP-14 / GP-15'),
            ),
          );
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
          return Scaffold(
            body: Center(
              child: Text('Ajouter un produit à la liste $listId — GP-21'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/list/:listId/product/:id/edit',
        name: AppRouteName.productEdit,
        builder: (context, state) {
          final listId = state.pathParameters['listId'] ?? '';
          final productId = state.pathParameters['id'] ?? '';
          return Scaffold(
            body: Center(
              child: Text('Modifier produit $productId de la liste $listId — GP-22'),
            ),
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

      // ── Participants & invitations ──────────────────────────
      GoRoute(
        path: '/list/:id/participants',
        name: AppRouteName.participantsManage,
        builder: (context, state) {
          final listId = state.pathParameters['id'] ?? '';
          return Scaffold(
            body: Center(
              child: Text('Gestion des participants pour la liste $listId — GP-32 / GP-33 / GP-34'),
            ),
          );
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

      final isLoggingIn =
          location == '/login' || location == '/register';
      final isJoinPreview = location.startsWith('/join/');

      final user = Supabase.instance.client.auth.currentUser;

      // Utilisateur non connecté
      if (user == null) {
        // Routes publiques autorisées sans session
        if (isLoggingIn || isJoinPreview) {
          return null;
        }

        // Toute autre route nécessite une auth → on redirige vers /login
        final from = uri.toString();
        if (from == '/login') {
          return null;
        }
        return '/login?redirect=$from';
      }

      // Utilisateur connecté
      final role = (user.userMetadata?['role'] as String?) ?? 'user';

      // Si connecté, empêcher retour sur login/register
      if (isLoggingIn) {
        if (role == 'admin') {
          return '/admin';
        }
        return '/home';
      }

      // Redirection des admins vers leur dashboard dédié pour la home.
      if (role == 'admin' && location == '/home') {
        return '/admin';
      }

      return null;
    },
  );
}