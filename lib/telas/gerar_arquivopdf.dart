import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../utils/constantes.dart';
import 'dart:typed_data';
import '../main.dart';

// ✅ COLOQUE A FUNÇÃO AQUI:
String capitalizar(String? texto) {
  if (texto == null || texto.trim().isEmpty) return '-';
  return texto
      .trim()
      .split(' ')
      .map((palavra) {
        if (palavra.isEmpty) return '';
        if (palavra.length <= 2)
          return palavra.toLowerCase(); // mantém "de", "da", "do" minúsculo
        return palavra[0].toUpperCase() + palavra.substring(1).toLowerCase();
      })
      .join(' ');
}

// ✅ Função para aplicar máscara de telefone
String mascaraTelefone(String? numero) {
  if (numero == null || numero.trim().isEmpty || numero == 'Não informado')
    return 'Não informado';

  // Deixa só os números
  String digitos = numero.replaceAll(RegExp(r'[^0-9]'), '');

  if (digitos.length == 11) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 7)}-${digitos.substring(7)}';
  } else if (digitos.length == 10) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 6)}-${digitos.substring(6)}';
  }
  return numero; // se não tiver o tamanho certo, mostra como veio
}

class DadosCartaoVacina {
  final dynamic pet;
  final List<dynamic> vacinasVencidas;
  final List<dynamic> vacinasEmDia;
  final List<dynamic> vacinasFinalizadas;
  final String nomePet;
  final dynamic tutor;

  DadosCartaoVacina({
    required this.pet,
    required this.vacinasVencidas,
    required this.vacinasEmDia,
    required this.vacinasFinalizadas,
    required this.nomePet,
    this.tutor,
  });
}

class GerarArquivoPdf {
  String _formatarData(dynamic data) {
    if (data == null || data.toString().isEmpty) return '—';
    try {
      final d = DateTime.parse(data.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return data.toString();
    }
  }

  String _calcularIdade(dynamic nascimento) {
    if (nascimento == null) return 'Não informada';
    try {
      final nas = DateTime.parse(nascimento.toString());
      final hoje = DateTime.now();
      int anos = hoje.year - nas.year;
      int meses = hoje.month - nas.month;
      int dias = hoje.day - nas.day;
      if (dias < 0) {
        meses--;
        dias += 30;
      }
      if (meses < 0) {
        anos--;
        meses += 12;
      }
      final p = <String>[];
      if (anos > 0) p.add('$anos ${anos == 1 ? "ano" : "anos"}');
      if (meses > 0) p.add('$meses ${meses == 1 ? "mês" : "meses"}');
      if (dias > 0 && p.isEmpty) p.add('$dias ${dias == 1 ? "dia" : "dias"}');
      return p.join(' e ');
    } catch (_) {
      return 'Não informada';
    }
  }

  String _obterNomeVacina(dynamic lanc, List<dynamic> listaProdutos) {
    final desc = lanc['descricao']?.toString();
    if (desc != null && desc.isNotEmpty && desc != 'Produto') return desc;
    final idProd = lanc['idProduto'];
    if (idProd != null) {
      final prod = listaProdutos.firstWhere(
        (p) => p['id'] == idProd,
        orElse: () => null,
      );
      if (prod != null && prod['nome'] != null) return prod['nome'].toString();
    }
    if (lanc['nome'] != null && lanc['nome'].toString().isNotEmpty) {
      return lanc['nome'].toString();
    }
    if (lanc['produto'] != null && lanc['produto']['nome'] != null) {
      return lanc['produto']['nome'].toString();
    }
    return 'Vacina';
  }

  String _pegarNomeRaca(dynamic idRaca, List<dynamic> listaRacas) {
    if (idRaca == null) return 'Não informada';
    final encontrada = listaRacas.firstWhere(
      (r) => r['id'] == idRaca,
      orElse: () => null,
    );
    if (encontrada != null && encontrada['nome'] != null) {
      return encontrada['nome'].toString();
    }
    return 'Não informada';
  }

  String? _pegarUrlFoto(String? foto) {
    if (foto == null) return null;
    final limpa = foto.trim();
    if (limpa.isNotEmpty && limpa.startsWith('http')) {
      return limpa;
    }
    return null;
  }

  Future<Uint8List> _carregarImagemDaUrl(String url) async {
    final resposta = await http.get(Uri.parse(url));
    if (resposta.statusCode == 200) {
      return resposta.bodyBytes;
    }
    throw Exception('Não foi possível carregar a imagem');
  }

  String _pegarValorEspecie(dynamic pet) {
    final especie = pet['especie'];
    if (especie != null &&
        especie['nomeEspecie'] != null &&
        especie['nomeEspecie'].toString().isNotEmpty) {
      return especie['nomeEspecie'].toString();
    }
    if (pet['nomeEspecie'] != null) {
      return pet['nomeEspecie'].toString();
    }
    return 'Não informada';
  }

  Future<DadosCartaoVacina?> _carregarDados(
    dynamic idPet,
    String nomePet,
  ) async {
    try {
      final resPet = await http.get(Uri.parse('$apiBase/pets/$idPet'));
      if (resPet.statusCode != 200) return null;
      final pet = json.decode(resPet.body);

      debugPrint('🐶 Dados do pet: $pet');
      debugPrint('🔍 idTutor = ${pet['idTutor']}');

      dynamic tutor;
      if (pet['idTutor'] != null) {
        try {
          final urlTutor = '$apiBase/tutores/${pet['idTutor']}';
          debugPrint('📡 Buscando tutor em: $urlTutor');

          final resTutor = await http.get(Uri.parse(urlTutor));
          debugPrint('📤 Status tutor: ${resTutor.statusCode}');

          if (resTutor.statusCode == 200) {
            tutor = json.decode(resTutor.body);
            debugPrint('✅ Tutor recebido: $tutor');
            debugPrint('🏙️ nomeCidade = ${tutor?['nomeCidade']}');
            debugPrint('🗺️ estado = ${tutor?['estado']}');
            debugPrint('📍 idMunicipio = ${tutor?['idMunicipio']}');
          } else {
            debugPrint('❌ Erro na busca do tutor: ${resTutor.body}');
          }
        } catch (e) {
          debugPrint('❌ Exceção ao buscar tutor: $e');
        }
      } else {
        debugPrint('⚠️ idTutor está NULO no pet!');
      }

      final resLanc = await http.get(
        Uri.parse('$apiBase/lancamentos/pet/$idPet'),
      );
      if (resLanc.statusCode != 200) return null;
      final todosLanc = json.decode(resLanc.body) as List;

      final resProd = await http.get(Uri.parse('$apiBase/produtos'));
      final listaProd = resProd.statusCode == 200
          ? json.decode(resProd.body) as List
          : <dynamic>[];

      final agora = DateTime.now();
      final hoje = DateTime(agora.year, agora.month, agora.day);
      final vencidas = <dynamic>[];
      final emDia = <dynamic>[];
      final finalizadas = <dynamic>[];

      for (final vac in todosLanc) {
        final idProd = vac['idProduto'];
        final prod = listaProd.firstWhere(
          (p) => p['id'] == idProd,
          orElse: () => null,
        );
        if (prod == null || prod['idProduto'] != 1) continue;

        final status =
            vac['status']?.toString().toUpperCase().trim() ?? 'ATIVO';
        if ([
          'REPETIDO',
          'REPETIDA',
          'FINALIZADO',
          'FINALIZADA',
        ].contains(status)) {
          finalizadas.add(vac);
          continue;
        }

        DateTime? dataVenc;
        try {
          final ds =
              vac['proximaDose']?.toString() ?? vac['repetir']?.toString();
          if (ds != null && ds.isNotEmpty) dataVenc = DateTime.parse(ds);
        } catch (_) {}

        final dataVencDia = dataVenc != null
            ? DateTime(dataVenc.year, dataVenc.month, dataVenc.day)
            : null;

        if (dataVencDia != null && dataVencDia.isBefore(hoje)) {
          vencidas.add(vac);
        } else {
          emDia.add(vac);
        }
      }

      return DadosCartaoVacina(
        pet: pet,
        vacinasVencidas: vencidas,
        vacinasEmDia: emDia,
        vacinasFinalizadas: finalizadas,
        nomePet: nomePet,
        tutor: tutor,
      );
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados: $e');
      return null;
    }
  }

  Future<File?> gerarPdf(
    dynamic idPet,
    String nomePet, {
    String? fotoPet,
    dynamic idRacaPet,
    required List<dynamic> listaRacas,
  }) async {
    final dados = await _carregarDados(idPet, nomePet);
    if (dados == null) return null;

    final listaProd = <dynamic>[];
    try {
      final res = await http.get(Uri.parse('$apiBase/produtos'));
      if (res.statusCode == 200) listaProd.addAll(json.decode(res.body));
    } catch (_) {}

    final dataAtual = DateTime.now();
    final dataEmissao =
        '${dataAtual.day.toString().padLeft(2, '0')}/${dataAtual.month.toString().padLeft(2, '0')}/${dataAtual.year}';

    final tutor = dados.tutor;
    final pet = dados.pet;
    final fotoUrl = _pegarUrlFoto(fotoPet);

    Uint8List? imagemBytes;
    if (fotoUrl != null) {
      try {
        imagemBytes = await _carregarImagemDaUrl(fotoUrl);
      } catch (_) {}
    }

    final nomeRaca = _pegarNomeRaca(idRacaPet, listaRacas);
    final nomeEspecie = _pegarValorEspecie(dados.pet);

    // ✅ AGORA PEGANDO DIRETO DA RESPOSTA DA API! Sem busca extra!
    final nomeCidade =
        tutor?['nomeCidade']?.toString().trim() ??
        pet['nomeCidade']?.toString().trim() ??
        pet['cidade']?.toString().trim() ??
        '';

    final estado =
        tutor?['estado']?.toString().trim() ??
        pet['estado']?.toString().trim() ??
        '';

    final textoCidadeUf = (nomeCidade.isNotEmpty || estado.isNotEmpty)
        ? [
            if (nomeCidade.isNotEmpty) nomeCidade,
            if (estado.isNotEmpty) estado,
          ].join('-')
        : 'Não informado';

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EDE5F7'),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#D4C8EB'),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: imagemBytes != null
                          ? pw.Image(
                              pw.MemoryImage(imagemBytes),
                              fit: pw.BoxFit.cover,
                            )
                          : pw.Center(
                              child: pw.Text(
                                '📷',
                                style: pw.TextStyle(fontSize: 30),
                              ),
                            ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      flex: 65,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            nomePet,
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#6A48B5'),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Raça: $nomeRaca  |  Espécie: $nomeEspecie',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Idade: ${_calcularIdade(dados.pet['nascimento'])}',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Nascimento: ${_formatarData(dados.pet['nascimento'])}',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 35,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'CARTEIRA DE\nVACINAÇÃO',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#6A48B5'),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8F5FC'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DADOS DO TUTOR',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#6A48B5'),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 45,
                          child: pw.Text(
                            'Nome: ${capitalizar(tutor?['nome'] ?? pet['nomeTutor'])}',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          flex: 55,
                          child: pw.Text(
                            'E-mail: ${tutor?['email'] ?? pet['email'] ?? 'Não informado'}',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 28,
                          child: pw.Text(
                            'Celular: ${mascaraTelefone(tutor?['telefone'] ?? pet['telefone'])}',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Expanded(
                          flex: 36,
                          child: pw.Text(
                            'Cidade-UF: $textoCidadeUf',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Expanded(
                          flex: 36,
                          child: pw.Text(
                            'Bairro: ${capitalizar(tutor?['bairro'] ?? pet['bairro'])}',
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              if (dados.vacinasVencidas.isNotEmpty) ...[
                pw.Text(
                  'VACINAS VENCIDAS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: dados.vacinasVencidas.map((vac) {
                    return pw.Container(
                      width: 170,
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.red, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            _obterNomeVacina(vac, listaProd),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Aplicação: ${_formatarData(vac['dataAplicacao'] ?? vac['data'])}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            'Vencimento: ${_formatarData(vac['proximaDose'] ?? vac['repetir'])}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                pw.SizedBox(height: 20),
              ],
              if (dados.vacinasEmDia.isNotEmpty) ...[
                pw.Text(
                  'VACINAS EM DIA',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: dados.vacinasEmDia.map((vac) {
                    return pw.Container(
                      width: 170,
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.green,
                          width: 1.5,
                        ),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            _obterNomeVacina(vac, listaProd),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Aplicação: ${_formatarData(vac['dataAplicacao'] ?? vac['data'])}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            'Vencimento: ${_formatarData(vac['proximaDose'] ?? vac['repetir'])}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                pw.SizedBox(height: 24),
              ],
              pw.Text(
                'HISTÓRICO DE APLICAÇÕES',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#6A48B5'),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 6,
                ),
                color: PdfColor.fromHex('#EDE5F7'),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 28,
                      child: pw.Text(
                        'Vacina',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 22,
                      child: pw.Text(
                        'Aplicação',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 22,
                      child: pw.Text(
                        'Vencimento',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 28,
                      child: pw.Text(
                        'Observações',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...dados.vacinasFinalizadas.asMap().entries.map((entry) {
                final vac = entry.value;
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  color: entry.key % 2 == 0
                      ? PdfColors.white
                      : PdfColor.fromHex('#F8F5FC'),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 28,
                        child: pw.Text(
                          _obterNomeVacina(vac, listaProd),
                          style: pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.Expanded(
                        flex: 22,
                        child: pw.Text(
                          _formatarData(vac['dataAplicacao'] ?? vac['data']),
                          style: pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.Expanded(
                        flex: 22,
                        child: pw.Text(
                          _formatarData(vac['proximaDose'] ?? vac['repetir']),
                          style: pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.Expanded(
                        flex: 28,
                        child: pw.Text(
                          vac['observacao']?.toString() ?? '-',
                          style: pw.TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 220,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Assinatura do Veterinário + CRMV',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 220,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Assinatura do Tutor',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'Documento Emitido em $dataEmissao',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final arquivo = File(
      '${tempDir.path}/cartao_vacina_${idPet}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await arquivo.writeAsBytes(await pdf.save());
    return arquivo;
  }

  Future<void> baixarPdf(
    BuildContext context, {
    required dynamic idPet,
    required String nomePet,
    String? fotoPet,
    dynamic idRacaPet,
    required List<dynamic> listaRacas,
  }) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('💾 Gerando PDF...')));

    final arquivoPdf = await gerarPdf(
      idPet,
      nomePet,
      fotoPet: fotoPet,
      idRacaPet: idRacaPet,
      listaRacas: listaRacas,
    );

    if (arquivoPdf == null || !context.mounted) return;

    try {
      final nomeArquivo =
          'Cartao_Vacina_${nomePet.replaceAll(' ', '_')}_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.pdf';
      final pastaDownloads = Directory('/storage/emulated/0/Download');
      if (!await pastaDownloads.exists())
        await pastaDownloads.create(recursive: true);
      final caminhoFinal = path.join(pastaDownloads.path, nomeArquivo);
      final destino = await arquivoPdf.copy(caminhoFinal);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Salvo em:\n$caminhoFinal'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );

      // ✅ ADICIONE ESTA LINHA — chama a notificação!
      await notificarPdfGerado(caminhoFinal);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 8),
        ),
      );
      debugPrint('❌ Erro ao salvar: $e');
    }
  }
}
