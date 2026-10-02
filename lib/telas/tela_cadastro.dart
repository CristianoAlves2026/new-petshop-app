import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constantes.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class TelaCadastro extends StatefulWidget {
  final Map<String, dynamic>? dadosTutor; // ✅ NOVO
  const TelaCadastro({super.key, this.dadosTutor});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  // 📝 Controladores dos campos
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _bairroController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmaSenhaController = TextEditingController();

  // 👁️ Mostrar/Ocultar senha
  bool _senhaVisivel = false;
  bool _confirmaSenhaVisivel = false;
  String? _codigoCorreto;
  String _codigoDigitado = '';
  bool _mostrarCampoCodigo = false;

  // 📋 Listas para os combos
  List<String> _listaEstados = [];
  List<dynamic> _listaMunicipios = [];
  String? _estadoSelecionado;
  dynamic _municipioSelecionado;

  bool _carregando = false;
  bool _carregandoEstados = true;

  // ──────────────────────────────────────
  // 🎭 MÁSCARAS
  // ──────────────────────────────────────

  String _mascaraCpf(String valor) {
    String num = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (num.length > 11) num = num.substring(0, 11);
    if (num.length <= 3) return num;
    if (num.length <= 6) return '${num.substring(0, 3)}.${num.substring(3)}';
    if (num.length <= 9)
      return '${num.substring(0, 3)}.${num.substring(3, 6)}.${num.substring(6)}';
    return '${num.substring(0, 3)}.${num.substring(3, 6)}.${num.substring(6, 9)}-${num.substring(9, num.length)}';
  }

  // ✅ MÁSCARA ATUALIZADA → EXEMPLO: (28) 99999-9999
  String _mascaraTelefone(String valor) {
    String num = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (num.length > 11) num = num.substring(0, 11);
    if (num.length <= 2) return num;
    if (num.length <= 7) return '(${num.substring(0, 2)}) ${num.substring(2)}';
    return '(${num.substring(0, 2)}) ${num.substring(2, 7)}-${num.substring(7, num.length)}';
  }

  String _limpar(String valor) => valor.replaceAll(RegExp(r'[^0-9]'), '');

  // ──────────────────────────────────────
  // ✅ VALIDAÇÃO DE CPF
  // ──────────────────────────────────────

  bool _validarCpf(String cpf) {
    if (cpf.length != 11) return false;
    if (cpf.split('').every((c) => c == cpf[0])) return false;

    int soma1 = 0;
    for (int i = 0; i < 9; i++) soma1 += int.parse(cpf[i]) * (10 - i);
    int d1 = 11 - (soma1 % 11);
    d1 = d1 >= 10 ? 0 : d1;
    if (d1 != int.parse(cpf[9])) return false;

    int soma2 = 0;
    for (int i = 0; i < 10; i++) soma2 += int.parse(cpf[i]) * (11 - i);
    int d2 = 11 - (soma2 % 11);
    d2 = d2 >= 10 ? 0 : d2;
    if (d2 != int.parse(cpf[10])) return false;

    return true;
  }

  // ──────────────────────────────────────
  // ✅ VALIDAÇÃO DE E-MAIL
  // ──────────────────────────────────────

  bool _validarEmail(String email) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return regex.hasMatch(email);
  }

  // ──────────────────────────────────────
  // 🔄 CARREGAR ESTADOS E MUNICÍPIOS
  // ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // ✅ PRIMEIRO carrega os estados...
    _carregarEstados().then((_) {
      // ✅ ...SÓ DEPOIS preenche os dados
      if (widget.dadosTutor != null) {
        final t = widget.dadosTutor!;
        setState(() {
          _nomeController.text = (t['nome'] ?? '').toString().toUpperCase();
          _cpfController.text = _mascaraCpf(t['cpf']?.toString() ?? '');
          _telefoneController.text = _mascaraTelefone(
            t['telefone']?.toString() ?? '',
          );
          _emailController.text = (t['email'] ?? '').toString().toLowerCase();
          _bairroController.text = (t['bairro'] ?? '').toString().toUpperCase();
          _estadoSelecionado = t['estado'];
        });

        // ✅ Se tem estado → carrega municípios e seleciona
        if (_estadoSelecionado != null) {
          _carregarMunicipios(_estadoSelecionado!).then((_) {
            setState(() {
              final idProcurado = t['idMunicipio'];

              _municipioSelecionado = _listaMunicipios.firstWhere(
                (m) {
                  final idMun = m['id'] ?? m['idCidade'] ?? m['id_municipio'];
                  return idMun == idProcurado;
                },
                orElse: () {
                  return null;
                },
              );
            });
          });
        }
      }
    });
  }

  Future<void> _carregarEstados() async {
    // ✅ mudei de void → Future<void>
    try {
      final res = await http.get(Uri.parse('$apiBase/estados'));
      if (res.statusCode == 200) {
        setState(() {
          _listaEstados = List<String>.from(json.decode(res.body));
        });
      }
    } catch (e) {
      _mensagem('⚠️ Não foi possível carregar os estados', Colors.orange);
    } finally {
      setState(() => _carregandoEstados = false);
    }
  }

  Future<void> _carregarMunicipios(String estado) async {
    setState(() {
      _listaMunicipios = [];
      _municipioSelecionado = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$apiBase/municipios?estado=$estado'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        setState(() {
          _listaMunicipios = List<dynamic>.from(json.decode(res.body));
        });
      }
    } catch (e) {
      _mensagem('⚠️ Erro ao carregar municípios', Colors.orange);
    }
  }

  // ──────────────────────────────────────
  // 🚀 ENVIAR CADASTRO
  // ──────────────────────────────────────

  Future<void> _cadastrar() async {
    // ✅ Se o campo está visível e EM BRANCO → gera código NOVO
    if (_mostrarCampoCodigo && _codigoDigitado.isEmpty) {
      setState(() {
        _codigoCorreto = null;
      });
      // Segue abaixo para gerar e enviar código novo
    }
    // ✅ Se o campo está visível e PREENCHIDO → confirma
    else if (_mostrarCampoCodigo) {
      if (_codigoDigitado == _codigoCorreto) {
        await _executarCadastroReal();
      } else {
        _mensagem(
          '❌ Código não confere. Digite codigo correto ou apague e clique Salvar para gerar um novo codigo.',
          Colors.red,
        );
      }
      return;
    }

    // ✅ PASSO B — Primeiro clique → VALIDAÇÕES NORMAIS
    final nome = _nomeController.text.trim().toUpperCase();
    final cpf = _limpar(_cpfController.text);
    final telefone = _limpar(_telefoneController.text);
    final email = _emailController.text.trim().toLowerCase();
    final bairro = _bairroController.text.trim().toUpperCase();
    final senha = _senhaController.text.trim();
    final confirmaSenha = _confirmaSenhaController.text.trim();
    final bool ehCadastroNovo = widget.dadosTutor == null;

    // ✅ Validações — IGUAIS AO SEU
    if (nome.isEmpty) return _mensagem('❌ Nome é obrigatório', Colors.red);
    if (cpf.isEmpty) return _mensagem('❌ CPF é obrigatório', Colors.red);
    if (!_validarCpf(cpf))
      return _mensagem('❌ CPF inválido! Verifique os dígitos', Colors.red);
    if (telefone.isEmpty)
      return _mensagem('❌ Telefone é obrigatório', Colors.red);
    if (telefone.length != 11)
      return _mensagem('❌ Telefone precisa ter 11 dígitos com DDD', Colors.red);
    if (telefone[2] != '9')
      return _mensagem('❌ Telefone deve começar com dígito 9', Colors.red);
    if (email.isEmpty) return _mensagem('❌ E-mail é obrigatório', Colors.red);
    if (!_validarEmail(email))
      return _mensagem('❌ Formato de e-mail inválido', Colors.red);
    if (_estadoSelecionado == null)
      return _mensagem('❌ Selecione um Estado', Colors.red);
    if (_municipioSelecionado == null)
      return _mensagem('❌ Selecione um Município', Colors.red);
    if (bairro.isEmpty) return _mensagem('❌ Bairro é obrigatório', Colors.red);

    if (ehCadastroNovo) {
      if (senha.isEmpty) return _mensagem('❌ Senha é obrigatória', Colors.red);
      if (senha != confirmaSenha)
        return _mensagem('❌ As senhas não coincidem', Colors.red);
    } else {
      if (senha.isNotEmpty && senha != confirmaSenha)
        return _mensagem('❌ As senhas não coincidem', Colors.red);
    }

    // ✅ Se é EDIÇÃO → pula código, salva direto
    if (!ehCadastroNovo) {
      await _executarCadastroReal();
      return;
    }

    // ✅ É CADASTRO NOVO → GERA E ENVIA CÓDIGO
    // ✅ PEGA O TOKEN FCM AGORA MESMO
    // ✅ É CADASTRO NOVO → GERA E ENVIA CÓDIGO
    setState(() => _carregando = true);
    try {
      // ✅ ENVIA SEM O TOKEN — SÓ TELEFONE E E-MAIL
      final respostaCod = await http
          .post(
            Uri.parse('$apiBase/enviar-codigo'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'telefone': telefone,
              'email': _emailController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (respostaCod.statusCode == 200) {
        final dados = json.decode(respostaCod.body);
        setState(() {
          _codigoCorreto = dados['codigo'];
          _mostrarCampoCodigo = true;
        });
        _mensagem('✅ Código enviado! Verifique seu e-mail.', Colors.green);
      } else if (respostaCod.statusCode == 400) {
        final erro = json.decode(respostaCod.body);
        _mensagem('❌ ${erro['erro']}', Colors.red); // ✅ Mostra o erro da API
      } else {
        _mensagem('❌ Erro ao enviar código', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      _mensagem('❌ Erro de conexão', Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _executarCadastroReal() async {
    final nome = _nomeController.text.trim().toUpperCase();
    final cpf = _limpar(_cpfController.text);
    final telefone = _limpar(_telefoneController.text);
    final email = _emailController.text.trim().toLowerCase();
    final bairro = _bairroController.text.trim().toUpperCase();
    final senha = _senhaController.text.trim();
    final confirmaSenha = _confirmaSenhaController.text.trim();
    final bool ehCadastroNovo = widget.dadosTutor == null;

    setState(() => _carregando = true);
    try {
      final Map<String, dynamic> dadosEnvio = {
        'nome': nome,
        'cpf': cpf,
        'telefone': telefone,
        'email': email,
        'idMunicipio': _municipioSelecionado['id'],
        'bairro': bairro,
        'estado': _estadoSelecionado,
        'idPetshop': null,
      };
      if (senha.isNotEmpty) {
        dadosEnvio['senha'] = senha;
      }

      final resposta;
      if (ehCadastroNovo) {
        resposta = await http
            .post(
              Uri.parse('$apiBase/tutores'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(dadosEnvio),
            )
            .timeout(const Duration(seconds: 15));
      } else {
        final idEditar = widget.dadosTutor!['id'];
        resposta = await http
            .put(
              Uri.parse('$apiBase/tutores/$idEditar'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(dadosEnvio),
            )
            .timeout(const Duration(seconds: 15));
      }

      if (!mounted) return;

      if ((ehCadastroNovo && resposta.statusCode == 201) ||
          (!ehCadastroNovo && resposta.statusCode == 200)) {
        _mensagem(
          ehCadastroNovo
              ? '✅ Cadastro realizado com sucesso!'
              : '✅ Dados atualizados!',
          Colors.green,
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        _mensagem(resposta.body, Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      _mensagem('❌ Erro de conexão', Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mensagem(String texto, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto, style: const TextStyle(fontSize: 16)),
        backgroundColor: cor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ──────────────────────────────────────
  // 🎨 INTERFACE
  // ──────────────────────────────────────

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
                  // ✅ SETA DE VOLTAR
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
                    'Cadastro de Usuario',
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

          // 🔹 FORMULÁRIO
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // ✅ NOME → SÓ MAIÚSCULAS EM TEMPO REAL
                  TextField(
                    controller: _nomeController,
                    decoration: _dec('Nome', Icons.badge),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (v) {
                      final maiusculo = v.toUpperCase();
                      if (maiusculo != v) {
                        _nomeController.value = TextEditingValue(
                          text: maiusculo,
                          selection: TextSelection.collapsed(
                            offset: maiusculo.length,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // CPF
                  TextField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    decoration: _dec(
                      'CPF',
                      Icons.badge,
                      hint: '123.456.789-09',
                    ),
                    onChanged: (v) {
                      final m = _mascaraCpf(v);
                      if (m != v)
                        _cpfController.value = TextEditingValue(
                          text: m,
                          selection: TextSelection.collapsed(offset: m.length),
                        );
                    },
                  ),
                  const SizedBox(height: 14),

                  // ✅ TELEFONE → EXEMPLO ATUALIZADO
                  TextField(
                    controller: _telefoneController,
                    keyboardType: TextInputType.number,
                    decoration: _dec(
                      'Telefone',
                      Icons.phone,
                      hint: '(28) 99999-9999',
                    ),
                    onChanged: (v) {
                      final m = _mascaraTelefone(v);
                      if (m != v)
                        _telefoneController.value = TextEditingValue(
                          text: m,
                          selection: TextSelection.collapsed(offset: m.length),
                        );
                    },
                  ),
                  const SizedBox(height: 14),

                  // E-MAIL
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec('E-mail', Icons.email),
                    onChanged: (v) {
                      final minusculo = v.toLowerCase();
                      if (minusculo != v) {
                        _emailController.value = TextEditingValue(
                          text: minusculo,
                          selection: TextSelection.collapsed(
                            offset: minusculo.length,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // ESTADO
                  _carregandoEstados
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: _estadoSelecionado,
                          decoration: _dec('Estado', Icons.map),
                          items: _listaEstados
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (e) {
                            setState(() => _estadoSelecionado = e);
                            if (e != null) _carregarMunicipios(e);
                          },
                        ),
                  const SizedBox(height: 14),

                  // MUNICÍPIO
                  DropdownButtonFormField<dynamic>(
                    value: _municipioSelecionado,
                    decoration: _dec('Município', Icons.location_city),
                    items: _listaMunicipios
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m['nome']),
                          ),
                        )
                        .toList(),
                    onChanged: _listaMunicipios.isEmpty
                        ? null
                        : (m) => setState(() => _municipioSelecionado = m),
                  ),
                  const SizedBox(height: 14),

                  // ✅ BAIRRO → SÓ MAIÚSCULAS EM TEMPO REAL
                  TextField(
                    controller: _bairroController,
                    decoration: _dec('Bairro', Icons.home),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (v) {
                      final maiusculo = v.toUpperCase();
                      if (maiusculo != v) {
                        _bairroController.value = TextEditingValue(
                          text: maiusculo,
                          selection: TextSelection.collapsed(
                            offset: maiusculo.length,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // SENHA
                  TextField(
                    controller: _senhaController,
                    enabled: widget.dadosTutor == null, //
                    obscureText: !_senhaVisivel,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _senhaVisivel
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() => _senhaVisivel = !_senhaVisivel);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // CONFIRMAR SENHA
                  TextField(
                    controller: _confirmaSenhaController,
                    enabled: widget.dadosTutor == null,
                    obscureText: !_confirmaSenhaVisivel,
                    decoration: InputDecoration(
                      labelText: 'Confirmar Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmaSenhaVisivel
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(
                            () =>
                                _confirmaSenhaVisivel = !_confirmaSenhaVisivel,
                          );
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  // ✅ CAMPO DE CÓDIGO — SÓ APARECE QUANDO PRECISAR
                  if (_mostrarCampoCodigo) ...[
                    const SizedBox(height: 24),
                    TextField(
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Código de Verificação',
                        hintText: 'Digite os 6 dígitos',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.verified_user),
                      ),
                      onChanged: (valor) {
                        setState(() {
                          _codigoDigitado = valor;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '🔔 Enviamos o código no e-mail informado.',
                      style: TextStyle(color: Colors.green, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // BOTÃO
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _cadastrar,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Cores.roxoEscuro, // 💜 Roxo Escuro!
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _carregando
                          ? const CircularProgressIndicator(color: Colors.white)
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

  // 🎨 Auxiliar de Decoração
  InputDecoration _dec(String label, IconData icone, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icone),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      );
}
