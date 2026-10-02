import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constantes.dart';
import 'produtos/tela_lancamento.dart';
import 'tela_cartao_vacina.dart'; // ✅ Adicione esta linha
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'tela_visualizacao_pdf.dart';
import 'dart:io'; // ✅ Para reconhecer Platform

class TelaProdutos extends StatefulWidget {
  final String nomePet;
  final dynamic idPet;
  final dynamic idPetshop;
  final String? categoria;

  const TelaProdutos({
    super.key,
    required this.nomePet,
    required this.idPet,
    this.idPetshop,
    this.categoria,
  });

  @override
  State<TelaProdutos> createState() => _TelaProdutosState();
}

class _TelaProdutosState extends State<TelaProdutos> {
  // ✅ Vacinas JÁ selecionada por padrão
  int _indiceSelecionado = 0;
  List<dynamic> _listaProdutos = [];
  List<dynamic> _listaLancamentos = [];
  String _filtro = 'todos'; // ✅ 'todos', 'noprazo', 'vencidos', 'concluidos'
  bool _carregando = false;
  bool _carregandoLancamentos = true;
  String _categoriaSelecionada = 'Vacinas';
  String _textoFiltro = 'Histórico';
  String _nomePetExibicao = '';

  // ✅ 1 = Vacinas | 2 = Alimentação | 3 = Saúde | 4 = Higiene | 5 = Outros
  int get _idCategoria {
    switch (_indiceSelecionado) {
      case 0:
        return 1;
      case 1:
        return 2;
      case 2:
        return 3;
      case 3:
        return 4;
      case 4:
        return 5;
      default:
        return 1;
    }
  }

  String get _nomeCategoria {
    switch (_indiceSelecionado) {
      case 0:
        return 'Vacinas';
      case 1:
        return 'Alimentação';
      case 2:
        return 'Saúde';
      case 3:
        return 'Higiene';
      case 4:
        return 'Outros';
      default:
        return 'Produtos';
    }
  }

  // ✅ CARREGAR HISTÓRICO
  Future<void> _carregarLancamentos() async {
    // ✅ LIMPA A LISTA ANTES DE CARREGAR NOVO
    if (mounted) {
      setState(() {
        _listaLancamentos = [];
        _carregandoLancamentos = true;
      });
    }
    try {
      // 📋 PRIMEIRO: carrega todos os produtos
      final respProdutos = await http.get(Uri.parse('$apiBase/produtos'));
      List<dynamic> listaProdutos = [];
      if (respProdutos.statusCode == 200) {
        listaProdutos = json.decode(respProdutos.body);
      }

      // 📋 SEGUNDO: carrega os lançamentos do pet
      final respLanc = await http.get(
        Uri.parse('$apiBase/lancamentos/pet/${widget.idPet}'),
      );
      if (respLanc.statusCode != 200) {
        throw Exception('Não foi possível carregar lançamentos');
      }
      List<dynamic> todosLanc = json.decode(respLanc.body);

      // ✅ FILTRA NA ORDEM CERTA:
      // lancamento.idProduto → busca em produtos.id → pega produtos.idProduto = categoria
      if (mounted) {
        setState(() {
          _listaLancamentos = todosLanc.where((lanc) {
            final idDoProduto = lanc['idProduto'];

            // Acha o produto pelo campo "id"
            final produto = listaProdutos.firstWhere(
              (p) => p['id'] == idDoProduto,
              orElse: () => null,
            );

            if (produto == null) return false;

            // produtos.idProduto = número da categoria → compara com aba selecionada
            return produto['idProduto'] == _idCategoria;
          }).toList();

          _carregandoLancamentos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _listaLancamentos = [];
          _carregandoLancamentos = false;
        });
        debugPrint('❌ Erro: $e');
      }
    }
  }

  // ✅ IGNORAR AVISO → MUDA STATUS PARA IGNORADO
  Future<void> _ignorarAviso(dynamic idLancamento) async {
    try {
      final resposta = await http.put(
        Uri.parse('$apiBase/lancamentos/$idLancamento/ignorar'),
        headers: {'Content-Type': 'application/json'},
      );
      if (resposta.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Aviso ignorado!'),
              backgroundColor: Cores.roxoEscuro,
            ),
          );
          _carregarLancamentos();
        }
      } else {
        throw Exception('Não foi possível ignorar');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erro: $e')));
      }
    }
  }

  // ✅ FILTRO ATUALIZADO COM OS 3 TIPOS
  List<dynamic> get _listaFiltrada {
    final hoje = DateTime.now();
    return _listaLancamentos.where((lanc) {
      final status = lanc['status']?.toString().toUpperCase() ?? 'ATIVO';

      DateTime? dataRepetir;
      try {
        final dataStr = lanc['repetir']?.toString();
        if (dataStr != null && dataStr.isNotEmpty) {
          dataRepetir = DateTime.parse(dataStr);
        }
      } catch (_) {}

      final bool estaVencido =
          dataRepetir != null && dataRepetir.isBefore(hoje);

      switch (_filtro) {
        // ❌ VENCIDOS → ATIVO E data JÁ PASSOU
        case 'vencidos':
          return status == 'ATIVO' && estaVencido;

        // ✅ NO PRAZO → ATIVO E data AINDA NÃO CHEGOU
        case 'noprazo':
          return status == 'ATIVO' && !estaVencido;

        // ✅ CONCLUÍDOS → status DIFERENTE DE ATIVO
        case 'concluidos':
          return status != 'ATIVO';

        // TODOS → mostra tudo
        default:
          return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    print('🔍 nomePet recebido: "${widget.nomePet}"');
    print('🔍 idPet recebido: ${widget.idPet}');

    // ✅ NOVA PARTE: Define aba correta pela categoria
    // ✅ Define a aba certa conforme a categoria recebida
    if (widget.categoria != null) {
      switch (widget.categoria) {
        case 'vacinas':
          _categoriaSelecionada = 'Vacinas';
          _indiceSelecionado = 0;
          break;
        case 'alimentacao':
          _categoriaSelecionada = 'Alimentação';
          _indiceSelecionado = 1;
          break;
        case 'saude':
          _categoriaSelecionada = 'Saúde';
          _indiceSelecionado = 2;
          break;
        case 'higiene':
          _categoriaSelecionada = 'Higiene';
          _indiceSelecionado = 3;
          break;
        case 'outros':
        default:
          _categoriaSelecionada = 'Outros';
          _indiceSelecionado = 4;
      }
      print('🔍 Aba selecionada: $_categoriaSelecionada');
    }

    // ✅ RESTO CONTINUA IGUAL — NÃO MEXI NADA!
    if (widget.nomePet.isNotEmpty) {
      _nomePetExibicao = widget.nomePet;
      print('🔍 Usou nome direto: $_nomePetExibicao');
    } else {
      print('🔍 Vai buscar nome na API...');
      _buscarNomePet();
    }
    _carregarLancamentos();
  }

  void _aoTrocarCategoria(int indice) {
    if (mounted) {
      setState(() {
        _indiceSelecionado = indice;
        _categoriaSelecionada = _nomeCategoria;
      });
      _carregarLancamentos();
    }
  }

  // ✅ FLUXO: BUSCA → ESCOLHE → ABRE TELA NOVA
  Future<void> _adicionar() async {
    // ✅ ABRE A TELA E ESPERA O PRODUTO ESCOLHIDO VOLTAR
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaLancamento(
          idPet: widget.idPet,
          idCategoria: _idCategoria,
          idPetshop: widget.idPetshop,
        ),
      ),
    );

    // ✅ SE ESCOLHEU UM PRODUTO → MUDA PARA A ABA CERTA E REABRE COM O PRODUTO
    if (resultado != null && resultado is Map && mounted) {
      final idCat = resultado['idCategoria'];
      setState(() {
        switch (idCat) {
          case 1:
            _indiceSelecionado = 0;
            break;
          case 2:
            _indiceSelecionado = 1;
            break;
          case 3:
            _indiceSelecionado = 2;
            break;
          case 4:
            _indiceSelecionado = 3;
            break;
          case 5:
            _indiceSelecionado = 4;
            break;
        }
        _categoriaSelecionada = _nomeCategoria;
      });

      // ✅ REABRE A TELA JÁ COM O PRODUTO PREENCHIDO
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TelaLancamento(
            idPet: widget.idPet,
            idCategoria: idCat,
            idPetshop: widget.idPetshop,
            nomeProdutoSelecionado: resultado['nome'],
            idProdutoSelecionado: resultado['id'],
          ),
        ),
      );
    }

    _carregarLancamentos();
  }

  // ✅ ÍCONE CONFORME STATUS
  Widget _iconeStatus(dynamic lanc) {
    final status = lanc['status']?.toString() ?? 'ATIVO';

    // ✅ SE JÁ FOI REPETIDO OU IGNORADO → ÍCONE AZUL
    if (status == 'REPETIDO' || status == 'IGNORADO') {
      return const Icon(Icons.check_circle, color: Colors.blue, size: 28);
    }

    // ✅ SE AINDA ESTÁ ATIVO → VERIFICA DATA
    final hoje = DateTime.now();
    final dataRepetirStr = lanc['repetir']?.toString();
    if (dataRepetirStr == null || dataRepetirStr.isEmpty) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 28);
    }
    try {
      final dataRepetir = DateTime.parse(dataRepetirStr);
      return dataRepetir.isAfter(hoje)
          ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
          : const Icon(Icons.cancel, color: Colors.red, size: 28);
    } catch (_) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 28);
    }
  }

  // ✅ FORMATA DATA PARA DD/MM/AAAA
  String _formatarData(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return '---';
    try {
      final data = DateTime.parse(dataStr);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (_) {
      return dataStr;
    }
  }

  // ✅ FORMATA O TEXTO/ÍCONE DO STATUS NA LISTA
  String _textoStatus(dynamic lanc) {
    final status = lanc['status']?.toString().toUpperCase() ?? 'ATIVO';
    final hoje = DateTime.now();

    // Converte data de repetir
    DateTime? dataRepetir;
    try {
      final dataStr = lanc['repetir']?.toString();
      if (dataStr != null && dataStr.isNotEmpty) {
        dataRepetir = DateTime.parse(dataStr);
      }
    } catch (_) {}

    // ✅ REPETIDO → só ícone 🔁 (sem texto)
    if (status == 'REPETIDO') return ' • 🔁';

    // ✅ IGNORADO → só ícone 🔕 (sem texto)
    if (status == 'IGNORADO') return ' • 🔕';

    // ✅ ATIVO → mostra o texto
    final bool estaVencido = dataRepetir != null && dataRepetir.isBefore(hoje);
    return estaVencido ? ' - Vencido' : ' - No Prazo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment
              .spaceBetween, // ✅ Empurra o ícone para a direita
          children: [
            // ✅ LADO ESQUERDO — Título e nome do pet
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _categoriaSelecionada,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _nomePetExibicao,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            // ✅ LADO DIREITO — Ícone do PDF (só aparece em Vacinas)
            if (_categoriaSelecionada == 'Vacinas')
              IconButton(
                icon: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.white,
                  size: 26,
                ),
                tooltip: 'Cartão de Vacinação',
                onPressed: () => _mostrarOpcoesPdf(
                  context,
                  idPet: widget.idPet,
                  nomePet: _nomePetExibicao,
                ),
              ),
          ],
        ),
        backgroundColor: Cores.roxoEscuro,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ TÍTULO E FILTROS — FICAM EM CIMA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📋 $_textoFiltro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _filtro = _filtro == 'noprazo'
                                ? 'todos'
                                : 'noprazo';
                            _textoFiltro = _filtro == 'noprazo'
                                ? 'No Prazo'
                                : 'Todos';
                          });
                        }
                      },
                      icon: const Icon(Icons.check_circle),
                      color: _filtro == 'noprazo' ? Colors.green : Colors.grey,
                      tooltip: 'No prazo',
                    ),
                    IconButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _filtro = _filtro == 'vencidos'
                                ? 'todos'
                                : 'vencidos';
                            _textoFiltro = _filtro == 'vencidos'
                                ? 'Vencidas'
                                : 'Todos';
                          });
                        }
                      },
                      icon: const Icon(Icons.cancel),
                      color: _filtro == 'vencidos' ? Colors.red : Colors.grey,
                      tooltip: 'Vencidas',
                    ),
                    IconButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _filtro = _filtro == 'concluidos'
                                ? 'todos'
                                : 'concluidos';
                            _textoFiltro = _filtro == 'concluidos'
                                ? 'Finalizadas'
                                : 'Todos';
                          });
                        }
                      },
                      icon: const Icon(Icons.check_circle),
                      color: _filtro == 'concluidos'
                          ? Colors.blue
                          : Colors.grey,
                      tooltip: 'Finalizadas',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ✅ AQUI ESTÁ O SEGREDO → Expanded envolve SOMENTE a lista!
            Expanded(
              child: _carregandoLancamentos
                  ? const Center(child: CircularProgressIndicator())
                  : _listaFiltrada.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum lançamento ainda.\nToque em "+" para adicionar!',
                        style: TextStyle(color: Cores.textoClaro),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _listaFiltrada.length,
                      itemBuilder: (context, i) {
                        final lanc = _listaFiltrada[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: _iconeStatus(lanc),
                            title: Text(
                              lanc['descricao']?.toString() ?? 'Produto',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Data: ${_formatarData(lanc['data'])}\n'
                              'Vence: ${_formatarData(lanc['repetir'])}${_textoStatus(lanc)}',
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TelaLancamento(
                                    idPet: widget.idPet,
                                    lancamento: lanc,
                                    idCategoria: _idCategoria,
                                    idPetshop: widget.idPetshop,
                                  ),
                                ),
                              ).then((_) => _carregarLancamentos());
                            },
                            trailing: PopupMenuButton<String>(
                              onSelected: (opcao) {
                                if (opcao == 'repetir') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TelaLancamento(
                                        idPet: widget.idPet,
                                        idLancamentoRepetido: lanc['id'],
                                        lancamento: lanc,
                                        idCategoria: _idCategoria,
                                        idPetshop: widget.idPetshop,
                                      ),
                                    ),
                                  ).then((_) => _carregarLancamentos());
                                } else if (opcao == 'ignorar') {
                                  _ignorarAviso(lanc['id']);
                                }
                              },
                              itemBuilder: (context) {
                                final status =
                                    lanc['status']?.toString() ?? 'ATIVO';
                                final bool processado =
                                    status == 'REPETIDO' ||
                                    status == 'IGNORADO';
                                final hoje = DateTime.now();
                                DateTime? dataRepetir;
                                try {
                                  final dataStr = lanc['repetir']?.toString();
                                  if (dataStr != null && dataStr.isNotEmpty) {
                                    dataRepetir = DateTime.parse(dataStr);
                                  }
                                } catch (_) {}
                                final bool estaVencido =
                                    dataRepetir != null &&
                                    dataRepetir.isBefore(hoje);
                                return [
                                  PopupMenuItem(
                                    value: processado ? null : 'repetir',
                                    enabled: !processado,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.repeat,
                                          size: 18,
                                          color: processado
                                              ? Colors.grey
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Repetir Agora',
                                          style: TextStyle(
                                            color: processado
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: (!processado && estaVencido)
                                        ? 'ignorar'
                                        : null,
                                    enabled: !processado && estaVencido,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.notifications_off,
                                          size: 18,
                                          color: (processado || !estaVencido)
                                              ? Colors.grey
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Ignorar Aviso',
                                          style: TextStyle(
                                            color: (processado || !estaVencido)
                                                ? Colors.grey
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ), // ✅ FIM DO Expanded — A LISTA ACABA AQUI
            // ==============================================
            // ✅ BOTÃO ESTÁ FORA DO Expanded → FICA EMBAIXO!
            // ==============================================
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _carregando ? null : _adicionar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Cores.roxoEscuro,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(56, 56),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _carregando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.add, size: 28),
              ),
            ),
          ],
        ),
      ),
      // 🟣 BARRA DE CATEGORIAS
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceSelecionado,
        onTap: _aoTrocarCategoria,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Cores.roxoEscuro,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.vaccines),
            label: 'Vacinas',
          ), // ✅ Já está certo
          BottomNavigationBarItem(
            icon: Icon(Icons.pets_outlined),
            label: 'Alimentação',
          ), // ✅ OSSO 🦴
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Saúde',
          ), // ✅ Já está certo
          BottomNavigationBarItem(
            icon: Icon(Icons.bathtub),
            label: 'Higiene',
          ), // ✅ BANHEIRA 🛁
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Outros',
          ), // ✅ Já está certo
        ],
      ),
    );
  }

  Future<void> _buscarNomePet() async {
    print('🔍 Buscando pet ID: ${widget.idPet}');
    try {
      final resposta = await http.get(
        Uri.parse('$apiBase/pets/${widget.idPet}'),
      );
      print('🔍 Status API: ${resposta.statusCode}');

      if (!mounted) return;
      if (resposta.statusCode == 200) {
        final dados = json.decode(resposta.body);
        print('🔍 Dados do pet: $dados');
        setState(() {
          _nomePetExibicao = dados['nome'] ?? 'Pet';
          print('🔍 Nome definido: $_nomePetExibicao');
        });
      }
    } catch (e) {
      print('❌ Erro: $e');
      if (!mounted) return;
      setState(() {
        _nomePetExibicao = 'Pet';
      });
    }
  }

  // ✅ MOSTRA AS OPÇÕES: Visualizar | Baixar | Compartilhar
  // ✅ OPÇÕES SIMPLIFICADAS — Baixar e Compartilhar
  Future<void> _mostrarOpcoesPdf(
    BuildContext context, {
    required dynamic idPet,
    required String nomePet,
  }) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Cartão de Vacinação',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),

            // ✅ Opção 1 — Baixar/Salvar
            ListTile(
              leading: const Icon(
                Icons.download_for_offline_outlined,
                color: Colors.green,
              ),
              title: const Text('Baixar'),
              subtitle: const Text('Salvar na pasta Downloads'),
              onTap: () {
                Navigator.pop(ctx);
                _baixarPdf(context, idPet: idPet, nomePet: nomePet);
              },
            ),
            const Divider(height: 1),

            // ✅ Opção 2 — Compartilhar
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Compartilhar'),
              subtitle: const Text('Enviar por WhatsApp, e-mail...'),
              onTap: () {
                Navigator.pop(ctx);
                _compartilharPdf(context, idPet: idPet, nomePet: nomePet);
              },
            ),
            const Divider(height: 1),

            // ✅ Cancelar
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  // ✅ 1 — VISUALIZAR PDF na tela
  // ──────────────────────────────────────────────────────
  Future<void> _visualizarPdf(
    BuildContext contexto, {
    required dynamic idPet,
    required String nomePet,
  }) async {
    ScaffoldMessenger.of(contexto).showSnackBar(
      const SnackBar(content: Text('📄 Carregando visualização...')),
    );

    final arquivo = await _gerarArquivoPdf(idPet, nomePet);
    if (arquivo == null || !contexto.mounted) return;

    // ✅ Abre tela de visualização
    Navigator.push(
      contexto,
      MaterialPageRoute(
        builder: (newCtx) => TelaVisualizacaoPdf(
          caminhoArquivo: arquivo.path,
          nomeArquivo: 'Cartão de Vacinação - $nomePet',
        ),
      ),
    );
  }

  // ✅ BAIXAR — Salva na pasta Downloads do celular
  Future<void> _baixarPdf(
    BuildContext context, {
    required dynamic idPet,
    required String nomePet,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('💾 Salvando na pasta Downloads...')),
    );

    final arquivo = await _gerarArquivoPdf(idPet, nomePet);
    if (arquivo == null || !context.mounted) return;

    try {
      // ✅ Obtém a pasta de DOWNLOADS do celular
      Directory? pastaDownloads;

      if (Platform.isAndroid) {
        pastaDownloads = Directory('/storage/emulated/0/Download');
        // Cria a pasta se não existir
        if (!await pastaDownloads.exists()) {
          await pastaDownloads.create(recursive: true);
        }
      } else {
        // iOS — usa pasta de documentos
        pastaDownloads = await getApplicationDocumentsDirectory();
      }

      // ✅ Nome do arquivo limpo
      String nomeArquivo =
          'Cartao_Vacina_${nomePet.replaceAll(' ', '_')}_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.pdf';

      // ✅ Caminho final
      String caminhoFinal = '${pastaDownloads.path}/$nomeArquivo';

      // ✅ Copia o arquivo
      await arquivo.copy(caminhoFinal);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Salvo na Downloads: $nomeArquivo'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // ✅ Se não conseguir na raiz, salva na pasta do app como alternativa
      try {
        final pastaDocs = await getApplicationDocumentsDirectory();
        String nomeArquivo =
            'Cartao_Vacina_${nomePet.replaceAll(' ', '_')}.pdf';
        String caminhoFinal = '${pastaDocs.path}/$nomeArquivo';
        await arquivo.copy(caminhoFinal);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Salvo: $caminhoFinal'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erro ao salvar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────
  // ✅ 3 — COMPARTILHAR direto
  // ──────────────────────────────────────────────────────
  Future<void> _compartilharPdf(
    BuildContext contexto, {
    required dynamic idPet,
    required String nomePet,
  }) async {
    final arquivo = await _gerarArquivoPdf(idPet, nomePet);
    if (arquivo == null || !contexto.mounted) return;

    await Share.shareXFiles(
      [XFile(arquivo.path)],
      text: '📋 Cartão de Vacinação — $nomePet',
      subject: 'Cartão de Vacinação - $nomePet',
    );
  }

  // ──────────────────────────────────────────────────────
  // ✅ FUNÇÃO COMUM — Gera o arquivo PDF e retorna
  // ──────────────────────────────────────────────────────
  Future<File?> _gerarArquivoPdf(dynamic idPet, String nomePet) async {
    try {
      // 1️⃣ Busca dados do Pet
      final resPet = await http.get(Uri.parse('$apiBase/pets/$idPet'));
      if (resPet.statusCode != 200) throw Exception('Pet não encontrado');
      final pet = json.decode(resPet.body);

      // 2️⃣ Busca vacinas
      final resVacinas = await http.get(
        Uri.parse('$apiBase/lancamentos/vacinas/$idPet'),
      );
      List<dynamic> vacinas = [];
      if (resVacinas.statusCode == 200) {
        vacinas = json.decode(resVacinas.body);
      }

      // 3️⃣ Cálculo da idade
      String calcularIdade(dynamic nascimento) {
        if (nascimento == null) return 'Não informada';
        try {
          DateTime nas = DateTime.parse(nascimento.toString());
          DateTime hoje = DateTime.now();
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
          List<String> p = [];
          if (anos > 0) p.add('$anos ${anos == 1 ? "ano" : "anos"}');
          if (meses > 0) p.add('$meses ${meses == 1 ? "mês" : "meses"}');
          if (dias > 0 && p.isEmpty)
            p.add('$dias ${dias == 1 ? "dia" : "dias"}');
          return p.join(' e ');
        } catch (_) {
          return 'Não informada';
        }
      }

      // 4️⃣ Formata data
      String formatarData(dynamic data) {
        if (data == null || data.toString().isEmpty) return '—';
        try {
          DateTime d = DateTime.parse(data.toString());
          return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
        } catch (_) {
          return data.toString();
        }
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 🟦 CABEÇALHO
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#6A48B5'),
                    borderRadius: pw.BorderRadius.vertical(
                      top: pw.Radius.circular(8),
                    ),
                  ),
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 28,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '🐾 CARTÃO DE VACINAÇÃO',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        nomePet,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 20,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'PetShop CRM — Saúde Animal',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#E0D9F2'),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // 📋 DADOS DO PET
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8F5FC'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '🔹 DADOS DO ANIMAL',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#6A48B5'),
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        '🐶 Nome:        $nomePet',
                        style: const pw.TextStyle(fontSize: 15),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '🎂 Nascimento:  ${formatarData(pet['nascimento'])}    Idade:  ${calcularIdade(pet['nascimento'])}',
                        style: const pw.TextStyle(fontSize: 15),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '📋 Espécie:     ${pet['especie']?['nomeEspecie'] ?? 'Não informada'}    Raça:  ${pet['raca']?['nome'] ?? 'Não informada'}',
                        style: const pw.TextStyle(fontSize: 15),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '👤 Tutor:       ${pet['nomeTutor'] ?? 'Não informado'}',
                        style: const pw.TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // 💉 TÍTULO
                pw.Text(
                  '💉 VACINAS APLICADAS',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#6A48B5'),
                  ),
                ),
                pw.SizedBox(height: 16),

                // 📊 CABEÇALHO DA TABELA
                pw.Container(
                  color: PdfColor.fromHex('#EDE5F7'),
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 10,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 26,
                        child: pw.Text(
                          'Vacina',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 20,
                        child: pw.Text(
                          'Aplicação',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 20,
                        child: pw.Text(
                          'Próxima Dose',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 34,
                        child: pw.Text(
                          'Observações',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 📝 LINHAS DAS VACINAS
                ...vacinas.asMap().entries.map((entry) {
                  int i = entry.key;
                  var vac = entry.value;
                  final corLinha = i % 2 == 0
                      ? PdfColors.white
                      : PdfColor.fromHex('#F8F5FC');
                  return pw.Container(
                    color: corLinha,
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 26,
                          child: pw.Text(
                            vac['nome'] ?? vac['produto']?['nome'] ?? '—',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ),
                        pw.Expanded(
                          flex: 20,
                          child: pw.Text(
                            formatarData(vac['dataAplicacao'] ?? vac['data']),
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ),
                        pw.Expanded(
                          flex: 20,
                          child: pw.Text(
                            formatarData(vac['proximaDose']),
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ),
                        pw.Expanded(
                          flex: 34,
                          child: pw.Text(
                            vac['observacoes']?.toString() ?? '—',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 32),
                pw.Divider(thickness: 1, color: PdfColor.fromHex('#C4B5DD')),
                pw.SizedBox(height: 24),

                // 🏥 PROFISSIONAL
                pw.Text(
                  '🏥 Aplicado por: ___________________________________________________',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  '   CRMV: ____/_____-__',
                  style: const pw.TextStyle(fontSize: 14),
                ),

                pw.SizedBox(height: 40),

                // ✍️ LOCAL E DATA — rodapé
                pw.Divider(thickness: 2, color: PdfColor.fromHex('#6A48B5')),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Local: _____________________________________',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Data: _____/_____/________________',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Center(
                  child: pw.Text(
                    '🐾 PetShop CRM — Sistema de Gestão Veterinária',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // 6️⃣ Salva temporariamente
      final diretorio = await getTemporaryDirectory();
      final arquivo = File(
        '${diretorio.path}/cartao_vacina_${idPet}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await arquivo.writeAsBytes(await pdf.save());

      return arquivo;
    } catch (e) {
      debugPrint('❌ Erro ao gerar PDF: $e');
      return null;
    }
  }
}
