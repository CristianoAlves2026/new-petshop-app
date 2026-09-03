import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constantes.dart';
import 'tela_principal.dart';
import 'tela_recuperar_senha.dart';
import 'tela_cadastro.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;
  bool _senhaVisivel = false;

  // ✅ MÁSCARA CORRIGIDA
  String _aplicarMascaraCpf(String valor) {
    String numeros = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeros.length > 11) {
      numeros = numeros.substring(0, 11);
    }
    if (numeros.length <= 3) return numeros;
    if (numeros.length <= 6)
      return '${numeros.substring(0, 3)}.${numeros.substring(3)}';
    if (numeros.length <= 9)
      return '${numeros.substring(0, 3)}.${numeros.substring(3, 6)}.${numeros.substring(6)}';
    return '${numeros.substring(0, 3)}.${numeros.substring(3, 6)}.${numeros.substring(6, 9)}-${numeros.substring(9, numeros.length)}';
  }

  String _limparCpf(String cpfComMascara) {
    return cpfComMascara.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // ✅ CARREGA CPF SALVO AO ABRIR A TELA
  Future<void> _carregarCpfSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cpfSalvo = prefs.getString('cpf_salvo');
    if (cpfSalvo != null && cpfSalvo.isNotEmpty) {
      _cpfController.text = _aplicarMascaraCpf(cpfSalvo);
    }
  }

  // ✅ SALVA CPF QUANDO ALTERADO
  Future<void> _salvarCpf(String cpfComMascara) async {
    final String cpfLimpo = _limparCpf(cpfComMascara);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cpf_salvo', cpfLimpo);
  }

  // ✅ LOGIN COMPLETO E FECHADO CORRETAMENTE
  Future<void> _fazerLogin() async {
    final cpfLimpo = _limparCpf(_cpfController.text);
    final senha = _senhaController.text.trim();

    if (cpfLimpo.length != 11) {
      _mostrarMensagem('CPF precisa ter 11 dígitos!', Colors.red);
      return;
    }
    if (senha.isEmpty) {
      _mostrarMensagem('Digite sua senha!', Colors.red);
      return;
    }

    setState(() => _carregando = true);
    try {
      final url = Uri.parse('$apiBase/login');
      final resposta = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'cpf': cpfLimpo, 'senha': senha}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = json.decode(resposta.body);
        final idTutor = dados['id'];
        // ✅ PEGA O TOKEN E ENVIA
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _enviarTokenParaApi(token, idTutor);
        }
        final String nomeTutor = dados['nome'];
        _mostrarMensagem(dados['mensagem'], Cores.roxoEscuro);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TelaPrincipal(idTutor: idTutor, nomeTutor: nomeTutor),
          ),
        );
      } else if (resposta.statusCode == 401) {
        _mostrarMensagem('❌ CPF ou senha incorretos', Colors.red);
      } else {
        _mostrarMensagem('⚠️ Erro: ${resposta.statusCode}', Colors.orange);
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem('❌ Erro de conexão: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarMensagem(String texto, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto, style: const TextStyle(fontSize: 16)),
        backgroundColor: cor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ✅ CARREGA CPF SALVO AO INICIAR
  @override
  void initState() {
    super.initState();
    _carregarCpfSalvo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.fundo,
      body: Column(
        children: [
          // 🔹 CABEÇALHO COLORIDO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: Cores.gradiente,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: const Column(
              children: [
                Icon(Icons.pets, size: 60, color: Colors.white),
                SizedBox(height: 12),
                Text(
                  'PetShop CRM',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Login',
                  style: TextStyle(fontSize: 20, color: Colors.white70),
                ),
              ],
            ),
          ),

          // 🔹 FORMULÁRIO
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                children: [
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
                    onChanged: (valor) {
                      final mascarado = _aplicarMascaraCpf(valor);
                      if (mascarado != valor) {
                        _cpfController.value = TextEditingValue(
                          text: mascarado,
                          selection: TextSelection.collapsed(
                            offset: mascarado.length,
                          ),
                        );
                      }
                      _salvarCpf(valor); // ✅ SALVA CPF AO DIGITAR
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _senhaController,
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
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _fazerLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Cores.roxoEscuro,
                        elevation: 5,
                      ),
                      child: _carregando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'ENTRAR',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TelaRecuperarSenha(),
                      ),
                    ),
                    child: const Text(
                      'Esqueci minha senha',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaCadastro()),
                    ),
                    child: const Text(
                      'Não tem conta? Cadastre-se',
                      style: TextStyle(fontSize: 16),
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

  // ✅ === FUNÇÃO QUE ENVIA O TOKEN PARA A API ===
  Future<void> _enviarTokenParaApi(String token, dynamic idTutor) async {
    try {
      final resposta = await http.post(
        Uri.parse('$apiBase/$idTutor/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(token),
      );
      debugPrint(
        resposta.statusCode == 200
            ? '✅ Token salvo com sucesso para notificações!'
            : '⚠️ Token não foi salvo: código ${resposta.statusCode}',
      );
    } catch (e) {
      debugPrint('❌ Erro ao enviar token: $e');
    }
  }
}
