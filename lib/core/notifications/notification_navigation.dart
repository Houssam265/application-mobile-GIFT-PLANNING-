import '../router/app_router.dart';

Future<void> navigateFromNotification({
  String? action,
  String? listId,
  String? productId,
  String? suggestionId,
}) async {
  switch (action) {
    case 'join_request':
      if (listId != null && listId.isNotEmpty) {
        AppRouter.router.goNamed(
          AppRouteName.participantsManage,
          pathParameters: {'id': listId},
        );
        return;
      }
    case 'suggestion_created':
      if (listId != null && listId.isNotEmpty) {
        AppRouter.router.goNamed(
          AppRouteName.suggestionsManage,
          pathParameters: {'id': listId},
        );
        return;
      }
    case 'join_accepted':
    case 'join_refused':
    case 'suggestion_accepted':
    case 'suggestion_refused':
    case 'event_reminder':
    case 'list_auto_archived':
    case 'list_archived':
    case 'list_reactivated':
    case 'funding_incomplete_j1':
    case 'contribution_received':
    case 'product_added':
    case 'product_fully_funded':
    case 'product_funding_dropped':
      if (listId != null && listId.isNotEmpty) {
        AppRouter.router.goNamed(
          AppRouteName.listDetail,
          pathParameters: {'id': listId},
        );
        return;
      }
  }

  if (listId != null && listId.isNotEmpty) {
    AppRouter.router.goNamed(
      AppRouteName.listDetail,
      pathParameters: {'id': listId},
    );
    return;
  }

  if (productId != null && productId.isNotEmpty) {
    AppRouter.router.goNamed(
      AppRouteName.product,
      pathParameters: {'id': productId},
    );
    return;
  }

  if (suggestionId != null && suggestionId.isNotEmpty) {
    AppRouter.router.goNamed(AppRouteName.notificationsCenter);
    return;
  }

  AppRouter.router.goNamed(AppRouteName.notificationsCenter);
}
