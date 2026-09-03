import 'package:flutter/material.dart';

class Cores {
  // 💜 COR PRINCIPAL — OPÇÃO 3: ELEGANTE E MODERNA
  static const Color roxoEscuro = Color(0xFF512DA8);
  static const Color roxoClaro = Color(0xFF7E57C2);

  // 🩶 COR DE DESTAQUE / ACENTO
  static const Color cinzaAzulado = Color(0xFF607D8B);

  // 🔴 CORES DE ESTADO (mantive para mensagens)
  static const Color erro = Color(0xFFC62828); // 🔴 Mantém vermelho
  static const Color sucesso = Color(0xFF512DA8); // 💜 Agora roxo escuro
  static const Color alerta = Color(0xFF607D8B); // 🩶 Cinza azulado

  // ⚪ FUNDO E TEXTO
  static const Color fundo = Color(0xFFF5F5F5);
  static const Color texto = Color(0xFF263238);
  static const Color textoClaro = Color(0xFF757575);
  static const Color branco = Color(0xFFFFFFFF);

  // 🎭 GRADIENTE PRINCIPAL — NOVAS CORES!
  static const List<Color> gradiente = [
    Color(0xFF512DA8), // 💜 Roxo Escuro
    Color(0xFF7E57C2), // 🟣 Roxo Claro
  ];
}

const String cloudName = "vmcaoh90"; // ✅ COLE ESTA LINHA
const String cloudUploadPreset = "petshop_upload"; // ✅ ADICIONE ESTA LINHA

// 🌐 URL DA API — NÃO ALTERAR!
// emulador do Android Studio
const String apiBase = "http://10.0.2.2:8080/api/v1";

//celular real
//const String apiBase = "https://petshop-api-rtra.onrender.com/api/v1";
