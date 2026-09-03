import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/constantes.dart';
import 'package:flutter/services.dart';

class TelaCadastroPet extends StatefulWidget {
  final dynamic idTutor;
  final dynamic pet; // ✅ NOVO — recebe os dados para edição

  const TelaCadastroPet({
    super.key,
    required this.idTutor,
    this.pet, // ✅ OPCIONAL — se vier = edição, se não = cadastro
  });

  @override
  State<TelaCadastroPet> createState() => _TelaCadastroPetState();
}

class _TelaCadastroPetState extends State<TelaCadastroPet> {
  // 📝 Controladores
  final _nomeController = TextEditingController();
  final _nascimentoController = TextEditingController();
  final _anosController = TextEditingController();
  final _mesesController = TextEditingController();
  final _observacoesController = TextEditingController();

  // 📦 Dados
  String? _urlFoto;
  DateTime? _dataNascimento;
  List<dynamic> _listaRacas = [];
  String? _racaSelecionadaNome;
  dynamic _racaSelecionadaId;
  String _sexo = '';
  bool _castrado = false; // ☐ Desmarcado por padrão
  bool _falecido = false;
  bool _carregando = false;
  bool _carregandoRacas = true;

  // ✅ ==== ESPÉCIE ====
  List<dynamic> _listaEspecies = [];
  String? _especieSelecionadaNome;
  dynamic _especieSelecionadaId;
  bool _carregandoEspecies = true;
  dynamic _idPet; // ✅ GUARDA O ID QUANDO FOR EDIÇÃO

  // 🖼️ Imagem
  final ImagePicker _imagePicker = ImagePicker();
  File? _arquivoFoto;

  @override
  void initState() {
    super.initState();
    _carregarRacas();
    _carregarEspecies(); // ✅ ==== NOVA LINHA ====

    // ✅ SE VIER DADOS DO PET → PREENCHE OS CAMPOS
    if (widget.pet != null) {
      _preencherDadosParaEdicao();
    }
  }

  // ✅ PREENCHE TODOS OS CAMPOS PARA EDIÇÃO
  void _preencherDadosParaEdicao() {
    final pet = widget.pet;
    debugPrint(
      '🔍 ID Espécie do Pet: ${pet['idEspecie']}',
    ); // ✅ MOSTRA O ID NO CONSOLE
    _idPet = pet['id']; // ✅ GUARDA O ID PARA SABER QUE É EDIÇÃO

    // Nome
    _nomeController.text = pet['nome']?.toString() ?? '';

    // Nascimento
    if (pet['nascimento'] != null && pet['nascimento'].toString().isNotEmpty) {
      _dataNascimento = DateTime.parse(pet['nascimento'].toString());
      _nascimentoController.text =
          "${_dataNascimento!.day}/${_dataNascimento!.month}/${_dataNascimento!.year}";
    }

    // Raça
    if (pet['idRaca'] != null) {
      _racaSelecionadaId = pet['idRaca'];
      // Nome da raça vai aparecer quando carregar a lista
    }

    // Sexo
    _sexo = pet['sexo']?.toString() ?? '';

    // Castrado
    _castrado = pet['castrado'] == true;

    // Falecido
    _falecido = pet['falecido'] == true;

    // Foto
    // ✅ FOTO — CORRIGIDO
    final String? fotoUrl = pet['foto']?.toString();
    if (fotoUrl != null && fotoUrl.isNotEmpty) {
      _urlFoto = fotoUrl;
      debugPrint('✅ FOTO CARREGADA: $_urlFoto'); // ✅ MOSTRA NO CONSOLE
    } else {
      _urlFoto = null;
      debugPrint('⚠️ SEM FOTO: campo veio vazio ou nulo');
    }

    // Observações
    _observacoesController.text = pet['observacoes']?.toString() ?? '';
  }

  // ✅ Buscar lista de Raças na API
  Future<void> _carregarRacas() async {
    try {
      final resposta = await http.get(Uri.parse('$apiBase/racas'));
      if (resposta.statusCode == 200) {
        setState(() {
          _listaRacas = json.decode(resposta.body);
          _carregandoRacas = false;
        });
      }
    } catch (e) {
      setState(() => _carregandoRacas = false);
      _mensagem('⚠️ Erro ao carregar raças', Colors.orange);
    }
  }

  // ✅ ==== BUSCAR LISTA DE ESPÉCIES ====
  Future<void> _carregarEspecies() async {
    try {
      final resposta = await http.get(Uri.parse('$apiBase/especies'));
      if (resposta.statusCode == 200) {
        _listaEspecies = json.decode(resposta.body);

        // ✅ SE ESTIVERMOS EDITANDO → BUSCA A ESPÉCIE
        if (widget.pet != null) {
          final idEspeciePet = widget.pet['idEspecie'];
          debugPrint(
            '🔍 ID Espécie do Pet: $idEspeciePet',
          ); // ✅ MOSTRA NO CONSOLE

          if (idEspeciePet != null) {
            for (var e in _listaEspecies) {
              if (e['id'] == idEspeciePet) {
                _especieSelecionadaId = e['id'];
                _especieSelecionadaNome =
                    e['nomeEspecie']?.toString() ?? e['nome']?.toString();
                debugPrint(
                  '✅ Espécie encontrada: $_especieSelecionadaNome',
                ); // ✅ MOSTRA NO CONSOLE
                break;
              }
            }
          }
        }

        setState(() {
          _carregandoEspecies = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar espécies: $e');
      setState(() => _carregandoEspecies = false);
    }
  }

  // ✅ ==== SELECIONAR ESPÉCIE COM BUSCA ====
  void _selecionarEspecie() async {
    await showDialog(
      context: context,
      builder: (context) {
        String filtro = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtradas = _listaEspecies.where((especie) {
              final nome = especie['nomeEspecie'].toString().toLowerCase();
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
                                  title: Text(especie['nomeEspecie']),
                                  onTap: () {
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

  // ✅ Calcular Data a partir de Anos e Meses
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

  // ✅ Escolher Foto
  Future<void> _escolherFoto() async {
    try {
      final XFile? selecionada = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75, // ✅ Reduz qualidade para 75% — leve e boa!
        maxWidth: 1024, // ✅ Largura máxima de 1024 pixels
        maxHeight: 1024, // ✅ Altura máxima de 1024 pixels
      );
      if (selecionada != null) {
        setState(() => _arquivoFoto = File(selecionada.path));
      }
    } catch (e) {
      _mensagem('❌ Erro ao escolher foto', Colors.red);
    }
  }

  // ✅ Enviar Foto para Cloudinary pela API
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

  // ✅ Salvar Pet
  Future<void> _salvar() async {
    // Validações
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

    setState(() => _carregando = true);

    try {
      // Envia foto primeiro (se houver)
      _urlFoto = await _enviarFoto();

      // Prepara a data
      String? dataNascimentoStr;
      if (_dataNascimento != null) {
        dataNascimentoStr =
            "${_dataNascimento!.year}-${_dataNascimento!.month.toString().padLeft(2, '0')}-${_dataNascimento!.day.toString().padLeft(2, '0')}";
      }

      // Envia os dados do Pet
      final dados = {
        "idEspecie": _especieSelecionadaId, // ✅ ==== NOVA LINHA ====
        "nome": nome,
        "nascimento": dataNascimentoStr,
        "idRaca": _racaSelecionadaId,
        "sexo": _sexo,
        "castrado": _castrado,
        "falecido": _falecido,
        "foto": _urlFoto,
        "observacoes": _observacoesController.text.trim(),
        "idTutor": widget.idTutor,
      };

      // ✅ SE TEM ID = EDIÇÃO | SE NÃO TEM = CADASTRO NOVO
      final resposta;
      if (_idPet != null) {
        // ✅ MODO EDIÇÃO → ATUALIZA
        resposta = await http.put(
          Uri.parse('$apiBase/pets/$_idPet'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(dados),
        );
      } else {
        // ✅ MODO CADASTRO → NOVO
        resposta = await http.post(
          Uri.parse('$apiBase/pets'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(dados),
        );
      }

      // ✅ ACEITA 201 (novo) E 200 (edição)
      if ((_idPet == null && resposta.statusCode == 201) ||
          (_idPet != null && resposta.statusCode == 200)) {
        _mensagem(
          _idPet == null
              ? '✅ Pet cadastrado com sucesso!'
              : '✅ Pet atualizado!',
          const Color(0xFF512DA8),
        );
        Navigator.pop(context, true);
      } else {
        final corpo = json.decode(resposta.body);
        _mensagem(corpo['erro'] ?? '❌ Erro', Colors.red);
      }
    } catch (e) {
      _mensagem('⚠️ Erro de conexão: $e', Colors.red);
    } finally {
      setState(() => _carregando = false);
    }
  }

  // ✅ ==== EXCLUIR PET ====
  Future<void> _confirmarExclusao() async {
    // 🚨 CAIXA DE CONFIRMAÇÃO
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

    // ✅ SE CONFIRMOU → EXCLUI
    if (confirma == true) {
      setState(() => _carregando = true);
      try {
        final resposta = await http.delete(
          Uri.parse('$apiBase/pets/$_idPet'),
          headers: {'Content-Type': 'application/json'},
        );

        if (resposta.statusCode == 200 || resposta.statusCode == 204) {
          _mensagem('✅ Pet excluído com sucesso!', const Color(0xFF512DA8));
          // ✅ VOLTA PARA A LISTA E ATUALIZA
          Navigator.pop(context, true);
        } else {
          _mensagem('❌ Não foi possível excluir', Colors.red);
        }
      } catch (e) {
        _mensagem('⚠️ Erro de conexão', Colors.red);
      } finally {
        setState(() => _carregando = false);
      }
    }
  }

  // ✅ Mensagem
  void _mensagem(String texto, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: cor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ✅ Selecionar Raça com Busca
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
        title: Text(_idPet == null ? 'Cadastrar Pet' : 'Editar Pet'),
        backgroundColor: const Color(0xFF512DA8),
        foregroundColor: Colors.white,
        // ✅ ==== AÇÕES NO CANTO DIREITO ====
        actions: [
          // ✅ SÓ MOSTRA O ÍCONE EXCLUIR QUANDO FOR EDIÇÃO
          if (_idPet != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Excluir Pet',
              onPressed: _confirmarExclusao, // ✅ ==== PRECISA ESTÁ ASSIM! ====
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🐾 ESPÉCIE *
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

            // 📝 NOME
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Pet *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚàâãÀÂÃçÇ ]'),
                ),
                UpperCaseTextFormatter(), // ✅ FORÇA MAIÚSCULAS
              ],
            ),
            const SizedBox(height: 16),

            // 📅 DATA DE NASCIMENTO
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
                  _dataNascimento = escolhida;
                  _nascimentoController.text =
                      "${escolhida.day.toString().padLeft(2, '0')}/${escolhida.month.toString().padLeft(2, '0')}/${escolhida.year}";
                }
              },
            ),
            const SizedBox(height: 12),

            // 🔢 CALCULAR IDADE
            const Text(
              'Ou calcular pela idade:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _anosController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Anos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _mesesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Meses'),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 🐶 RAÇA COM BUSCA
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

            // ♂️ SEXO
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

            // ✅ CASTRADO
            // ✅ CASTRADO — Switch Liga/Desliza
            SwitchListTile(
              title: Text(_castrado ? 'Castrado' : 'Não Castrado'),
              value: _castrado,
              onChanged: (valor) => setState(() => _castrado = valor),
              activeColor: const Color(0xFF512DA8), // 💜 Roxo quando LIGADO
              inactiveThumbColor: Colors.grey,
            ),

            // ✅ SITUAÇÃO — Cadastro Ativo / Inativo
            // ✅ SITUAÇÃO — Ativo / Inativo
            SwitchListTile(
              title: Text(!_falecido ? 'Cadastro Ativo' : 'Cadastro Inativo'),
              value: !_falecido, // ✅ Ligado = Ativo
              onChanged: (valor) => setState(() => _falecido = !valor),
              activeColor: const Color(0xFF512DA8), // 💜 Roxo quando LIGADO
              inactiveThumbColor: Colors.grey,
            ),
            const SizedBox(height: 16),

            // 🖼️ FOTO
            InkWell(
              onTap: _escolherFoto,
              child: Container(
                height: 150,
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
                          errorBuilder: (context, erro, stackTrace) {
                            debugPrint('❌ ERRO AO CARREGAR FOTO: $erro');
                            return const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Foto indisponível',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Toque para adicionar foto',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 📝 OBSERVAÇÕES
            TextField(
              controller: _observacoesController,
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                UpperCaseTextFormatter(), // ✅ JÁ ESTÁ PRONTA! Reutiliza a mesma classe!
              ],
            ),
            const SizedBox(height: 24),

            // 💾 BOTÃO SALVAR
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: ElevatedButton(
                onPressed: _carregando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF512DA8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SALVAR PET', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ ===== COLOQUE A CLASSE ABAIXO, NO FIM DO ARQUIVO, FORA DE TUDO! =====

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
