import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constantes.dart';
import 'produtos/tela_lancamento.dart';

class TelaProdutos extends StatefulWidget {
  final String nomePet;
  final dynamic idPet;
  final dynamic idPetshop;

  const TelaProdutos({
    super.key,
    required this.nomePet,
    required this.idPet,
    this.idPetshop,
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
  String _textoFiltro = 'Histórico'; // ✅ Começa como "Histórico"

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
    print('🔍 idPetshop recebido: ${widget.idPetshop}');
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
    // ✅ GARANTE QUE O VALOR ESTÁ CERTO ANTES DE ENVIAR
    final categoriaParaEnviar = _idCategoria;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaLancamento(
          idPet: widget.idPet,
          idCategoria: categoriaParaEnviar, // ✅ ENVIA VALOR GARANTIDO
          idPetshop: widget.idPetshop,
        ),
      ),
    );
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
        title: Column(
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
              widget.nomePet, // ✅ NOME DO PET EM DESTAQUE
              style: const TextStyle(
                fontSize: 22, // ✅ MAIOR
                fontWeight: FontWeight.bold, // ✅ NEGRITO
                color: Colors.white, // ✅ BRANCO
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
}
