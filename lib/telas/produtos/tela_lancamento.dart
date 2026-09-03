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

  const TelaLancamento({
    super.key,
    required this.idPet,
    this.idLancamentoRepetido,
    this.lancamento,
  });

  @override
  State<TelaLancamento> createState() => _TelaLancamentoState();
}

class _TelaLancamentoState extends State<TelaLancamento> {
  String? _nomeProduto;
  dynamic _idProduto;

  // ✅ CONTROLADORES
  final _dataController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _anosController = TextEditingController();
  final _mesesController = TextEditingController();
  final _diasController = TextEditingController();
  final _proximaDoseController = TextEditingController();

  File? _foto;
  dynamic _idLancamento;
  String? _urlFoto;
  final _imagePicker = ImagePicker();
  bool _carregandoFoto = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();

    // ✅ ==============================================
    // ✅ REPETIR AGORA → Abre como NOVO lançamento
    // ✅ ==============================================
    if (widget.idLancamentoRepetido != null && widget.lancamento != null) {
      final lanc = widget.lancamento;

      // 🔑 SEM ID = É NOVO, NÃO EDIÇÃO!
      _idLancamento = null;

      // ✅ Copia só produto e observações
      _idProduto = lanc['idProduto'];
      _nomeProduto = lanc['descricao']?.toString();
      _observacoesController.text = lanc['observacao']?.toString() ?? '';
      _urlFoto = lanc['foto']?.toString();

      // ✅ SEMPRE DATA DE HOJE (igual ao botão "+")
      final hoje = DateTime.now();
      _dataController.text =
          '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';

      // ✅ Campo "Repetir em" fica VAZIO para preencher novo
      _proximaDoseController.text = '';
    }
    // ✅ ==============================================
    // ✅ EDIÇÃO → Se vier com ID, abre como edição
    // ✅ ==============================================
    else if (widget.lancamento != null) {
      final lanc = widget.lancamento;
      _idLancamento = lanc['id'];
      _idProduto = lanc['idProduto'];
      _nomeProduto = lanc['descricao']?.toString();
      _urlFoto = lanc['foto']?.toString();

      // ✅ Preenche data original da edição
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

      // ✅ Preenche data de repetir da edição
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
    // ✅ NOVO LANÇAMENTO pelo botão "+" → tudo em branco
    // ✅ ==============================================
    else {
      final hoje = DateTime.now();
      _dataController.text =
          '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
    }
  }

  // ✅ ABRIR JANELA DE BUSCA DE PRODUTO
  Future<void> _escolherProduto() async {
    setState(() => _salvando = true);
    try {
      const idCategoria = 1;
      final resposta = await http.get(
        Uri.parse('$apiBase/produtos/categoria/$idCategoria'),
      );
      setState(() => _salvando = false);
      if (!mounted) return;

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

      if (resultado != null) {
        setState(() {
          _nomeProduto = resultado['nome'];
          _idProduto = resultado['id'];
        });
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erro: $e')));
      }
    }
  }

  // ✅ CALCULAR PRÓXIMA DATA — CORRIGIDO COM VALIDAÇÃO
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
      if (partes.length != 3) {
        throw Exception('Formato inválido');
      }

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

      setState(() {});
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
    final XFile? escolhida = await _imagePicker.pickImage(
      source: origem,
      imageQuality: 70,
      maxWidth: 1000,
    );
    if (escolhida == null) return;
    setState(() {
      _foto = File(escolhida.path);
      _carregandoFoto = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Foto carregada!')));
    }
  }

  // ✅ SALVAR LANÇAMENTO
  Future<void> _salvarLancamento() async {
    // ✅ VALIDAÇÕES
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

    setState(() => _salvando = true);
    try {
      // ==========================================
      // ✅ ENVIAR FOTO PARA A API — IGUALZINHO AO PET!
      // ==========================================
      String? urlFotoGerada;
      if (_foto != null) {
        debugPrint('📸 Tem foto selecionada! Enviando...');
        try {
          var requisicao = http.MultipartRequest(
            'POST',
            Uri.parse('$apiBase/lancamentos/foto'),
          );
          requisicao.files.add(
            await http.MultipartFile.fromPath('arquivo', _foto!.path),
          );
          final resposta = await requisicao.send();
          debugPrint('☁️ Status da foto: ${resposta.statusCode}');
          if (resposta.statusCode == 200) {
            final corpo = await resposta.stream.bytesToString();
            final dados = json.decode(corpo);

            // ✅ ==== GARANTE QUE A URL EXISTE ====
            if (dados['urlFoto'] != null) {
              urlFotoGerada = dados['urlFoto'];
              _urlFoto = urlFotoGerada;
              debugPrint('✅ FOTO SALVA COM SUCESSO! URL: $_urlFoto');
            }
            // ✅ ==== FIM ====
          }
        } catch (e) {
          debugPrint('❌ ERRO AO ENVIAR FOTO: $e');
        }
      } else {
        debugPrint('📸 Sem foto nova para enviar');
      }
      // ==========================================
      // ✅ CONVERTE DATA
      final partesData = _dataController.text.split('/');
      final dataFormatada =
          '${partesData[2]}-${partesData[1]}-${partesData[0]}';

      // ✅ DATA DE REPETIR
      String? dataRepetir;
      if (_proximaDoseController.text.isNotEmpty) {
        final partesRepetir = _proximaDoseController.text.split('/');
        dataRepetir =
            '${partesRepetir[2]}-${partesRepetir[1]}-${partesRepetir[0]}';
      }

      // ✅ MONTAR DADOS
      // ✅ MONTA DADOS
      final Map<String, dynamic> dados = {
        'idPet': widget.idPet,
        'idProduto': _idProduto,
        'data': dataFormatada,
        'observacao': _observacoesController.text.trim().toUpperCase(),
        'repetir': dataRepetir,
        'foto': _urlFoto,
        'idPetshops': null,
      };

      // ✅ SÓ INCLUI O ID ANTIGO SE TIVER — SEMPRE SEPARADO!
      if (widget.idLancamentoRepetido != null) {
        dados['idLancamentoRepetido'] = widget.idLancamentoRepetido;
      }

      // ✅ NOVO LANÇAMENTO: SEM "Repetir em" = IGNORADO | PREENCHIDO = ATIVO
      if (_idLancamento == null) {
        dados['status'] = _proximaDoseController.text.trim().isEmpty
            ? 'IGNORADO'
            : 'ATIVO';
      }

      debugPrint(
        '📤 ENVIANDO PARA API: ${json.encode(dados)}',
      ); // ✅ LOG IMPORTANTE!

      // ✅ ENVIAR
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

      debugPrint('📥 RESPOSTA API: ${resposta.statusCode} - ${resposta.body}');

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
      debugPrint('❌ ERRO GERAL: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _idLancamento != null ? 'Editar Lançamento' : 'Novo Lançamento',
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
              // ✅ SELEÇÃO DO PRODUTO
              _nomeProduto == null
                  ? InkWell(
                      onTap: _salvando ? null : _escolherProduto,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Clique para selecionar',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.search,
                              color: Cores.roxoEscuro,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _nomeProduto!,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Cores.roxoEscuro,
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: _escolherProduto,
                            child: const Icon(
                              Icons.search,
                              color: Cores.roxoEscuro,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
              const SizedBox(height: 16),

              // ✅ CAMPO DE DATA — ESTAVA FALTANDO! 🎯
              TextField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: '📅 Data',
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
                  if (escolhida != null) {
                    _dataController.text =
                        '${escolhida.day.toString().padLeft(2, '0')}/'
                        '${escolhida.month.toString().padLeft(2, '0')}/'
                        '${escolhida.year}';
                    setState(() {});
                  }
                },
                readOnly: true,
              ),
              const SizedBox(height: 24),

              // ✅ OBSERVAÇÕES
              TextField(
                controller: _observacoesController,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
              ),
              const SizedBox(height: 24),

              // ✅ FOTO
              InkWell(
                onTap: () {
                  // ✅ SE JÁ TEM FOTO SALVA DA API → ABRE EM TELA CHEIA
                  if (_urlFoto != null && _foto == null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TelaFotoCheiaUrl(urlFoto: _urlFoto!),
                      ),
                    );
                  }
                  // ✅ SE É FOTO NOVA ESCOLHIDA → ABRE EM TELA CHEIA
                  else if (_foto != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TelaFotoCheia(arquivoFoto: _foto!),
                      ),
                    );
                  }
                  // ✅ NÃO TEM FOTO → ABRE OPÇÃO PARA ESCOLHER
                  else {
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
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 220,
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
                              size: 48,
                              color: Cores.roxoEscuro,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Toque para adicionar foto',
                              style: TextStyle(
                                color: Cores.roxoEscuro,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ✅ CÁLCULO: ME LEMBRE EM...
              const Text(
                '⏰ Me lembre em:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                  const SizedBox(width: 8),
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
                  const SizedBox(width: 8),
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
                ],
              ),
              const SizedBox(height: 12),

              // ✅ BOTÃO CALCULAR
              ElevatedButton.icon(
                onPressed: _calcularProximaDose,
                icon: const Icon(Icons.calculate),
                label: const Text('Calcular'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Cores.roxoEscuro,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // ✅ REPETIR EM
              TextField(
                controller: _proximaDoseController,
                decoration: const InputDecoration(
                  labelText: '📅 Repetir em',
                  prefixIcon: Icon(Icons.schedule),
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
                  if (escolhida != null) {
                    _proximaDoseController.text =
                        '${escolhida.day.toString().padLeft(2, '0')}/'
                        '${escolhida.month.toString().padLeft(2, '0')}/'
                        '${escolhida.year}';
                    setState(() {});
                  }
                },
                readOnly: true,
              ),
              const SizedBox(height: 24),

              // ✅ BOTÃO SALVAR
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvarLancamento,
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

  // ✅ CONFIRMAR EXCLUSÃO
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
      setState(() => _salvando = true);
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
}

// ✅ TELA DE FOTO EM TELA CHEIA
class TelaFotoCheia extends StatelessWidget {
  final File arquivoFoto;
  const TelaFotoCheia({super.key, required this.arquivoFoto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Foto'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(arquivoFoto, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ✅ TELA DE FOTO EM TELA CHEIA — PARA FOTOS DA INTERNET (URL)
class TelaFotoCheiaUrl extends StatelessWidget {
  final String urlFoto;
  const TelaFotoCheiaUrl({super.key, required this.urlFoto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Foto'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(urlFoto, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
