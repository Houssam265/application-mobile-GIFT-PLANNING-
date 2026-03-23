import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/join_code_parser.dart';
import 'qr_scan_screen.dart';

/// Actions pour rejoindre une liste : scan QR ou saisie du code → route `/join/:code`.
Future<void> showJoinListEntrySheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Rejoindre une liste',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2E86AB)),
                title: const Text('Scanner un QR code'),
                subtitle: const Text('Utilise le QR partagé par le propriétaire'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final code = await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (_) => const QrScanScreen()),
                  );
                  if (!context.mounted || code == null) return;
                  context.pushNamed(
                    AppRouteName.join,
                    pathParameters: {'code': code},
                  );
                },
              ),
            ListTile(
              leading: Icon(
                Icons.keyboard_alt_outlined,
                color: kIsWeb ? const Color(0xFF2E86AB) : Colors.grey.shade700,
              ),
              title: const Text('Saisir le code de la liste'),
              subtitle: const Text('Code alphanumérique (ex. partage de lien)'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showEnterCodeDialog(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

void _showEnterCodeDialog(BuildContext context) {
  final controller = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        title: const Text('Code de la liste'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Ex. A1B2C3D4 ou collez un lien',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitCode(context, dialogCtx, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => _submitCode(context, dialogCtx, controller.text),
            child: const Text('Voir l’aperçu'),
          ),
        ],
      );
    },
  );
}

void _submitCode(BuildContext originContext, BuildContext dialogCtx, String raw) {
  final code = extractJoinCode(raw);
  if (code == null) {
    ScaffoldMessenger.of(originContext).showSnackBar(
      const SnackBar(
        content: Text('Code ou lien non reconnu. Vérifiez la saisie.'),
      ),
    );
    return;
  }
  Navigator.of(dialogCtx).pop();
  originContext.pushNamed(
    AppRouteName.join,
    pathParameters: {'code': code},
  );
}
