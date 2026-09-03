import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils/constantes.dart'; // ✅ SUAS CONSTANTES
import 'telas/tela_login.dart';
import 'telas/tela_cadastro.dart';
import 'telas/tela_recuperar_senha.dart';

// ✅ INICIALIZA FIREBASE E CONFIGURA NOTIFICAÇÕES
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ INICIA O FIREBASE
  await Firebase.initializeApp();

  // ✅ CONFIGURA NOTIFICAÇÕES E PEGA TOKEN
  await _configurarNotificacoes();

  runApp(const MeuApp());
}

// ✅ PEGA TOKEN E ENVIA PARA API
Future<void> _configurarNotificacoes() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // ✅ Pede permissão de notificação
  NotificationSettings permissao = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (permissao.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('✅ Permissão de notificação concedida!');

    // ✅ PEGA O TOKEN
    String? token = await messaging.getToken();
    debugPrint('📱 TOKEN DO CELULAR: $token');

    // ✅ SE TIVER TOKEN, ENVIA PARA API
    if (token != null) {
      // ⚠️ O idTutor VAI VIR DA TELA DE LOGIN — por enquanto deixamos para depois
      // _enviarTokenParaApi(token, idTutor);
    }

    // ✅ ATUALIZA TOKEN SE MUDAR
    messaging.onTokenRefresh.listen((novoToken) {
      debugPrint('🔄 Token atualizado: $novoToken');
    });
  } else {
    debugPrint('❌ Permissão de notificação NEGADA!');
  }
}

// ✅ ENVIA TOKEN PARA A API (usaremos depois do login)
Future<void> _enviarTokenParaApi(String token, dynamic idTutor) async {
  try {
    final resposta = await http.post(
      Uri.parse('$apiBase/tutores/$idTutor/token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(token),
    );

    debugPrint(
      resposta.statusCode == 200
          ? '✅ Token salvo na API!'
          : '❌ Erro ao salvar token: ${resposta.statusCode}',
    );
  } catch (e) {
    debugPrint('❌ Erro de conexão: $e');
  }
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetShop CRM',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const TelaLogin(),
      routes: {
        '/cadastro': (context) => const TelaCadastro(),
        '/recuperar-senha': (context) => const TelaRecuperarSenha(),
      },
    );
  }
}
