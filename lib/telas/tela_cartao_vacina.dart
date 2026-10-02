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
        _dadosPet = json.decode(resPet.body);
      }

      final resVacinas = await http.get(
        Uri.parse('$apiBase/lancamentos/vacinas/${widget.idPet}'),
      );
      if (resVacinas.statusCode == 200) {
        _listaVacinas = json.decode(resVacinas.body);
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
      if (dias > 0 && partes.isEmpty)
        partes.add('$dias ${dias == 1 ? "dia" : "dias"}');
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

  @override
  Widget build(BuildContext context) {
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
                    // ✅ CABEÇALHO — ORIGINAL
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            '🐾 CARTÃO DE VACINAÇÃO',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'PetShop CRM — Saúde Animal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 1.2),
                    const SizedBox(height: 16),

                    // ✅ DADOS DO PET
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 16, height: 1.5),
                        children: [
                          TextSpan(
                            text: '🐶 Nome: ${widget.nomePet}\n',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text:
                                '🎂 Nascimento: ${_formatarData(_dadosPet?['nascimento'])}   •   Idade: ${_calcularIdade(_dadosPet?['nascimento'])}\n',
                          ),
                          TextSpan(
                            text:
                                '📋 Espécie: ${_dadosPet?['especie']?['nomeEspecie'] ?? 'Não informada'}   •   Raça: ${_dadosPet?['raca']?['nome'] ?? 'Não informada'}\n',
                          ),
                          TextSpan(
                            text:
                                '👤 Tutor: ${_dadosPet?['nomeTutor'] ?? 'Não informado'}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(thickness: 1.2),
                    const SizedBox(height: 16),

                    // ✅ TABELA DE VACINAS
                    const Text(
                      '💉 VACINAS APLICADAS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cabeçalho da tabela — ORIGINAL
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 6,
                      ),
                      color: Cores.roxoClaro.withOpacity(0.2),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 22,
                            child: Text(
                              'Vacina',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 18,
                            child: Text(
                              'Aplicação',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 18,
                            child: Text(
                              'Prox. Dose',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 42,
                            child: Text(
                              'Observações',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Linhas das vacinas — ORIGINAL
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _listaVacinas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final vac = _listaVacinas[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 6,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 22,
                                child: Text(
                                  vac['nome'] ?? vac['produto']?['nome'] ?? '—',
                                ),
                              ),
                              Expanded(
                                flex: 18,
                                child: Text(
                                  _formatarData(
                                    vac['dataAplicacao'] ?? vac['data'],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 18,
                                child: Text(_formatarData(vac['proximaDose'])),
                              ),
                              Expanded(
                                flex: 42,
                                child: Text(
                                  vac['observacoes']?.toString() ?? '—',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    const Divider(thickness: 1.2),
                    const SizedBox(height: 16),

                    // ✅ PROFISSIONAL
                    Text(
                      '🏥 Aplicado por: ${_dadosPet?['nomeVeterinario'] ?? '___________________________'}   CRMV: ${_dadosPet?['crmv'] ?? '____/_____-__'}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 32),

                    // ✅ LOCAL E DATA — ORIGINAL
                    const Divider(thickness: 1),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 15),
                        children: [
                          const TextSpan(
                            text: 'Local: ___________________________',
                          ),
                          const TextSpan(text: '   '),
                          TextSpan(
                            text:
                                'Data: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/_______',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
