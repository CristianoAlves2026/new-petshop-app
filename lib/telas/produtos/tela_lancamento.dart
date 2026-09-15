import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../utils/constantes.dart';
import 'package:flutter/services.dart';

// ✅ FORMATA PARA MAIÚSCULAS AUTOMATICAMENTE
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue textoAntigo,
    TextEditingValue textoNovo,
  ) {
    return TextEditingValue(
      text: textoNovo.text.toUpperCase(),
      selection: textoNovo.selection,
    );
  }
}

class TelaLancamento extends StatefulWidget {
  final dynamic idPet;
  final dynamic idLancamentoRepetido;
  final dynamic lancamento;
  final dynamic idCategoria;
  final dynamic idPetshop;
  final dynamic nomePetshop;

  const TelaLancamento({
    super.key,
    required this.idPet,
    this.idLancamentoRepetido,
    this.lancamento,
    this.idCategoria = 1,
    this.idPetshop,
    this.nomePetshop,
  });

  @override
  State<TelaLancamento> createState() => _TelaLancamentoState();
}

class _TelaLancamentoState extends State<TelaLancamento> {
  String? _nomeProduto;
  dynamic _idProduto;
  final _dataController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _anosController = TextEditingController();
  final _mesesController = TextEditingController();
  final _diasController = TextEditingController();
  final _proximaDoseController = TextEditingController();
  dynamic _idPetshopSelecionado;
  String? _nomePetshopSelecionado;
  final _codigoPetshopController = TextEditingController();

  File? _foto;
  dynamic _idLancamento;
  String? _urlFoto;
  final _imagePicker = ImagePicker();
  bool _carregandoFoto = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();

    _idPetshopSelecionado = widget.idPetshop;
    _codigoPetshopController.text = widget.idPetshop?.toString() ?? '';

    // ✅ BUSCA O NOME DO PETSHOP AUTOMATICAMENTE PELO ID
    if (widget.idPetshop != null && widget.idPetshop.toString().isNotEmpty) {
      Future.microtask(
        () => _buscarPetshopPorCodigo(widget.idPetshop.toString()),
      );
    }

    // ✅ ==============================================
    // ✅ REPETIR LANÇAMENTO
    // ✅ ==============================================
    if (widget.idLancamentoRepetido != null && widget.lancamento != null) {
      final lanc = widget.lancamento;
      _idLancamento = null;
      _idProduto = lanc['idProduto'];
      _nomeProduto = lanc['descricao']?.toString();
      _observacoesController.text = lanc['observacao']?.toString() ?? '';
      _urlFoto = lanc['foto']?.toString();
      final hoje = DateTime.now();
      _dataController.text =
          '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
      _proximaDoseController.text = '';
    }
    // ✅ ==============================================
    // ✅ EDIÇÃO DE LANÇAMENTO
    // ✅ ==============================================
    else if (widget.lancamento != null) {
      final lanc = widget.lancamento;
      _idLancamento = lanc['id'];
      _idProduto = lanc['idProduto'];
      _nomeProduto = lanc['descricao']?.toString();
      _urlFoto = lanc['foto']?.toString();
      try {
        final dataTexto = lanc['data']?.toString() ?? '';
        if (dataTexto.isNotEmpty) {
          final data = DateTime.parse(dataTexto);
          _dataController.text =
              '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
        }
      } catch (e) {
        debugPrint('❌ Erro ao carregar data: $e');
      }
      try {
        final repetirTexto = lanc['repetir']?.toString() ?? '';
        if (repetirTexto.isNotEmpty) {
          final repetir = DateTime.parse(repetirTexto);
          _proximaDoseController.text =
              '${repetir.day.toString().padLeft(2, '0')}/${repetir.month.toString().padLeft(2, '0')}/${repetir.year}';
        }
      } catch (e) {
        debugPrint('❌ Erro ao carregar repetir: $e');
      }
      _observacoesController.text = lanc['observacao']?.toString() ?? '';
    }
    // ✅ ==============================================
    // ✅ NOVO LANÇAMENTO
    // ✅ ==============================================
    else {
      final hoje = DateTime.now();
      _dataController.text =
          '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
    }
    // ✅ CARREGA PETSHOP QUE VEIO DA TELA DO PET
    _idPetshopSelecionado = widget.idPetshop;
    _nomePetshopSelecionado = widget.nomePetshop;
    _codigoPetshopController.text = widget.idPetshop?.toString() ?? '';
  }

  // ✅ ABRIR JANELA DE BUSCA DE PRODUTO
  Future<void> _escolherProduto() async {
    if (!mounted) return;

    try {
      final idCategoria = widget.idCategoria;
      final resposta = await http.get(
        Uri.parse('$apiBase/produtos/categoria/$idCategoria'),
      );

      if (!mounted) return; // ✅ PROTEÇÃO

      if (resposta.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erro ao carregar produtos')),
        );
        return;
      }
      final List<dynamic> lista = json.decode(resposta.body);
      if (lista.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nenhum produto encontrado')),
        );
        return;
      }
      final resultado = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          String textoBusca = '';
          List<dynamic> listaFiltrada = List.from(lista);
          return StatefulBuilder(
            builder: (context, atualizar) {
              return AlertDialog(
                title: const Text('📋 Escolher Produto'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Digite para buscar...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (texto) {
                          atualizar(() {
                            textoBusca = texto;
                            listaFiltrada = lista
                                .where(
                                  (p) => p['descricao']
                                      .toString()
                                      .toLowerCase()
                                      .contains(texto.toLowerCase()),
                                )
                                .toList();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: listaFiltrada.isEmpty
                            ? const Center(child: Text('Nenhum resultado'))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: listaFiltrada.length,
                                itemBuilder: (context, i) {
                                  final prod = listaFiltrada[i];
                                  return ListTile(
                                    title: Text(prod['descricao'].toString()),
                                    onTap: () {
                                      Navigator.pop(context, {
                                        'nome': prod['descricao'].toString(),
                                        'id': prod['id'],
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (resultado != null && mounted) {
        setState(() {
          _nomeProduto = resultado['nome'];
          _idProduto = resultado['id'];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _salvando = false); // ✅ PROTEÇÃO
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erro: $e')));
      }
    }
  }

  // ✅ BUSCA PETSHOP PELO CÓDIGO DIGITADO
  Future<void> _buscarPetshopPorCodigo(String codigo) async {
    if (codigo.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _nomePetshopSelecionado = null;
        _idPetshopSelecionado = null;
      });
      return;
    }
    try {
      final resposta = await http.get(Uri.parse('$apiBase/petshops/$codigo'));
      if (!mounted) return;
      if (resposta.statusCode == 200) {
        final dados = json.decode(resposta.body);

        if (!mounted) return;
        setState(() {
          _idPetshopSelecionado = dados['id'];
          _nomePetshopSelecionado = dados['nomeFantasia'];
        });
      } else {
        setState(() {
          _nomePetshopSelecionado = null;
          _idPetshopSelecionado = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nomePetshopSelecionado = null;
        _idPetshopSelecionado = null;
      });
    }
  }

  // ✅ ABRE LISTA PARA ESCOLHER PETSHOP
  Future<void> _abrirListaPetshops() async {
    List<dynamic> listaPetshops = [];
    try {
      final resposta = await http.get(Uri.parse('$apiBase/petshops'));
      if (resposta.statusCode == 200) {
        listaPetshops = json.decode(resposta.body);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Não foi possível carregar os PetShops'),
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Erro de conexão')));
      return;
    }

    if (!mounted) return;
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String textoBusca = '';
        List<dynamic> listaFiltrada = List.from(listaPetshops);
        return StatefulBuilder(
          builder: (context, atualizar) {
            return AlertDialog(
              title: const Text('🏪 Escolher PetShop'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Digite para buscar...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (texto) {
                        atualizar(() {
                          textoBusca = texto;
                          listaFiltrada = listaPetshops
                              .where(
                                (p) => p['nomeFantasia']
                                    .toString()
                                    .toLowerCase()
                                    .contains(texto.toLowerCase()),
                              )
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: listaFiltrada.isEmpty
                          ? const Center(child: Text('Nenhum resultado'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: listaFiltrada.length,
                              itemBuilder: (context, i) {
                                final ps = listaFiltrada[i];
                                return ListTile(
                                  title: Text(
                                    ps['nomeFantasia'].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${ps['cidade'] ?? ''} - ${ps['bairro'] ?? ''}',
                                  ),
                                  onTap: () {
                                    Navigator.pop(context, {
                                      'id': ps['id'],
                                      'nome': ps['nomeFantasia'].toString(),
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != null && mounted) {
      setState(() {
        _idPetshopSelecionado = resultado['id'];
        _nomePetshopSelecionado = resultado['nome'];
        _codigoPetshopController.text = resultado['id'].toString();
      });
    }
  }

  // ✅ CALCULAR PRÓXIMA DATA
  void _calcularProximaDose() {
    try {
      final textoData = _dataController.text.trim();
      if (textoData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Informe a Data primeiro')),
        );
        return;
      }
      final partes = textoData.split('/');
      if (partes.length != 3) throw Exception('Formato inválido');
      final dataBase = DateTime.parse('${partes[2]}-${partes[1]}-${partes[0]}');
      int anos = int.tryParse(_anosController.text) ?? 0;
      int meses = int.tryParse(_mesesController.text) ?? 0;
      int dias = int.tryParse(_diasController.text) ?? 0;
      DateTime proxima = DateTime(
        dataBase.year + anos,
        dataBase.month + meses,
        dataBase.day + dias,
      );
      _proximaDoseController.text =
          '${proxima.day.toString().padLeft(2, '0')}/'
          '${proxima.month.toString().padLeft(2, '0')}/'
          '${proxima.year}';
      if (mounted) setState(() {}); // ✅ PROTEÇÃO
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Verifique a data informada')),
        );
      }
    }
  }

  // ✅ ESCOLHER FOTO
  Future<void> _escolherFoto(ImageSource origem) async {
    if (!mounted) return;
    final XFile? escolhida = await _imagePicker.pickImage(
      source: origem,
      imageQuality: 70,
      maxWidth: 1000,
    );
    if (escolhida == null) return;
    if (mounted) {
      // ✅ PROTEÇÃO
      setState(() {
        _foto = File(escolhida.path);
        _carregandoFoto = false;
      });
    }
  }

  // ✅ SALVAR LANÇAMENTO
  Future<void> _salvarLancamento() async {
    if (_salvando) return;
    if (!mounted) return;

    if (_idProduto == null || _nomeProduto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Escolha o produto primeiro!')),
      );
      return;
    }
    if (_dataController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Informe a Data')));
      return;
    }

    if (mounted) setState(() => _salvando = true); // ✅ PROTEÇÃO

    try {
      String? urlFotoGerada;
      if (_foto != null) {
        debugPrint('📸 Enviando foto...');
        try {
          var requisicao = http.MultipartRequest(
            'POST',
            Uri.parse('$apiBase/lancamentos/foto'),
          );
          requisicao.files.add(
            await http.MultipartFile.fromPath('arquivo', _foto!.path),
          );
          final resposta = await requisicao.send();
          debugPrint('☁️ Status foto: ${resposta.statusCode}');
          if (resposta.statusCode == 200) {
            final corpo = await resposta.stream.bytesToString();
            final dados = json.decode(corpo);
            if (dados['urlFoto'] != null) {
              urlFotoGerada = dados['urlFoto'];
              _urlFoto = urlFotoGerada;
              debugPrint('✅ Foto salva! URL: $_urlFoto');
            }
          }
        } catch (e) {
          debugPrint('❌ Erro ao enviar foto: $e');
        }
      }

      final partesData = _dataController.text.split('/');
      final dataFormatada =
          '${partesData[2]}-${partesData[1]}-${partesData[0]}';

      String? dataRepetir;
      if (_proximaDoseController.text.isNotEmpty) {
        final partesRepetir = _proximaDoseController.text.split('/');
        dataRepetir =
            '${partesRepetir[2]}-${partesRepetir[1]}-${partesRepetir[0]}';
      }

      final Map<String, dynamic> dados = {
        'idPet': widget.idPet,
        'idProduto': _idProduto,
        'data': dataFormatada,
        'observacao': _observacoesController.text.trim().toUpperCase(),
        'repetir': dataRepetir,
        'foto': _urlFoto,
        'idPetshop': _idPetshopSelecionado,
      };

      if (widget.idLancamentoRepetido != null) {
        dados['idLancamentoRepetido'] = widget.idLancamentoRepetido;
      }

      if (_idLancamento == null) {
        dados['status'] = _proximaDoseController.text.trim().isEmpty
            ? 'IGNORADO'
            : 'ATIVO';
      }

      debugPrint('📤 Enviando: ${json.encode(dados)}');

      final url = _idLancamento != null
          ? Uri.parse('$apiBase/lancamentos/$_idLancamento')
          : Uri.parse('$apiBase/lancamentos');

      final resposta = _idLancamento != null
          ? await http.put(
              url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(dados),
            )
          : await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(dados),
            );

      debugPrint('📥 Resposta: ${resposta.statusCode} - ${resposta.body}');

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Lançamento salvo com sucesso!'),
              backgroundColor: Cores.roxoEscuro,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Erro ao salvar');
      }
    } catch (e) {
      debugPrint('❌ Erro geral: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false); // ✅ PROTEÇÃO
    }
  }

  // ✅ NOME DA CATEGORIA
  String _obterNomeCategoria() {
    switch (widget.idCategoria) {
      case 1:
        return '💉 Vacinas';
      case 2:
        return '🥩 Alimentação';
      case 3:
        return '💊 Saúde';
      case 4:
        return '🧴 Higiene';
      case 5:
        return '📦 Outros';
      default:
        return '📋 Lançamento';
    }
  }

  // ✅ EXCLUIR LANÇAMENTO
  Future<void> _confirmarExcluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Lançamento'),
        content: const Text('Tem certeza que deseja excluir este lançamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      if (mounted) setState(() => _salvando = true);
      try {
        final resposta = await http.delete(
          Uri.parse('$apiBase/lancamentos/$_idLancamento'),
        );
        if (resposta.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Excluído com sucesso!')),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Erro: $e')));
        }
      } finally {
        if (mounted) setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _obterNomeCategoria() +
              (_idLancamento != null ? ' - Editar' : ' - Novo'),
        ),
        backgroundColor: Cores.roxoEscuro,
        foregroundColor: Colors.white,
        actions: [
          if (_idLancamento != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmarExcluir,
              tooltip: 'Excluir',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✅ SELEÇÃO DE PRODUTO
              _nomeProduto == null
                  ? InkWell(
                      onTap: _salvando ? null : _escolherProduto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Clique para selecionar',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.search,
                              color: Cores.roxoEscuro,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    )
                  : InkWell(
                      onTap: _salvando ? null : _escolherProduto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                _nomeProduto!,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Cores.roxoEscuro,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.search,
                              color: Cores.roxoEscuro,
                              size: 30,
                            ),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 20),

              // ✅ DATA
              TextField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: '📅 Data do Lançamento',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                  hintText: 'DD/MM/AAAA',
                ),
                onTap: () async {
                  DateTime? dataInicial;
                  try {
                    final texto = _dataController.text.trim();
                    if (texto.isNotEmpty) {
                      final partes = texto.split('/');
                      dataInicial = DateTime.parse(
                        '${partes[2]}-${partes[1]}-${partes[0]}',
                      );
                    }
                  } catch (_) {}
                  dataInicial ??= DateTime.now();
                  DateTime? escolhida = await showDatePicker(
                    context: context,
                    initialDate: dataInicial,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (escolhida != null && mounted) {
                    _dataController.text =
                        '${escolhida.day.toString().padLeft(2, '0')}/'
                        '${escolhida.month.toString().padLeft(2, '0')}/'
                        '${escolhida.year}';
                    if (mounted) setState(() {});
                  }
                },
                readOnly: true,
              ),
              const SizedBox(height: 20),

              // ✅ CAMPO PETSHOP — MESMO FORMATO DA TELA DO PET
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text(
                      'PetShop: ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Cores.roxoEscuro,
                      ),
                    ),
                    // ✅ CÓDIGO + NOME OU CAMPO PARA DIGITAR
                    Expanded(
                      child: _nomePetshopSelecionado != null
                          ? Text(
                              '${_idPetshopSelecionado ?? widget.idPetshop} — $_nomePetshopSelecionado',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : TextField(
                              controller: _codigoPetshopController,
                              decoration: const InputDecoration(
                                hintText: 'Código',
                                border: InputBorder.none,
                                counterText: '',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              style: const TextStyle(fontSize: 15),
                              onChanged: (valor) {
                                if (valor.trim().length == 3) {
                                  _buscarPetshopPorCodigo(valor.trim());
                                }
                              },
                            ),
                    ),
                    // ✅ BOTÃO LUPA
                    IconButton(
                      icon: const Icon(Icons.search, color: Cores.roxoEscuro),
                      onPressed: _salvando ? null : _abrirListaPetshops,
                      tooltip: 'Buscar PetShop',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ✅ FOTO
              InkWell(
                onTap: () {
                  Widget conteudoFoto;
                  if (_urlFoto != null) {
                    conteudoFoto = Image.network(
                      _urlFoto!,
                      fit: BoxFit.contain,
                    );
                  } else if (_foto != null) {
                    conteudoFoto = Image.file(_foto!, fit: BoxFit.contain);
                  } else {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Tirar foto'),
                              onTap: () {
                                Navigator.pop(context);
                                _escolherFoto(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Escolher da galeria'),
                              onTap: () {
                                Navigator.pop(context);
                                _escolherFoto(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          title: const Text(
                            'Foto',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.black,
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: Column(
                          children: [
                            Expanded(
                              child: InteractiveViewer(
                                child: Center(child: conteudoFoto),
                              ),
                            ),
                            Container(
                              color: Colors.black87,
                              padding: const EdgeInsets.all(16),
                              child: SafeArea(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _escolherFoto(ImageSource.camera);
                                        },
                                        icon: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          '📸 Tirar nova',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.all(12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _escolherFoto(ImageSource.gallery);
                                        },
                                        icon: const Icon(
                                          Icons.photo_library,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          '📂 Galeria',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.all(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Cores.roxoEscuro, width: 2),
                  ),
                  child: _urlFoto != null && _foto == null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _urlFoto!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : _foto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_foto!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: Cores.roxoEscuro,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Toque para adicionar foto',
                              style: TextStyle(
                                color: Cores.roxoEscuro,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ✅ ME LEMBRE EM
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Cores.roxoEscuro.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '⏰ Me lembre em:',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Cores.roxoEscuro,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _anosController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ano(s)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _mesesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Mês(es)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _diasController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Dia(s)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _calcularProximaDose,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Cores.roxoEscuro,
                              foregroundColor: Colors.white,
                            ),
                            child: const Icon(Icons.calculate, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _proximaDoseController,
                      decoration: const InputDecoration(
                        labelText: '🔁 Repetir em',
                        prefixIcon: Icon(
                          Icons.schedule,
                          color: Cores.roxoEscuro,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        DateTime? dataBase;
                        try {
                          final texto = _dataController.text.trim();
                          if (texto.isNotEmpty) {
                            final partes = texto.split('/');
                            dataBase = DateTime.parse(
                              '${partes[2]}-${partes[1]}-${partes[0]}',
                            );
                          }
                        } catch (_) {}
                        dataBase ??= DateTime.now();
                        DateTime? escolhida = await showDatePicker(
                          context: context,
                          initialDate: dataBase,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (escolhida != null && mounted) {
                          _proximaDoseController.text =
                              '${escolhida.day.toString().padLeft(2, '0')}/'
                              '${escolhida.month.toString().padLeft(2, '0')}/'
                              '${escolhida.year}';
                          setState(() {});
                        }
                      },
                      readOnly: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ✅ OBSERVAÇÕES
              TextField(
                controller: _observacoesController,
                decoration: const InputDecoration(
                  labelText: '📝 Observações',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
              ),
              const SizedBox(height: 28),

              // ✅ BOTÃO SALVAR
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _salvando ? null : () => _salvarLancamento(),
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save, size: 22),
                  label: Text(
                    _salvando ? 'Salvando...' : 'Salvar',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Cores.roxoEscuro,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
