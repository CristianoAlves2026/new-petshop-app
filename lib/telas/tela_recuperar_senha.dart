import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/constantes.dart';

class TelaRecuperarSenha extends StatefulWidget {
  const TelaRecuperarSenha({super.key});

  @override
  State<TelaRecuperarSenha> createState() => _TelaRecuperarSenhaState();
}

class _TelaRecuperarSenhaState extends State<TelaRecuperarSenha> {
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  bool _carregando = false;

  // ──────────────────────────────────────
  // 🎭 MÁSCARA DE CPF
  // ──────────────────────────────────────
  String _mascaraCpf(String valor) {
    String num = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (num.length > 11) num = num.substring(0, 11);
    if (num.length <= 3) return num;
    if (num.length <= 6) return '${num.substring(0, 3)}.${num.substring(3)}';
    if (num.length <= 9) {
      return '${num.substring(0, 3)}.${num.substring(3, 6)}.${num.substring(6)}';
    }
    return '${num.substring(0, 3)}.${num.substring(3, 6)}.${num.substring(6, 9)}-${num.substring(9)}';
  }

  String _limparCpf(String valor) => valor.replaceAll(RegExp(r'[^0-9]'), '');

  // ──────────────────────────────────────
  // ✅ VALIDAR CPF
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
  // ✅ VALIDAR E-MAIL
  // ──────────────────────────────────────
  bool _validarEmail(String email) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return regex.hasMatch(email);
  }

  // ──────────────────────────────────────
  // 🚀 ENVIAR RECUPERAÇÃO
  // ──────────────────────────────────────
  Future<void> _recuperar() async {
    final cpf = _limparCpf(_cpfController.text);
    final email = _emailController.text.trim().toLowerCase();

    // ✅ Validações em branco
    if (cpf.isEmpty) return _mensagem('❌ CPF é obrigatório', Colors.red);
    if (email.isEmpty) return _mensagem('❌ E-mail é obrigatório', Colors.red);

    // ✅ Validações de formato
    if (!_validarCpf(cpf)) return _mensagem('❌ CPF inválido', Colors.red);
    if (!_validarEmail(email))
      return _mensagem('❌ Formato de e-mail inválido', Colors.red);

    setState(() => _carregando = true);

    try {
      final res = await http
          .post(
            Uri.parse('$apiBase/recuperar-senha'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'cpf': cpf, 'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final dados = json.decode(res.body);
        final nome = dados['nome'];
        final novaSenha = dados['novaSenha'];
        _mensagem('✅ $nome, sua nova senha é $novaSenha', Cores.roxoEscuro);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.pop(context);
        });
      } else if (res.statusCode == 404) {
        _mensagem('❌ CPF ou E-mail não encontrados', Colors.red);
      } else {
        _mensagem('❌ Erro ao processar solicitação', Colors.red);
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
          // 🔹 CABEÇALHO COM SETA E TÍTULO
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
                  // SETA DE VOLTAR
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
                  // TÍTULO
                  const Text(
                    'Recuperar Senha',
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_reset,
                    size: 80,
                    //color: Color(0xFF2E7D32),
                    color: Cores.roxoEscuro,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Informe seu CPF e E-mail cadastrados para receber uma nova senha.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),

                  // ✅ CAMPO CPF COM MÁSCARA
                  TextField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'CPF',
                      hintText: '123.456.789-09',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (v) {
                      final m = _mascaraCpf(v);
                      if (m != v) {
                        _cpfController.value = TextEditingValue(
                          text: m,
                          selection: TextSelection.collapsed(offset: m.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ✅ CAMPO E-MAIL — SÓ MINÚSCULAS
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
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
                  const SizedBox(height: 30),

                  // ✅ BOTÃO RECUPERAR
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _recuperar,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Cores.roxoEscuro,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _carregando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'RECUPERAR SENHA',
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
