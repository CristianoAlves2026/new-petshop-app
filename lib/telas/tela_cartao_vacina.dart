import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/constantes.dart';

class TelaCartaoVacina extends StatefulWidget {
  final dynamic idPet;
  final String nomePet;
  const TelaCartaoVacina({
    super.key,
    required this.idPet,
    required this.nomePet,
  });

  @override
  State<TelaCartaoVacina> createState() => _TelaCartaoVacinaState();
}

class _TelaCartaoVacinaState extends State<TelaCartaoVacina> {
  bool _carregando = true;
  dynamic _dadosPet;
  dynamic _dadosTutor;
  List<dynamic> _listaVacinas = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final resPet = await http.get(Uri.parse('$apiBase/pets/${widget.idPet}'));
      if (resPet.statusCode == 200) {
        setState(() {
          _dadosPet = json.decode(resPet.body);
          _dadosTutor = _dadosPet['tutor']; // ← API vai precisar incluir isso
        });
      }
      final resVacinas = await http.get(
        Uri.parse('$apiBase/lancamentos/vacinas/${widget.idPet}'),
      );
      if (resVacinas.statusCode == 200) {
        setState(() {
          _listaVacinas = json.decode(resVacinas.body);
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar cartão: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _calcularIdade(dynamic nascimento) {
    if (nascimento == null) return 'Não informada';
    try {
      DateTime nas = DateTime.parse(nascimento.toString());
      DateTime hoje = DateTime.now();
      int anos = hoje.year - nas.year;
      int meses = hoje.month - nas.month;
      int dias = hoje.day - nas.day;
      if (dias < 0) {
        meses--;
        int ultimoMes = hoje.month > 1 ? hoje.month - 1 : 12;
        int anoUltimoMes = hoje.month > 1 ? hoje.year : hoje.year - 1;
        dias += DateTime(anoUltimoMes, ultimoMes + 1, 0).day;
      }
      if (meses < 0) {
        anos--;
        meses += 12;
      }
      List<String> partes = [];
      if (anos > 0) partes.add('$anos ${anos == 1 ? "ano" : "anos"}');
      if (meses > 0) partes.add('$meses ${meses == 1 ? "mês" : "meses"}');
      if (dias > 0 && partes.isEmpty) {
        partes.add('$dias ${dias == 1 ? "dia" : "dias"}');
      }
      return partes.join(' e ');
    } catch (_) {
      return 'Não informada';
    }
  }

  String _formatarData(dynamic data) {
    if (data == null || data.toString().isEmpty) return '—';
    try {
      DateTime d = DateTime.parse(data.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return data.toString();
    }
  }

  bool _estaVencida(dynamic dataVencimento) {
    if (dataVencimento == null) return false;
    try {
      DateTime venc = DateTime.parse(dataVencimento.toString());
      return DateTime.now().isAfter(venc);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final dataEmissao =
        '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';

    // Separa vacinas vigentes e finalizadas
    final vigentes = _listaVacinas.where((v) {
      final status = (v['status'] ?? 'ativo').toString().toUpperCase();
      return status != 'IGNORADO' && status != 'REPETIDO';
    }).toList();

    final historico = _listaVacinas.where((v) {
      final status = (v['status'] ?? '').toString().toUpperCase();
      return status == 'IGNORADO' || status == 'REPETIDO';
    }).toList();

    // Ordena vigentes: vencidas primeiro, depois em dia
    vigentes.sort((a, b) {
      bool aVenc = _estaVencida(a['proximaDose']);
      bool bVenc = _estaVencida(b['proximaDose']);
      if (aVenc && !bVenc) return -1;
      if (!aVenc && bVenc) return 1;
      return 0;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartão de Vacinação'),
        backgroundColor: Cores.roxoEscuro,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // CABEÇALHO — Foto + Dados / Título à direita
                    // ==========================================
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lado Esquerdo: Foto + Dados do Pet
                        Expanded(
                          flex: 6,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Foto
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Cores.roxoClaro.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _dadosPet?['foto'] != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          _dadosPet['foto'],
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.pets,
                                        size: 36,
                                        color: Cores.roxoEscuro,
                                      ),
                              ),
                              const SizedBox(width: 16),
                              // Dados do Pet
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.nomePet.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Raça: ${_dadosPet?['raca']?['nome'] ?? 'Não informada'}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'Espécie: ${_dadosPet?['especie']?['nomeEspecie'] ?? 'Não informada'}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Nascimento: ${_formatarData(_dadosPet?['nascimento'])}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'Idade: ${_calcularIdade(_dadosPet?['nascimento'])}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Lado Direito: Título
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Text(
                                'CARTEIRA DE',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                'VACINAÇÃO',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 1.2),
                    const SizedBox(height: 16),

                    // ==========================================
                    // DADOS DO TUTOR
                    // ==========================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '👤 DADOS DO TUTOR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nome: ${_dadosTutor?['nome'] ?? '___________________________'}',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Telefone: ${_dadosTutor?['telefone'] ?? '___________'}',
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'E-mail: ${_dadosTutor?['email'] ?? '___________________________'}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Cidade: ${_dadosTutor?['idMunicipio'] != null ? _dadosTutor['idMunicipio'] : '_________________'} / ${_dadosTutor?['estado'] ?? '__'}',
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Bairro: ${_dadosTutor?['bairro'] ?? '___________________________'}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ==========================================
                    // VACINAS VIGENTES — Caixas lado a lado
                    // ==========================================
                    if (vigentes.isNotEmpty) ...[
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.start,
                        children: vigentes.map((vac) {
                          bool vencida = _estaVencida(vac['proximaDose']);
                          return Container(
                            width: 180,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: vencida
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: vencida
                                    ? Colors.orange.shade200
                                    : Colors.green.shade200,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  vac['nome'] ?? vac['produto']?['nome'] ?? '—',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Data Aplicação',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  _formatarData(
                                    vac['dataAplicacao'] ?? vac['data'],
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Vencimento',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  _formatarData(vac['proximaDose']),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: vencida
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: vencida
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  vencida ? '⚠️ Vencida' : '✅ Em dia',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: vencida
                                        ? Colors.orange.shade800
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // ==========================================
                    // HISTÓRICO DE APLICAÇÕES
                    // ==========================================
                    if (historico.isNotEmpty) ...[
                      const Text(
                        'Histórico de Aplicações',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Cabeçalho da tabela
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 25,
                              child: Text(
                                'Vacina',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 20,
                              child: Text(
                                'Aplicação',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 20,
                              child: Text(
                                'Vencimento',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 35,
                              child: Text(
                                'Observações',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Linhas
                      ...historico.map(
                        (vac) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 25,
                                child: Text(
                                  vac['nome'] ?? vac['produto']?['nome'] ?? '—',
                                ),
                              ),
                              Expanded(
                                flex: 20,
                                child: Text(
                                  _formatarData(
                                    vac['dataAplicacao'] ?? vac['data'],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 20,
                                child: Text(_formatarData(vac['proximaDose'])),
                              ),
                              Expanded(
                                flex: 35,
                                child: Text(
                                  vac['observacoes']?.toString() ?? '—',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // ==========================================
                    // ASSINATURAS
                    // ==========================================
                    const Divider(thickness: 1),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 200,
                              height: 1,
                              color: Colors.black54,
                            ),
                            const SizedBox(height: 8),
                            const Text('Assinatura do Veterinário + CRMV'),
                            const Text(
                              'CRMV: ____/____-___',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 200,
                              height: 1,
                              color: Colors.black54,
                            ),
                            const SizedBox(height: 8),
                            const Text('Assinatura do Tutor'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ==========================================
                    // RODAPÉ — Data de Emissão
                    // ==========================================
                    const Divider(thickness: 1),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Documento Emitido em: $dataEmissao',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
