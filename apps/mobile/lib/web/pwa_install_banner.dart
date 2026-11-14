import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/web/pwa_install.dart'
    if (dart.library.js_interop) 'package:gs_mobile/web/pwa_install_web.dart';

class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  Timer? _poll;
  var _offer = PwaInstall.shouldOffer;
  var _ios = PwaInstall.isIosGuide;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      final offer = PwaInstall.shouldOffer;
      final ios = PwaInstall.isIosGuide;
      if (offer != _offer || ios != _ios) {
        setState(() {
          _offer = offer;
          _ios = ios;
        });
      }
      if (PwaInstall.isStandalone) _poll?.cancel();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    if (_ios) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Instalar no iPhone'),
          content: const Text(
            'No Safari, toque em Compartilhar (o quadrado com a seta) e depois em Adicionar à Tela de Início. O GS Campo abre como aplicativo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }
    await PwaInstall.prompt();
    if (mounted) {
      setState(() {
        _offer = PwaInstall.shouldOffer;
        _ios = PwaInstall.isIosGuide;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_offer) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: OutlinedButton.icon(
        onPressed: _install,
        style: OutlinedButton.styleFrom(
          foregroundColor: GsTheme.paper,
          side: const BorderSide(color: GsTheme.brass),
        ),
        icon: const Icon(Icons.install_mobile),
        label: Text(_ios ? 'Instalar no iPhone' : 'Instalar no celular'),
      ),
    );
  }
}

Future<void> showPwaInstallHelp(BuildContext context) async {
  if (PwaInstall.isIosGuide) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instalar no iPhone'),
        content: const Text(
          'No Safari, toque em Compartilhar (o quadrado com a seta) e depois em Adicionar à Tela de Início.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    return;
  }
  await PwaInstall.prompt();
}
