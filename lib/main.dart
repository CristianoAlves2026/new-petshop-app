import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils/constantes.dart';
import 'telas/tela_login.dart';
import 'telas/tela_cadastro.dart';
import 'telas/tela_recuperar_senha.dart';

final FlutterLocalNotificationsPlugin _notificacoes =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _aoReceberEmSegundoPlano(RemoteMessage mensagem) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await _inicializarNotificacoesVisuais();

  FirebaseMessaging.onBackgroundMessage(_aoReceberEmSegundoPlano);

  FirebaseMessaging.onMessage.listen((RemoteMessage mensagem) async {
    final notificacao = mensagem.notification;
    if (notificacao != null) {
      await _mostrarNotificacaoNaTela(
        notificacao.title ?? "Notificação",
        notificacao.body ?? "",
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage mensagem) {
    debugPrint("🔔 Toque na notificação");
  });

  await _configurarNotificacoes();
  runApp(const MeuApp());
}

Future<void> _inicializarNotificacoesVisuais() async {
  const configAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const configIOS = DarwinInitializationSettings();
  const config = InitializationSettings(android: configAndroid, iOS: configIOS);
  await _notificacoes.initialize(config);
}

Future<void> _mostrarNotificacaoNaTela(String titulo, String mensagem) async {
  const detalhesAndroid = AndroidNotificationDetails(
    'lembretes',
    'Lembretes',
    channelDescription: 'Notificações de lembretes',
    importance: Importance.high,
    priority: Priority.high,
  );
  const detalhes = NotificationDetails(android: detalhesAndroid);
  await _notificacoes.show(0, titulo, mensagem, detalhes);
}

Future<void> _configurarNotificacoes() async {
  final messaging = FirebaseMessaging.instance;

  final permissao = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (permissao.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('✅ Permissão concedida!');
    final token = await messaging.getToken();
    debugPrint('📱 Token: $token');

    messaging.onTokenRefresh.listen((novoToken) {
      debugPrint('🔄 Token atualizado: $novoToken');
    });
  } else {
    debugPrint('❌ Permissão negada!');
  }
}

Future<void> _enviarTokenParaApi(String token, dynamic idTutor) async {
  try {
    final resposta = await http.post(
      Uri.parse('$apiBase/$idTutor/token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(token),
    );
    debugPrint(
      resposta.statusCode == 200
          ? '✅ Token salvo!'
          : '⚠️ Erro: ${resposta.statusCode}',
    );
  } catch (e) {
    debugPrint('❌ Erro: $e');
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
