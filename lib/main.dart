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
import 'telas/produtos/tela_lancamento.dart'; // ✅ NOVA — Tela do lançamento
import 'telas/tela_produtos.dart';

final FlutterLocalNotificationsPlugin _notificacoes =
    FlutterLocalNotificationsPlugin();

// ✅ Chave global para abrir telas de qualquer lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _aoReceberEmSegundoPlano(RemoteMessage mensagem) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _inicializarNotificacoesVisuais();

  // ✅ APP FECHADO — ao tocar na notificação
  FirebaseMessaging.instance.getInitialMessage().then((mensagemInicial) {
    if (mensagemInicial != null) {
      _abrirLancamentoDaNotificacao(mensagemInicial.data);
    }
  });

  FirebaseMessaging.onBackgroundMessage(_aoReceberEmSegundoPlano);

  // ✅ APP ABERTO — recebe notificação

  FirebaseMessaging.onMessage.listen((RemoteMessage mensagem) async {
    debugPrint('🔔 [APP ABERTO] Mensagem recebida!');
    final notificacao = mensagem.notification;

    String titulo = notificacao?.title ?? "Notificação";
    String corpo = notificacao?.body ?? "";

    if (corpo.isNotEmpty) {
      await _mostrarNotificacaoNaTela(titulo, corpo);
    }
  });

  // ✅ TOCA NA NOTIFICAÇÃO — abre direto no lançamento
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage mensagem) {
    _abrirLancamentoDaNotificacao(mensagem.data);
  });

  await _configurarNotificacoes();
  runApp(const MeuApp());
}

// ✅ Abre a tela do lançamento correto
void _abrirLancamentoDaNotificacao(Map<String, dynamic> dados) {
  final idLancamento = dados['idLancamento'];
  final idPet = dados['idPet'];

  if (idLancamento != null && idPet != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contexto = navigatorKey.currentContext;
      if (contexto != null) {
        Navigator.push(
          contexto,
          MaterialPageRoute(
            builder: (context) => TelaProdutos(
              nomePet: "", // ✅ Vazio — a tela recarrega os dados
              idPet: idPet,
            ),
          ),
        );
      }
    });
  }
}

Future<void> _inicializarNotificacoesVisuais() async {
  const configAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const configIOS = DarwinInitializationSettings();
  const config = InitializationSettings(android: configAndroid, iOS: configIOS);
  await _notificacoes.initialize(
    config,
    // ✅ Ao tocar na notificação exibida no app
    onDidReceiveNotificationResponse: (resposta) {
      if (resposta.payload != null) {
        try {
          final dados = json.decode(resposta.payload!);
          _abrirLancamentoDaNotificacao(dados);
        } catch (_) {}
      }
    },
  );
}

Future<void> _mostrarNotificacaoNaTela(String titulo, String mensagem) async {
  const detalhesAndroid = AndroidNotificationDetails(
    'lembretes',
    'Lembretes',
    channelDescription: 'Notificações de lembretes',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );
  const detalhes = NotificationDetails(android: detalhesAndroid);

  await _notificacoes.show(titulo.hashCode, titulo, mensagem, detalhes);
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
      navigatorKey: navigatorKey, // ✅ Permite navegar de qualquer lugar
      theme: ThemeData(primarySwatch: Colors.green),
      home: const TelaLogin(),
      routes: {
        '/cadastro': (context) => const TelaCadastro(),
        '/recuperar-senha': (context) => const TelaRecuperarSenha(),
      },
    );
  }
}
