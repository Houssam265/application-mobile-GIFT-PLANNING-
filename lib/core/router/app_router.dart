import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/presentation/register_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Login — GP-04')),
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Dashboard — GP-17')),
        ),
      ),
      GoRoute(
        path: '/join/:code',
        name: 'join',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('Aperçu liste — code: ${state.pathParameters['code']}'),
          ),
        ),
      ),
    ],
  );
}