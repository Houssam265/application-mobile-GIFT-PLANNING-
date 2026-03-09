import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Login — GP-04')),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Register — GP-02')),
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