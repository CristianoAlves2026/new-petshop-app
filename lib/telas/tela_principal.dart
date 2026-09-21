import 'package:flutter/material.dart';
import '../../utils/constantes.dart';
import 'tela_cadastro_pet.dart';
import 'tela_produtos.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TelaPrincipal extends StatefulWidget {
  final dynamic idTutor;
  final String nomeTutor;
  const TelaPrincipal({
    super.key,
    required this.idTutor,
    required this.nomeTutor,
  });
  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  bool menuAberto = false;
  List<dynamic> _listaPets = [];
  bool _carregando = true;
  List<dynamic> _listaRacas = [];

  @override
  void initState() {
    super.initState();
    _carregarPets();
  }

  Future<void> _carregarPets() async {
    try {
      final respostaRacas = await http.get(Uri.parse('$apiBase/racas'));
      if (respostaRacas.statusCode == 200) {
        _listaRacas = json.decode(respostaRacas.body);
      }
      final resposta = await http.get(
        Uri.parse('$apiBase/pets/tutor/${widget.idTutor}'),
      );
      if (resposta.statusCode == 200) {
        setState(() {
          _listaPets = json.decode(resposta.body);
          _carregando = false;
        });
      }
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PetShop CRM'),
            Text(widget.nomeTutor, style: const TextStyle(fontSize: 14)),
          ],
        ),
        backgroundColor: Cores.roxoEscuro,
        foregroundColor: Cores.branco,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() {
              menuAberto = !menuAberto;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ TÍTULO / ESPAÇO — NÃO TEM BOTÃO AQUI MAIS!
                const SizedBox(height: 8),

                // ✅ AQUI ESTÁ O SEGREDO → Expanded envolve SOMENTE a lista!
                Expanded(
                  child: _carregando
                      ? const Center(child: CircularProgressIndicator())
                      : _listaPets.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum Pet cadastrado',
                            style: TextStyle(
                              fontSize: 16,
                              color: Cores.textoClaro,
                            ),
                          ),
                        )
                      : GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.90,
                          padding: EdgeInsets.zero,
                          children: List.generate(_listaPets.length, (i) {
                            final pet = _listaPets[i];
                            //print('🔍 DADOS COMPLETOS DO PET: $pet');

                            final nomePet = pet['nome'] ?? 'Sem nome';
                            String nomeRaca = 'Raça não informada';
                            final idRacaPet = pet['idRaca'];
                            if (idRacaPet != null) {
                              var encontrada = _listaRacas.firstWhere(
                                (r) => r['id'] == idRacaPet,
                                orElse: () => null,
                              );
                              if (encontrada != null) {
                                nomeRaca =
                                    encontrada['nome']?.toString() ?? nomeRaca;
                              }
                            }

                            String textoSexo = pet['sexo']?.toString() ?? '';
                            String textoIdade = '';
                            if (pet['nascimento'] != null &&
                                pet['nascimento'].toString().isNotEmpty) {
                              try {
                                DateTime nascimento = DateTime.parse(
                                  pet['nascimento'].toString(),
                                );
                                DateTime hoje = DateTime.now();
                                int anos = hoje.year - nascimento.year;
                                int meses = hoje.month - nascimento.month;
                                int dias = hoje.day - nascimento.day;
                                if (dias < 0) {
                                  meses--;
                                  DateTime mesAnterior = DateTime(
                                    hoje.year,
                                    hoje.month,
                                    0,
                                  );
                                  dias += mesAnterior.day;
                                }
                                if (meses < 0) {
                                  anos--;
                                  meses += 12;
                                }
                                List<String> partes = [];
                                if (anos > 0)
                                  partes.add(
                                    '$anos ${anos == 1 ? "ano" : "anos"}',
                                  );
                                if (meses > 0)
                                  partes.add(
                                    '$meses ${meses == 1 ? "mês" : "meses"}',
                                  );
                                if (partes.isEmpty)
                                  partes.add(
                                    '$dias ${dias == 1 ? "dia" : "dias"}',
                                  );
                                textoIdade = partes.join(' e ');
                              } catch (e) {
                                textoIdade = '';
                              }
                            }

                            final foto = pet['foto']?.toString().trim();

                            return Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(
                                  color: Cores.roxoClaro,
                                  width: 2,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                highlightColor: Colors.transparent,
                                splashColor: Cores.roxoClaro.withOpacity(0.2),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TelaProdutos(
                                        nomePet:
                                            pet['nome']?.toString() ??
                                            'Sem nome',
                                        idPet: pet['id'],
                                        idPetshop: pet['idPetshop'],
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 36,
                                        backgroundColor: Cores.roxoClaro,
                                        child:
                                            (foto != null &&
                                                foto.isNotEmpty &&
                                                foto.startsWith('http'))
                                            ? ClipOval(
                                                child: Image.network(
                                                  foto,
                                                  fit: BoxFit.cover,
                                                  width: 72,
                                                  height: 72,
                                                  errorBuilder:
                                                      (context, erro, pilha) =>
                                                          const Icon(
                                                            Icons.pets,
                                                            color: Colors.white,
                                                            size: 36,
                                                          ),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.pets,
                                                color: Colors.white,
                                                size: 36,
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  TelaCadastroPet(
                                                    idTutor: widget.idTutor,
                                                    pet: pet,
                                                  ),
                                            ),
                                          ).then((resultado) {
                                            if (resultado == true) {
                                              _carregarPets();
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            '⋯',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Cores.roxoEscuro,
                                              height: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        nomePet,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$nomeRaca${textoIdade.isNotEmpty ? '\n$textoIdade' : ''}${textoSexo.isNotEmpty ? ' · $textoSexo' : ''}",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          height: 1.2,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                ), // ✅ FIM DO Expanded — A LISTA ACABA AQUI
                // ==============================================
                // ✅ BOTÃO "NOVO PET" — FORA DO Expanded → EMBAIXO!
                // ==============================================
              ],
            ),
          ),

          // ✅ MENU LATERAL
          if (menuAberto)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: MediaQuery.of(context).size.width / 2,
                color: Cores.branco,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.person,
                        color: Cores.roxoEscuro,
                      ),
                      title: const Text('Meus Dados'),
                      onTap: () {
                        setState(() {
                          menuAberto = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📋 Em breve!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // ✅ ==== BOTÃO FLUTUANTE ====
      floatingActionButton: FloatingActionButton(
        backgroundColor: Cores.roxoEscuro,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TelaCadastroPet(idTutor: widget.idTutor),
            ),
          ).then((resultado) {
            if (resultado == true) {
              _carregarPets();
            }
          });
        },
        child: const Icon(Icons.add, size: 28),
      ),

      // ✅ ==== FIM DO BOTÃO FLUTUANTE ====
    );
  }
}
