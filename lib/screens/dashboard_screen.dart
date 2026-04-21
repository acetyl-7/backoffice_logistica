import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'menu_panel.dart';
import 'refuels_panel.dart';
import 'tasks_panel.dart';
import 'incidents_panel.dart';
import 'images_panel.dart';
import 'driver_authorization_panel.dart';
import 'trips_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? selectedDriverId;
  String? selectedDriverName;
  String? selectedDriverPhotoUrl;
  bool? selectedDriverIsAuthorized;
  Map<String, dynamic>? selectedDriverData;
  String currentView = 'menu';
  int _globalSelectedIndex = 0;

  late Stream<QuerySnapshot> _usersStream;
  final TextEditingController _pendingSearchController = TextEditingController();
  final TextEditingController _authorizedSearchController = TextEditingController();
  String _pendingSearchQuery = '';
  String _authorizedSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  @override
  void dispose() {
    _pendingSearchController.dispose();
    _authorizedSearchController.dispose();
    super.dispose();
  }

  Future<void> _markDriverMessagesAsRead(String driverId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('driverId', isEqualTo: driverId)
          .where('sender', isEqualTo: 'driver')
          .where('status', isEqualTo: 'sent')
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      await batch.commit();
      debugPrint(
          'Marcou ${querySnapshot.docs.length} mensagens como lidas para $driverId');
    } catch (e) {
      debugPrint('ERRO UPDATE (markAsRead): $e');
    }
  }

  void _selectDriver({
    required String driverId,
    required String nome,
    String? photoUrl,
    required bool isAuthorized,
    required Map<String, dynamic> data,
  }) {
    setState(() {
      selectedDriverId = driverId;
      selectedDriverName = nome;
      selectedDriverPhotoUrl = photoUrl;
      selectedDriverIsAuthorized = isAuthorized;
      selectedDriverData = data;
      currentView = 'menu';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _globalSelectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _globalSelectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: const Color(0xFF0F172A),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Motoristas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: Text('Rotas'),
              ),
            ],
          ),
          Expanded(
            child: _globalSelectedIndex == 0
                ? _buildMainDashboard()
                : const TripsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDashboard() {
    return Row(
      children: [
        // ── Lista Lateral (Esquerda) ──
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Cabeçalho
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: const Color(0xFF1E293B),
                  width: double.infinity,
                  child: const SafeArea(
                    bottom: false,
                    child: Text(
                      'Motoristas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Lista com duas secções
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _usersStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                            child: Text('Erro ao carregar motoristas.'));
                      }
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final allDocs = snapshot.data?.docs ?? [];

                      // Separar em autorizados e por autorizar
                      final pending = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['isAuthorized'] != false) return false;

                        final String nickname = (data['nickname']?.toString() ?? '').trim().toLowerCase();
                        if (nickname.isEmpty) return false;

                        if (_pendingSearchQuery.isNotEmpty) {
                          if (!nickname.contains(_pendingSearchQuery)) {
                            return false;
                          }
                        }
                        return true;
                      }).toList();

                      final authorized = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['isAuthorized'] != true) return false;

                        final String nickname = (data['nickname']?.toString() ?? '').trim().toLowerCase();
                        if (nickname.isEmpty) return false;

                        if (_authorizedSearchQuery.isNotEmpty) {
                          if (!nickname.contains(_authorizedSearchQuery)) {
                            return false;
                          }
                        }
                        return true;
                      }).toList();

                      if (allDocs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Nenhum utilizador encontrado.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // ── SECÇÃO: POR AUTORIZAR ──
                          _buildSectionHeader(
                            title: 'Por Autorizar',
                            count: pending.length,
                            color: Colors.amber.shade700,
                            badgeColor: Colors.amber.shade600,
                            icon: Icons.pending_actions,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: TextField(
                              controller: _pendingSearchController,
                              decoration: InputDecoration(
                                hintText: 'Pesquisar pendentes...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                  setState(() {
                                    _pendingSearchQuery = val.toLowerCase();
                                  });
                              },
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                ...pending.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final String? tNickname = data['nickname']?.toString();
                                  final nome = (tNickname != null && tNickname.trim().isNotEmpty) ? tNickname : 'Sem Alcunha';
                                  final photoUrl = data['photoUrl']?.toString();
                                  final driverId = data['uid']?.toString() ?? doc.id;
                                  final isSelected = selectedDriverId == driverId;

                                  return _buildPendingDriverTile(
                                    driverId: driverId,
                                    nome: nome,
                                    photoUrl: photoUrl,
                                    data: data,
                                    isSelected: isSelected,
                                  );
                                }),
                                if (pending.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Text(
                                      'Nenhum motorista correspondente.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          Container(height: 1, color: Colors.grey.shade300),

                          // ── SECÇÃO: AUTORIZADOS ──
                          _buildSectionHeader(
                            title: 'Autorizados',
                            count: authorized.length,
                            color: Colors.green.shade700,
                            badgeColor: Colors.green.shade600,
                            icon: Icons.verified_user,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: TextField(
                              controller: _authorizedSearchController,
                              decoration: InputDecoration(
                                hintText: 'Pesquisar autorizados...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) {
                                  setState(() {
                                    _authorizedSearchQuery = val.toLowerCase();
                                  });
                              },
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                ...authorized.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final String? tNickname = data['nickname']?.toString();
                                  final nome = (tNickname != null && tNickname.trim().isNotEmpty) ? tNickname : 'Sem Alcunha';
                                  final photoUrl = data['photoUrl']?.toString();
                                  final driverId = data['uid']?.toString() ?? doc.id;
                                  final isSelected = selectedDriverId == driverId;

                                  return _buildAuthorizedDriverTile(
                                    driverId: driverId,
                                    nome: nome,
                                    photoUrl: photoUrl,
                                    data: data,
                                    isSelected: isSelected,
                                  );
                                }),
                                if (authorized.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Text(
                                      'Nenhum motorista correspondente.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Área Principal (Direita) ──
          Expanded(
            child: _buildRightPanel(),
          ),
        ],
      );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required Color color,
    required Color badgeColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: color.withValues(alpha: 0.07),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDriverTile({
    required String driverId,
    required String nome,
    String? photoUrl,
    required Map<String, dynamic> data,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: Colors.amber.shade100,
            backgroundImage:
                (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? Icon(Icons.person,
                    color: Colors.amber.shade700)
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        nome,
        style: TextStyle(
          fontWeight:
              isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        'Pendente de autorização',
        style: TextStyle(
            fontSize: 11, color: Colors.amber.shade700),
      ),
      selected: isSelected,
      selectedTileColor: Colors.amber.shade50,
      onTap: () {
        _selectDriver(
          driverId: driverId,
          nome: nome,
          photoUrl: photoUrl,
          isAuthorized: false,
          data: data,
        );
      },
    );
  }

  Widget _buildAuthorizedDriverTile({
    required String driverId,
    required String nome,
    String? photoUrl,
    required Map<String, dynamic> data,
    required bool isSelected,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('driverId', isEqualTo: driverId)
          .where('sender', isEqualTo: 'driver')
          .where('status', isEqualTo: 'sent')
          .snapshots(),
      builder: (context, msgSnapshot) {
        if (msgSnapshot.hasError) {
          debugPrint(
              'ERRO FIRESTORE (badge $driverId): ${msgSnapshot.error}');
        }
        final unreadCount = msgSnapshot.data?.docs.length ?? 0;

        final int unreadTasks = data['unreadTasks'] as int? ?? 0;
        final int unreadRefuels = data['unreadRefuels'] as int? ?? 0;
        final int unreadIncidents = data['unreadIncidents'] as int? ?? 0;
        final int unreadImages = data['unreadImages'] as int? ?? 0;

        Widget buildBadge(int count, Color color) {
          if (count <= 0 || isSelected) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(left: 4.0), // Espaçamento entre bolinhas
            child: CircleAvatar(
              backgroundColor: color,
              radius: 11,
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            backgroundImage:
                (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? const Icon(Icons.person, color: Colors.blueGrey)
                : null,
          ),
          title: Text(
            nome,
            style: TextStyle(
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildBadge(unreadTasks, Colors.green), // Tarefas
              buildBadge(unreadRefuels, Colors.orange), // Abastecimentos 
              buildBadge(unreadIncidents, Colors.red), // Incidentes
              buildBadge(unreadImages, Colors.purple), // Imagens
              // Mensagens de Chat (usar azul escuro para distinguir)
              buildBadge(unreadCount, Colors.blue.shade800), 
            ],
          ),
          selected: isSelected,
          selectedTileColor: Colors.grey[200],
          onTap: () async {
            _selectDriver(
              driverId: driverId,
              nome: nome,
              photoUrl: photoUrl,
              isAuthorized: true,
              data: data,
            );
            await _markDriverMessagesAsRead(driverId);
          },
        );
      },
    );
  }

  Widget _buildRightPanel() {
    if (selectedDriverId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Selecione um motorista para ver opções.',
              style:
                  TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // Motorista por autorizar → Formulário de Autorização
    if (selectedDriverIsAuthorized == false) {
      return DriverAuthorizationPanel(
        key: ValueKey(selectedDriverId),
        driverId: selectedDriverId!,
        driverData: selectedDriverData ?? {},
      );
    }

    // Motorista autorizado → Menu normal
    switch (currentView) {
      case 'chat':
        return ChatScreen(
          selectedDriverId: selectedDriverId,
          selectedDriverName: selectedDriverName,
          onBack: () => setState(() => currentView = 'menu'),
        );
      case 'tasks':
        final realDriverId = selectedDriverData?['driverId']?.toString() ?? '';
        final idToPass = realDriverId.isNotEmpty ? realDriverId : selectedDriverId!;
        return TasksPanel(
          driverId: idToPass,
          driverName: selectedDriverName ?? 'Motorista',
          onBack: () => setState(() => currentView = 'menu'),
        );
      case 'refuels':
        return RefuelsPanel(
          driverId: selectedDriverId!,
          driverName: selectedDriverName ?? 'Motorista',
          onBack: () => setState(() => currentView = 'menu'),
        );
      case 'incidents':
        return IncidentsPanel(
          driverId: selectedDriverId!,
          driverName: selectedDriverName ?? 'Motorista',
          onBack: () => setState(() => currentView = 'menu'),
        );
      case 'images':
        return ImagesPanel(
          driverId: selectedDriverId!,
          driverName: selectedDriverName ?? 'Motorista',
          onBack: () => setState(() => currentView = 'menu'),
        );
      case 'profile':
        return Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                child: TextButton.icon(
                  onPressed: () => setState(() => currentView = 'menu'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar ao Menu'),
                ),
              ),
            ),
            Expanded(
              child: DriverAuthorizationPanel(
                key: ValueKey('profile_${selectedDriverId!}'),
                driverId: selectedDriverId!,
                driverData: selectedDriverData ?? {},
              ),
            ),
          ],
        );
      case 'menu':
      default:
        return MenuPanel(
          driverId: selectedDriverId!,
          driverName: selectedDriverName ?? 'Motorista',
          driverPhotoUrl: selectedDriverPhotoUrl,
          onOpenChat: () {
            setState(() => currentView = 'chat');
          },
          onOpenTasks: () {
            setState(() => currentView = 'tasks');
            FirebaseFirestore.instance.collection('users').doc(selectedDriverId!).update({'unreadTasks': 0}).catchError((_){});
          },
          onOpenRefuels: () {
            setState(() => currentView = 'refuels');
            FirebaseFirestore.instance.collection('users').doc(selectedDriverId!).update({'unreadRefuels': 0}).catchError((_){});
          },
          onOpenIncidents: () {
            setState(() => currentView = 'incidents');
            FirebaseFirestore.instance.collection('users').doc(selectedDriverId!).update({'unreadIncidents': 0}).catchError((_){});
          },
          onOpenImages: () {
            setState(() => currentView = 'images');
            FirebaseFirestore.instance.collection('users').doc(selectedDriverId!).update({'unreadImages': 0}).catchError((_){});
          },
          onOpenProfile: () => setState(() => currentView = 'profile'),
          onRevokeAuthorization: () {
            // Após revogar, desselecionar o motorista para limpar o painel
            setState(() {
              selectedDriverId = null;
              selectedDriverName = null;
              selectedDriverPhotoUrl = null;
              selectedDriverIsAuthorized = null;
              selectedDriverData = null;
              currentView = 'menu';
            });
          },
        );
    }
  }
}
