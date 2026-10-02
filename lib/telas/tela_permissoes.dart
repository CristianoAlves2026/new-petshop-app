import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/constantes.dart';

class TelaPermissoes extends StatefulWidget {
  final dynamic idTutor;

  const TelaPermissoes({super.key, required this.idTutor});

  @override
  State<TelaPermissoes> createState() => _TelaPermissoesState();
}

class _TelaPermissoesState extends State<TelaPermissoes> {
  bool _carregando = true;
  bool _salvando = false;

  // ✅ Status das permissões
  bool _dadosPessoais = false;
  bool _dadosPet = false;
  bool _receberOfertas = false;

  // ✅ Textos exatos apresentados
  static const String _textoDadosPessoais =
      "Autorizo o PetShop parceiro a acessar meu nome, telefone e e-mail para atendimento e contato. Posso cancelar a qualquer momento.";
  static const String _textoDadosPet =
      "Autorizo o PetShop parceiro a acessar os dados dos meus animais (nome, espécie, raça, vacinas, saúde e histórico) para atendimento personalizado. Posso cancelar a qualquer momento.";
  static const String _textoOfertas =
      "Concordo em receber promoções, descontos e novidades por e-mail ou notificação. Esta autorização não é obrigatória e não prejudica meus serviços. Posso cancelar a qualquer momento.";

  @override
  void initState() {
    super.initState();
    _carregarPermissoes();
  }

  // ✅ Carregar status atual de cada permissão
  Future<void> _carregarPermissoes() async {
    setState(() => _carregando = true);
    try {
      final res = await http
          .get(Uri.parse('$apiBase/permissoes/${widget.idTutor}'))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final dados = json.decode(res.body);
        setState(() {
          _dadosPessoais = dados['dadosPessoais'] ?? false;
          _dadosPet = dados['dadosPet'] ?? false;
          _receberOfertas = dados['receberOfertas'] ?? false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _mensagem('⚠️ Não foi possível carregar permissões', Colors.orange);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ✅ Salvar TODAS as permissões
  Future<void> _salvar() async {
    // ✅ Evita cliques repetidos
    if (_salvando) return;

    setState(() => _salvando = true);

    try {
      // ✅ Envia todas as permissões
      await Future.wait([
        _enviarPermissao('dados_pessoais', _dadosPessoais, _textoDadosPessoais),
        _enviarPermissao('dados_pet', _dadosPet, _textoDadosPet),
        _enviarPermissao('receber_ofertas', _receberOfertas, _textoOfertas),
      ]);

      // ✅ Só continua se a tela ainda estiver ativa
      if (!mounted) return;

      // ✅ Mostra mensagem de sucesso
      _mensagem('✅ Permissões salvas!', Colors.green);

      // ✅ Espera um tempo para o usuário ver a mensagem
      await Future.delayed(const Duration(seconds: 1));

      // ✅ Volta SOMENTE se a tela ainda estiver na pilha
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      _mensagem('❌ Erro ao salvar: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  // ✅ Enviar UMA permissão para a API
  Future<void> _enviarPermissao(String tipo, bool valor, String texto) async {
    final res = await http
        .post(
          Uri.parse('$apiBase/permissoes'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'idTutor': widget.idTutor,
            'tipo': tipo,
            'texto': texto,
            'autorizado': valor,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Erro ao salvar $tipo');
    }
  }

  void _mensagem(String texto, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto, style: const TextStyle(fontSize: 16)),
        backgroundColor: cor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 🔹 CABEÇALHO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: Cores.gradiente,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Permissões',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔹 CONTEÚDO
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gerencie o que deseja compartilhar',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 30),

                        // ✅ 1 — Dados Pessoais
                        SwitchListTile(
                          tileColor: Colors
                              .transparent, // ✅ Esta linha resolve o aviso
                          title: const Text(
                            'Compartilhar meus dados de contato',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Nome, telefone e e-mail',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: _dadosPessoais,
                          onChanged: (v) => setState(() => _dadosPessoais = v),
                          activeColor: Cores.roxoEscuro,
                        ),
                        const Divider(),

                        // ✅ 2 — Dados dos Pets
                        SwitchListTile(
                          tileColor: Colors
                              .transparent, // ✅ Esta linha resolve o aviso
                          title: const Text(
                            'Compartilhar informações dos meus pets',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Histórico, vacinas e cuidados',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: _dadosPet,
                          onChanged: (v) => setState(() => _dadosPet = v),
                          activeColor: Cores.roxoEscuro,
                        ),
                        const Divider(),

                        // ✅ 3 — Ofertas
                        SwitchListTile(
                          tileColor: Colors
                              .transparent, // ✅ Esta linha resolve o aviso
                          title: const Text(
                            'Receber ofertas e novidades',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Promoções e descontos por e-mail ou notificação',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: _receberOfertas,
                          onChanged: (v) => setState(() => _receberOfertas = v),
                          activeColor: Cores.roxoEscuro,
                        ),
                        const SizedBox(height: 40),

                        // ✅ BOTÃO SALVAR
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _salvando ? null : _salvar,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Cores.roxoEscuro,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _salvando
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'SALVAR',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
