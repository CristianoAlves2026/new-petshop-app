import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/constantes.dart';
import 'package:flutter/services.dart';

class TelaCadastroPet extends StatefulWidget {
  final dynamic idTutor;
  final dynamic pet;
  const TelaCadastroPet({super.key, required this.idTutor, this.pet});
  @override
  State<TelaCadastroPet> createState() => _TelaCadastroPetState();
}

class _TelaCadastroPetState extends State<TelaCadastroPet> {
  final _nomeController = TextEditingController();
  final _nascimentoController = TextEditingController();
  final _anosController = TextEditingController();
  final _mesesController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _codigoPetshopController = TextEditingController();

  String? _urlFoto;
  String? _nomePetshopSelecionado;
  dynamic _idPetshopSelecionado; // ✅ ID do Petshop para salvar
  DateTime? _dataNascimento;
  List<dynamic> _listaRacas = [];
  String? _racaSelecionadaNome;
  dynamic _racaSelecionadaId;
  String _sexo = '';
  bool _castrado = false;
  bool _falecido = false;
  bool _carregando = false;
  bool _carregandoRacas = true;
  List<dynamic> _listaEspecies = [];
  String? _especieSelecionadaNome;
  dynamic _especieSelecionadaId;
  bool _carregandoEspecies = true;
  dynamic _idPet;
  final ImagePicker _imagePicker = ImagePicker();
  File? _arquivoFoto;

  @override
  void initState() {
    super.initState();
    // ✅ PRIMEIRO CARREGA TODAS AS LISTAS
    _carregarRacas().then((_) {
      _carregarEspecies().then((_) {
        // ✅ SÓ DEPOIS PREENCHE OS DADOS DA EDIÇÃO
        if (widget.pet != null) {
          _preencherDadosParaEdicao();
        }
      });
    });
  }

  void _preencherDadosParaEdicao() {
    final pet = widget.pet;
    debugPrint('🔍 ID Espécie do Pet: ${pet['idEspecie']}');
    _idPet = pet['id'];
    _nomeController.text = pet['nome']?.toString() ?? '';

    if (pet['nascimento'] != null && pet['nascimento'].toString().isNotEmpty) {
      _dataNascimento = DateTime.parse(pet['nascimento'].toString());
      _nascimentoController.text =
          "${_dataNascimento!.day}/${_dataNascimento!.month}/${_dataNascimento!.year}";
    }

    if (pet['idRaca'] != null) {
      _racaSelecionadaId = pet['idRaca'];
      // ✅ BUSCA E EXIBE O NOME DA RAÇA NA EDIÇÃO
      for (var raca in _listaRacas) {
        if (raca['id'] == _racaSelecionadaId) {
          _racaSelecionadaNome = raca['nome'];
          break;
        }
      }
    }

    // ✅ ==== AQUI VAMOS ADICIONAR O CARREGAMENTO DO PETSHOP ====
    if (pet['idPetshop'] != null) {
      _idPetshopSelecionado = pet['idPetshop'];
      _codigoPetshopController.text = _idPetshopSelecionado.toString();
      // ✅ Busca o nome do Petshop automaticamente
      _buscarPetshopPorCodigo(_idPetshopSelecionado.toString());
    }

    if (pet['idEspecie'] != null) {
      final idEspeciePet = pet['idEspecie'];
      for (var e in _listaEspecies) {
        if (e['id'] == idEspeciePet) {
          _especieSelecionadaId = e['id'];
          _especieSelecionadaNome =
              e['nomeEspecie']?.toString() ?? e['nome']?.toString();
          break;
        }
      }
    }

    _sexo = pet['sexo']?.toString() ?? '';
    _castrado = pet['castrado'] == true;
    _falecido = pet['falecido'] == true;

    final String? fotoUrl = pet['foto']?.toString();
    if (fotoUrl != null && fotoUrl.isNotEmpty) {
      _urlFoto = fotoUrl;
    } else {
      _urlFoto = null;
    }

    _observacoesController.text = pet['observacoes']?.toString() ?? '';
  }

  Future<void> _carregarRacas() async {
    try {
      final resposta = await http.get(Uri.parse('$apiBase/racas'));
      if (resposta.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _listaRacas = json.decode(resposta.body);
          _carregandoRacas = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoRacas = false);
      _mensagem('⚠️ Erro ao carregar raças', Colors.orange);
    }
  }

  Future<void> _carregarEspecies() async {
    try {
      final resposta = await http.get(Uri.parse('$apiBase/especies'));
      if (resposta.statusCode == 200) {
        _listaEspecies = json.decode(resposta.body);
        if (!mounted) return;
        setState(() => _carregandoEspecies = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoEspecies = false);
    }
  }

  void _selecionarEspecie() async {
    await showDialog(
      context: context,
      builder: (context) {
        String filtro = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtradas = _listaEspecies.where((especie) {
              final nome = (especie['nomeEspecie'] ?? '')
                  .toString()
                  .toLowerCase();
              return nome.contains(filtro.toLowerCase());
            }).toList();
            return AlertDialog(
              title: const Text('Selecionar Espécie'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '🔍 Buscar espécie',
                      ),
                      onChanged: (valor) =>
                          setDialogState(() => filtro = valor),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _carregandoEspecies
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtradas.length,
                              itemBuilder: (context, i) {
                                final especie = filtradas[i];
                                return ListTile(
                                  title: Text(especie['nomeEspecie'] ?? ''),
                                  onTap: () {
                                    if (!mounted) return;
                                    setState(() {
                                      _especieSelecionadaId = especie['id'];
                                      _especieSelecionadaNome =
                                          especie['nomeEspecie'];
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _calcularNascimento() {
    final anos = int.tryParse(_anosController.text) ?? 0;
    final meses = int.tryParse(_mesesController.text) ?? 0;
    if (anos == 0 && meses == 0) {
      _mensagem('⚠️ Informe os anos e/ou meses', Colors.orange);
      return;
    }
    DateTime hoje = DateTime.now();
    _dataNascimento = DateTime(hoje.year - anos, hoje.month - meses, hoje.day);
    _nascimentoController.text =
        "${_dataNascimento!.day.toString().padLeft(2, '0')}/${_dataNascimento!.month.toString().padLeft(2, '0')}/${_dataNascimento!.year}";
    _mensagem('✅ Data calculada!', const Color(0xFF512DA8));
  }

  // ✅ FOTO — ESCOLHER ORIGEM: CÂMERA OU GALERIA
  Future<void> _escolherFoto() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar foto com a câmera'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? foto = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 75,
                  maxWidth: 1024,
                  maxHeight: 1024,
                );
                if (foto != null) {
                  if (!mounted) return;
                  setState(() => _arquivoFoto = File(foto.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? foto = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 75,
                  maxWidth: 1024,
                  maxHeight: 1024,
                );
                if (foto != null) {
                  setState(() => _arquivoFoto = File(foto.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _enviarFoto() async {
    if (_arquivoFoto == null) return null;
    try {
      var requisicao = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/pets/foto'),
      );
      requisicao.files.add(
        await http.MultipartFile.fromPath('arquivo', _arquivoFoto!.path),
      );
      final resposta = await requisicao.send();
      if (resposta.statusCode == 200) {
        final corpo = await resposta.stream.bytesToString();
        final dados = json.decode(corpo);
        return dados['urlFoto'];
      }
    } catch (e) {
      _mensagem('❌ Erro ao enviar foto', Colors.red);
    }
    return null;
  }

  // ✅ BUSCA POR CÓDIGO — SÓ AVISA SE NÃO ENCONTRAR
  Future<void> _buscarPetshopPorCodigo(String codigo) async {
    if (codigo.trim().isEmpty) {
      if (!mounted) return; // ← ✅ ADICIONA ESTA LINHA
      setState(() {
        _nomePetshopSelecionado = null;
        _idPetshopSelecionado = null;
      });
      return;
    }

    try {
      final resposta = await http.get(Uri.parse('$apiBase/petshops/$codigo'));

      if (resposta.statusCode == 200) {
        final dados = json.decode(resposta.body);
        if (!mounted) return; // ← ✅ ADICIONA ESTA LINHA
        setState(() {
          _idPetshopSelecionado = dados['id'];
          _nomePetshopSelecionado = dados['nomeFantasia'];
        });
        // ✅ SEM NENHUMA MENSAGEM QUANDO ENCONTRA
      } else {
        // ❌ SÓ AVISA SE NÃO ENCONTRAR
        if (!mounted) return; // ← ✅ ADICIONA ESTA LINHA
        setState(() {
          _nomePetshopSelecionado = null;
          _idPetshopSelecionado = null;
          _codigoPetshopController.text = '';
        });
        _mensagem(
          '⚠️ PetShop não encontrado! Verifique o código ou busque pelo nome.',
          Colors.orange,
        );
      }
    } catch (e) {
      if (!mounted) return; // ← COLOCA ESSA LINHA ABAIXO DO {
      setState(() {
        _nomePetshopSelecionado = null;
        _idPetshopSelecionado = null;
        _codigoPetshopController.text = '';
      });
      _mensagem('⚠️ Erro ao buscar', Colors.red);
    }
  }

  // ✅ 2 — ABRE LISTA PARA BUSCAR PELO NOME
  Future<void> _abrirListaPetshops() async {
    List<dynamic> listaPetshops = [];
    try {
      final resposta = await http.get(Uri.parse('$apiBase/petshops'));
      if (resposta.statusCode == 200) {
        listaPetshops = json.decode(resposta.body);
      } else {
        _mensagem('❌ Não foi possível carregar os petshops', Colors.red);
        return;
      }
    } catch (e) {
      _mensagem('❌ Erro de conexão', Colors.red);
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        String filtro = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtrados = listaPetshops.where((ps) {
              final nome = (ps['nomeFantasia'] ?? '').toString().toLowerCase();
              return nome.contains(filtro.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text('Selecionar Petshop'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '🔍 Buscar pelo nome',
                      ),
                      onChanged: (valor) =>
                          setDialogState(() => filtro = valor),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtrados.isEmpty
                          ? const Text('Nenhum petshop encontrado')
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtrados.length,
                              itemBuilder: (context, i) {
                                final ps = filtrados[i];
                                final nome = ps['nomeFantasia'] ?? '';
                                final cidade = ps['cidade'] ?? '';
                                final bairro = ps['bairro'] ?? '';
                                final endereco = ps['endereco'] ?? '';
                                String linhaEndereco = '';
                                if (cidade.isNotEmpty && bairro.isNotEmpty) {
                                  linhaEndereco = '$cidade — $bairro';
                                } else if (cidade.isNotEmpty) {
                                  linhaEndereco = cidade;
                                } else if (endereco.isNotEmpty) {
                                  linhaEndereco = endereco;
                                } else {
                                  linhaEndereco = 'Sem endereço';
                                }
                                return ListTile(
                                  title: Text(
                                    nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    linhaEndereco,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () {
                                    if (!mounted) return; // ← COLOCA ESTA LINHA
                                    setState(() {
                                      _idPetshopSelecionado = ps['id'];
                                      _codigoPetshopController.text = ps['id']
                                          .toString();
                                      _nomePetshopSelecionado = nome;
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _salvar() async {
    if (_especieSelecionadaId == null) {
      _mensagem('❌ Selecione a espécie', Colors.red);
      return;
    }
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      _mensagem('❌ Nome é obrigatório', Colors.red);
      return;
    }
    if (_nascimentoController.text.isEmpty && _dataNascimento == null) {
      _mensagem('❌ Informe a data de nascimento ou a idade', Colors.red);
      return;
    }
    if (_racaSelecionadaId == null) {
      _mensagem('❌ Selecione a raça', Colors.red);
      return;
    }
    if (_sexo.isEmpty) {
      _mensagem('❌ Selecione o sexo', Colors.red);
      return;
    }
    if (!mounted) return;
    setState(() => _carregando = true);

    try {
      _urlFoto = await _enviarFoto();

      String? dataNascimentoStr;
      if (_dataNascimento != null) {
        dataNascimentoStr =
            "${_dataNascimento!.year}-${_dataNascimento!.month.toString().padLeft(2, '0')}-${_dataNascimento!.day.toString().padLeft(2, '0')}";
      }

      final dados = {
        "idEspecie": _especieSelecionadaId,
        "nome": nome,
        "nascimento": dataNascimentoStr,
        "idRaca": _racaSelecionadaId,
        "sexo": _sexo,
        "castrado": _castrado,
        "falecido": _falecido,
        "foto": _urlFoto,
        "observacoes": _observacoesController.text.trim(),
        "idTutor": widget.idTutor,
        "idPetshop": _idPetshopSelecionado, // ✅ SALVA O ID DO PETSHOP
      };

      final resposta;
      if (_idPet != null) {
        resposta = await http.put(
          Uri.parse('$apiBase/pets/$_idPet'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(dados),
        );
      } else {
        resposta = await http.post(
          Uri.parse('$apiBase/pets'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(dados),
        );
      }

      if ((_idPet == null && resposta.statusCode == 201) ||
          (_idPet != null && resposta.statusCode == 200)) {
        _mensagem(
          _idPet == null
              ? '✅ Pet cadastrado com sucesso!'
              : '✅ Pet atualizado!',
          const Color(0xFF512DA8),
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        final corpo = json.decode(resposta.body);
        _mensagem(corpo['erro'] ?? '❌ Erro', Colors.red);
      }
    } catch (e) {
      _mensagem('⚠️ Erro de conexão: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _confirmarExclusao() async {
    final bool? confirma = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Excluir Pet'),
        content: const Text(
          'Tem certeza que deseja excluir este Pet?\nEsta ação NÃO pode ser desfeita e todos\n os dados do Pet serão excluídos definitivamente!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirma == true) {
      if (!mounted) return;
      setState(() => _carregando = true);
      try {
        final resposta = await http.delete(
          Uri.parse('$apiBase/pets/$_idPet'),
          headers: {'Content-Type': 'application/json'},
        );
        if (resposta.statusCode == 200 || resposta.statusCode == 204) {
          _mensagem('✅ Pet excluído com sucesso!', const Color(0xFF512DA8));
          if (mounted) Navigator.pop(context, true);
        } else {
          _mensagem('❌ Não foi possível excluir', Colors.red);
        }
      } catch (e) {
        _mensagem('⚠️ Erro de conexão', Colors.red);
      } finally {
        if (mounted) setState(() => _carregando = false);
      }
    }
  }

  void _mensagem(String texto, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: cor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _selecionarRaca() async {
    await showDialog(
      context: context,
      builder: (context) {
        String filtro = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtradas = _listaRacas.where((raca) {
              final nome = raca['nome'].toString().toLowerCase();
              return nome.contains(filtro.toLowerCase());
            }).toList();
            return AlertDialog(
              title: const Text('Selecionar Raça'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '🔍 Buscar raça',
                      ),
                      onChanged: (valor) =>
                          setDialogState(() => filtro = valor),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _carregandoRacas
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtradas.length,
                              itemBuilder: (context, i) {
                                final raca = filtradas[i];
                                return ListTile(
                                  title: Text(raca['nome']),
                                  onTap: () {
                                    setState(() {
                                      _racaSelecionadaId = raca['id'];
                                      _racaSelecionadaNome = raca['nome'];
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(_idPet == null ? 'Cadastrar Pet' : 'Editar Pet'),
            ),
            // ✅ STATUS ATIVO/INATIVO DIRETO NO CABEÇALHO
            TextButton(
              onPressed: () => setState(() => _falecido = !_falecido),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                children: [
                  Icon(
                    _falecido ? Icons.cancel : Icons.check_circle,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _falecido ? 'Inativo' : 'Ativo',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF512DA8),
        foregroundColor: Colors.white,
        actions: [
          if (_idPet != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Excluir Pet',
              onPressed: _confirmarExclusao,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ======================================
            // 📸 TOPO: FOTO CLICÁVEL + NOME EM NEGRITO
            // ======================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                InkWell(
                  onTap: _escolherFoto,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _arquivoFoto != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_arquivoFoto!, fit: BoxFit.cover),
                          )
                        : (_urlFoto != null && _urlFoto!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _urlFoto!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, erro, stackTrace) =>
                                  const Icon(
                                    Icons.add_a_photo,
                                    size: 28,
                                    color: Colors.grey,
                                  ),
                            ),
                          )
                        : const Icon(
                            Icons.add_a_photo,
                            size: 28,
                            color: Colors.grey,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Pet *',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚàâãÀÂÃçÇ ]'),
                      ),
                      UpperCaseTextFormatter(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ======================================
            // 🐾 ESPÉCIE
            // ======================================
            InkWell(
              onTap: _carregandoEspecies ? null : _selecionarEspecie,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Espécie *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.search),
                ),
                child: Text(_especieSelecionadaNome ?? 'Toque para selecionar'),
              ),
            ),
            const SizedBox(height: 16),

            // ======================================
            // 🐶 RAÇA
            // ======================================
            InkWell(
              onTap: _carregandoRacas ? null : _selecionarRaca,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Raça *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.search),
                ),
                child: Text(_racaSelecionadaNome ?? 'Toque para selecionar'),
              ),
            ),
            const SizedBox(height: 16),

            // ======================================
            // 📅 DATA DE NASCIMENTO
            // ======================================
            TextField(
              controller: _nascimentoController,
              decoration: const InputDecoration(
                labelText: 'Data de Nascimento',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                DateTime? escolhida = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (escolhida != null) {
                  setState(() {
                    _dataNascimento = escolhida;
                    _nascimentoController.text =
                        "${escolhida.day.toString().padLeft(2, '0')}/${escolhida.month.toString().padLeft(2, '0')}/${escolhida.year}";
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // ======================================
            // 📦 IDADE
            // ======================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calcular data de nascimento pela idade aproximada:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _anosController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Anos',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _mesesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Meses',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _calcularNascimento,
                        icon: const Icon(Icons.calculate),
                        label: const Text('Calcular'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF512DA8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ======================================
            // ♂️ SEXO
            // ======================================
            const Text('Sexo *', style: TextStyle(fontWeight: FontWeight.w500)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Macho'),
                    value: 'Macho',
                    groupValue: _sexo,
                    onChanged: (v) => setState(() => _sexo = v ?? ''),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Fêmea'),
                    value: 'Fêmea',
                    groupValue: _sexo,
                    onChanged: (v) => setState(() => _sexo = v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ======================================
            // ✅ CASTRADO
            // ======================================
            SwitchListTile(
              title: Text(_castrado ? 'Castrado' : 'Não Castrado'),
              value: _castrado,
              onChanged: (valor) => setState(() => _castrado = valor),
              activeColor: const Color(0xFF512DA8),
              inactiveThumbColor: Colors.grey,
            ),
            const SizedBox(height: 20),

            // ======================================
            // 🏪 PETSHOP FAVORITO — UM SÓ CAMPO + LUPA 🔍
            // ======================================
            // ======================================
            // 🏪 PETSHOP FAVORITO — UM SÓ CAMPO + LUPA 🔍
            // ======================================
            InkWell(
              onTap: _abrirListaPetshops,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'PetShop Favorito',
                  hintText:
                      _nomePetshopSelecionado ??
                      'Digite o código ou toque para buscar',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      final codigo = _codigoPetshopController.text.trim();

                      if (_nomePetshopSelecionado != null || codigo.isEmpty) {
                        // ✅ JÁ TEM NOME SELECIONADO OU CAMPO VAZIO → ABRE LISTA
                        _abrirListaPetshops();
                      } else {
                        // ✅ TEM CÓDIGO DIGITADO E SEM NOME → BUSCA DIRETO
                        _buscarPetshopPorCodigo(codigo);
                      }
                    },
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                child: _nomePetshopSelecionado != null
                    ? Text(
                        '${_codigoPetshopController.text} — $_nomePetshopSelecionado',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      )
                    : SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _codigoPetshopController,
                          decoration: const InputDecoration(
                            hintText: '000',
                            border: InputBorder.none,
                            counterText: '',
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ======================================
            // 📝 OBSERVAÇÕES
            // ======================================
            TextField(
              controller: _observacoesController,
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
            ),
            const SizedBox(height: 32),

            // ======================================
            // 💾 BOTÃO SALVAR
            // ======================================
            ElevatedButton(
              onPressed: _carregando ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF512DA8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 60),
              ),
              child: _carregando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SALVAR PET', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
