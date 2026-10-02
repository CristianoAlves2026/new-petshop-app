import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart'; // ✅ FALTAVA ESTE!
import '../../utils/constantes.dart'; // ✅ E ESTE!

class TelaVisualizacaoPdf extends StatelessWidget {
  final String caminhoArquivo;
  final String nomeArquivo;

  const TelaVisualizacaoPdf({
    super.key,
    required this.caminhoArquivo,
    required this.nomeArquivo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(nomeArquivo),
        backgroundColor: Cores.roxoEscuro,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              nomeArquivo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Arquivo pronto em:\n$caminhoArquivo',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                backgroundColor: Cores.roxoEscuro,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Share.shareXFiles(
                  [XFile(caminhoArquivo)],
                  text: '📋 $nomeArquivo',
                  subject: nomeArquivo,
                );
              },
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copiar caminho do arquivo'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: caminhoArquivo));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Caminho copiado!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
