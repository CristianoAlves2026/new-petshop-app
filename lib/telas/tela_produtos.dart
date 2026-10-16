import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constantes.dart';
import 'produtos/tela_lancamento.dart';
//import 'tela_cartao_vacina.dart'; // ✅ Adicione esta linha
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
//import 'dart:convert';
//import 'tela_visualizacao_pdf.dart';
//import 'dart:io'; // ✅ Para reconhecer Platform
import 'package:path/path.dart' as path;
import 'gerar_arquivopdf.dart';
//import 'package:share_plus/share_plus.dart';

class TelaProdutos extends StatefulWidget {
  final String nomePet;
  final dynamic idPet;
  final dynamic idPetshop;
  final String? categoria;
  final String? fotoPet;
  final dynamic idRacaPet;

  const TelaProdutos({
    super.key,
    required this.nomePet,
    required this.idPet,
    this.idPetshop,
    this.categoria,
    this.fotoPet,
    this.idRacaPet,
  });

  @override
  State<TelaProdutos> createState() => _TelaProdutosState();
}

class _TelaProdutosState extends State<TelaProdutos> {
  // ✅ Vacinas JÁ selecionada por padrão
  int _indiceSelecionado = 0;
  List<dynamic> _listaProdutos = [];
  List<dynamic> _listaLancamentos = [];
  List<dynamic> _listaRacas = [];
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

  // ✅ ENCERRAR LANÇAMENTO → status = REPETIDO
  Future<void> _encerrarLancamento(dynamic idLancamento) async {
    setState(() => _carregando = true);
    try {
      final resposta = await http.put(
        Uri.parse('$apiBase/lancamentos/$idLancamento/encerrar'),
        headers: {'Content-Type': 'application/json'},
      );

      if (resposta.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _categoriaSelecionada == 'Vacinas'
                    ? '✅ Vacina regularizada com sucesso!'
                    : '✅ Lançamento finalizado!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _carregarLancamentos();
        }
      } else {
        throw Exception('Não foi possível finalizar');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
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
        // ✅ NO PRAZO → ATIVO ou IGNORADO + data AINDA NÃO PASSOU
        case 'noprazo':
          return status != 'REPETIDO' && !estaVencido;

        // ✅ VENCIDOS → ATIVO ou IGNORADO + data JÁ PASSOU
        case 'vencidos':
          return status != 'REPETIDO' && estaVencido;

        // ✅ FINALIZADAS → SOMENTE status = REPETIDO
        case 'concluidos':
          return status == 'REPETIDO';

        // TODOS → mostra tudo
        default:
          return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _carregarRacas();
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
    final hoje = DateTime.now();

    // ✅ SÓ REPETIDO → ícone azul
    if (status == 'REPETIDO') {
      return const Icon(Icons.check_circle, color: Colors.blue, size: 28);
    }

    // ✅ ATIVO ou IGNORADO → verificam a data
    final dataRepetirStr = lanc['repetir']?.toString();
    if (dataRepetirStr == null || dataRepetirStr.isEmpty) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 28);
    }

    try {
      final dataRepetir = DateTime.parse(dataRepetirStr);
      return dataRepetir.isAfter(hoje)
          ? const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 28,
            ) // ✅ No Prazo
          : const Icon(Icons.cancel, color: Colors.red, size: 28); // ❌ Vencido
    } catch (_) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 28);
    }
  }

  // ✅ FORMATA DATA PARA DD/MM/AAAAf
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
    if (status == 'REPETIDO') return ' - Finalizada'; //• 🔁

    // ✅ IGNORADO → só ícone 🔕 (sem texto)
    if (status == 'IGNORADO') return ' - 🔕 Silencida';

    // ✅ ATIVO → mostra o texto
    final bool estaVencido = dataRepetir != null && dataRepetir.isBefore(hoje);
    return estaVencido ? ' - Vencido' : ' - Em dia';
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
                                ? 'Em dia'
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
                                } else if (opcao == 'encerrar') {
                                  _encerrarLancamento(lanc['id']); // ✅ NOVO
                                }
                              },
                              itemBuilder: (context) {
                                final status =
                                    lanc['status']?.toString() ?? 'ATIVO';
                                final bool processado =
                                    status == 'REPETIDO'; //||
                                //status == 'IGNORADO';
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
                                final bool ehVacina =
                                    _categoriaSelecionada == 'Vacinas';

                                return [
                                  // ✅ 1 — Repetir Dose / Comprar Novamente
                                  PopupMenuItem(
                                    value: processado ? null : 'repetir',
                                    enabled:
                                        !processado, // ✅ Em dia e Vencido = habilitado | Finalizado = desabilitado
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
                                          ehVacina
                                              ? 'Próxima Dose'
                                              : 'Comprar Novamente',
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

                                  // ✅ 2 — Silenciar
                                  PopupMenuItem(
                                    value: processado ? null : 'ignorar',
                                    enabled:
                                        !processado, // ✅ Em dia e Vencido = habilitado | Finalizado = desabilitado
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.notifications_off,
                                          size: 18,
                                          color: processado
                                              ? Colors.grey
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Silenciar Notificações',
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

                                  // ✅ 3 — Vacina Regularizada / Finalizar
                                  PopupMenuItem(
                                    value: processado ? null : 'encerrar',
                                    enabled:
                                        !processado, // ✅ Em dia e Vencido = habilitado | Finalizado = desabilitado
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 18,
                                          color: processado
                                              ? Colors.grey
                                              : Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          ehVacina
                                              ? 'Vacina Regularizada'
                                              : 'Finalizar',
                                          style: TextStyle(
                                            color: processado
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

  // ✅ OPÇÕES — Baixar e Compartilhar
  Future<void> _mostrarOpcoesPdf(
    BuildContext context, {
    required dynamic idPet,
    required String nomePet,
  }) async {
    final gerador = GerarArquivoPdf();
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
            ListTile(
              leading: const Icon(
                Icons.download_for_offline_outlined,
                color: Colors.green,
              ),
              title: const Text('Baixar'),
              subtitle: const Text('Salvar na pasta Downloads'),
              onTap: () {
                Navigator.pop(ctx);
                gerador.baixarPdf(
                  context,
                  idPet: idPet,
                  nomePet: nomePet,
                  fotoPet: widget.fotoPet,
                  idRacaPet: widget.idRacaPet,
                  listaRacas: _listaRacas,
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Compartilhar'),
              subtitle: const Text('Enviar por WhatsApp, e-mail...'),
              onTap: () async {
                Navigator.pop(ctx);
                final arquivo = await gerador.gerarPdf(
                  idPet,
                  nomePet,
                  fotoPet: widget.fotoPet,
                  idRacaPet: widget.idRacaPet,
                  listaRacas: _listaRacas,
                );
                if (arquivo != null && context.mounted) {
                  await Share.shareXFiles(
                    [XFile(arquivo.path)],
                    text: '📋 Cartão de Vacinação — $nomePet',
                    subject: 'Cartão de Vacinação - $nomePet',
                  );
                }
              },
            ),
            const Divider(height: 1),
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

  Future<void> _carregarRacas() async {
    try {
      final resposta = await http.get(Uri.parse('$apiBase/racas'));
      if (resposta.statusCode == 200) {
        setState(() {
          _listaRacas = json.decode(resposta.body);
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar raças: $e');
    }
  }
}
