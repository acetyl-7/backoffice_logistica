import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as rr;

class TripsPanel extends StatefulWidget {
  final String? driverId;
  final String? driverName;
  final VoidCallback? onBack;

  const TripsPanel({super.key, this.driverId, this.driverName, this.onBack});

  @override
  State<TripsPanel> createState() => _TripsPanelState();
}

class _TripsPanelState extends State<TripsPanel> {
  String? selectedDriverId;
  String? selectedFleetDriverId;
  int selectedYear = DateTime.now().year;
  int _activeTab = 0; // 0: Estatísticas, 1: Relatório de Trabalho

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Stream<QuerySnapshot> _usersStream;

  // Monthly stats: month (1..12) -> List of tasks, refuels, incidents
  Map<int, List<Map<String, dynamic>>> _yearlyTasks = {};
  Map<int, List<Map<String, dynamic>>> _yearlyRefuels = {};
  Map<int, List<Map<String, dynamic>>> _yearlyIncidents = {};
  Map<int, int> _startingTasks = {};
  Map<int, int> _startingRefuels = {};
  Map<int, int> _startingIncidents = {};
  bool _isLoadingTasks = false;

  final List<String> _monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  void initState() {
    super.initState();
    selectedDriverId = widget.driverId;
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDatePt(DateTime dt) {
    final List<String> weekDays = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
    final List<String> months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    
    final wDay = weekDays[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    
    return '$wDay, ${dt.day} de $monthName de ${dt.year}';
  }

  Future<void> _openMapLink(double lat, double lon) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Não foi possível abrir o mapa para $url');
      }
    } catch (e) {
      debugPrint('Erro ao abrir link do mapa: $e');
    }
  }

  void _showInteractiveMapDialog(GeoPoint startLoc, GeoPoint? endLoc) {
    double centerLat = startLoc.latitude;
    double centerLon = startLoc.longitude;
    if (endLoc != null) {
      centerLat = (startLoc.latitude + endLoc.latitude) / 2;
      centerLon = (startLoc.longitude + endLoc.longitude) / 2;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 800,
            height: 600,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.map, color: Color(0xFF0F172A)),
                        SizedBox(width: 10),
                        Text(
                          'Mapa do Dia de Trabalho',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: rr.LatLng(centerLat, centerLon),
                            initialZoom: 13.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.cisterpor.backoffice_logistica',
                            ),
                            if (endLoc != null)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: [
                                      rr.LatLng(startLoc.latitude, startLoc.longitude),
                                      rr.LatLng(endLoc.latitude, endLoc.longitude),
                                    ],
                                    strokeWidth: 4.0,
                                    color: Colors.blue.shade600,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: rr.LatLng(startLoc.latitude, startLoc.longitude),
                                  width: 40,
                                  height: 40,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                                      ],
                                    ),
                                    child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                                  ),
                                ),
                                if (endLoc != null)
                                  Marker(
                                    point: rr.LatLng(endLoc.latitude, endLoc.longitude),
                                    width: 40,
                                    height: 40,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                                        ],
                                      ),
                                      child: const Icon(Icons.flag, color: Colors.white, size: 20),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                const Text('Início', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                const SizedBox(width: 16),
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.red.shade600, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                const Text('Fim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(int tabIndex, String label, IconData icon) {
    final isSelected = _activeTab == tabIndex;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = tabIndex;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF0F172A)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDriver(String uid, String fleetDriverId) {
    setState(() {
      selectedDriverId = uid;
      selectedFleetDriverId = fleetDriverId;
    });
    _fetchYearlyData();
  }

  void _changeYear(int offset) {
    setState(() {
      selectedYear += offset;
    });
    _fetchYearlyData();
  }

  Future<void> _fetchYearlyData() async {
    final String? mainDriverId = selectedDriverId;
    if (mainDriverId == null) return;

    setState(() {
      _isLoadingTasks = true;
      _yearlyTasks.clear();
      _yearlyRefuels.clear();
      _yearlyIncidents.clear();
      _startingTasks.clear();
      _startingRefuels.clear();
      _startingIncidents.clear();
    });

    try {
      // Fetch Tasks: Could be assigned to the SQL ID or the Firebase Auth UID
      final List<String> taskDriverIds = [
        mainDriverId,
        if (selectedFleetDriverId != null && selectedFleetDriverId!.isNotEmpty)
          selectedFleetDriverId!,
      ];

      final QuerySnapshot<Map<String, dynamic>> tasksSnap;
      if (taskDriverIds.length > 1) {
        tasksSnap = await FirebaseFirestore.instance
            .collection('tasks')
            .where('driverId', whereIn: taskDriverIds)
            .get();
      } else {
        tasksSnap = await FirebaseFirestore.instance
            .collection('tasks')
            .where('driverId', isEqualTo: mainDriverId)
            .get();
      }

      // Fetch Refuels: Always stored using the Firebase Auth UID
      final refuelsSnap = await FirebaseFirestore.instance
          .collection('refuels')
          .where('driverId', isEqualTo: mainDriverId)
          .get();

      // Fetch Incidents: Always stored using the Firebase Auth UID
      final incidentsSnap = await FirebaseFirestore.instance
          .collection('incidents')
          .where('driverId', isEqualTo: mainDriverId)
          .get();

      // Fetch starting counts from yearly_stats if they exist
      final statsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(mainDriverId)
          .collection('yearly_stats')
          .doc(selectedYear.toString())
          .get();

      Map<int, int> tempStartingTasks = {};
      Map<int, int> tempStartingRefuels = {};
      Map<int, int> tempStartingIncidents = {};

      if (statsDoc.exists) {
        final statsData = statsDoc.data();
        if (statsData != null) {
          final tasksMap = statsData['tasks'] as Map<String, dynamic>?;
          tasksMap?.forEach((k, v) => tempStartingTasks[int.tryParse(k) ?? 0] = (v as num).toInt());
          
          final refuelsMap = statsData['refuels'] as Map<String, dynamic>?;
          refuelsMap?.forEach((k, v) => tempStartingRefuels[int.tryParse(k) ?? 0] = (v as num).toInt());
          
          final incidentsMap = statsData['incidents'] as Map<String, dynamic>?;
          incidentsMap?.forEach((k, v) => tempStartingIncidents[int.tryParse(k) ?? 0] = (v as num).toInt());
        }
      }

      Map<int, List<Map<String, dynamic>>> tasksByMonth = {
        for (var i = 1; i <= 12; i++) i: []
      };
      Map<int, List<Map<String, dynamic>>> refuelsByMonth = {
        for (var i = 1; i <= 12; i++) i: []
      };
      Map<int, List<Map<String, dynamic>>> incidentsByMonth = {
        for (var i = 1; i <= 12; i++) i: []
      };

      for (var doc in tasksSnap.docs) {
        final data = doc.data();
        final ts = data['completedAt'] as Timestamp? ??
            data['date'] as Timestamp? ??
            data['timestamp'] as Timestamp?;
        if (ts != null) {
          final dt = ts.toDate();
          if (dt.year == selectedYear && tasksByMonth.containsKey(dt.month)) {
            data['id'] = doc.id;
            data['dt'] = dt;
            
            // Only count completed/finished tasks as requested by the user
            final status = data['status']?.toString() ?? '';
            if (status == 'completed' || status == 'terminada' || status == 'anulada') {
              tasksByMonth[dt.month]!.add(data);
            }
          }
        }
      }

      for (var doc in refuelsSnap.docs) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        if (ts != null) {
          final dt = ts.toDate();
          if (dt.year == selectedYear && refuelsByMonth.containsKey(dt.month)) {
            data['id'] = doc.id;
            data['dt'] = dt;
            refuelsByMonth[dt.month]!.add(data);
          }
        }
      }

      for (var doc in incidentsSnap.docs) {
        final data = doc.data();
        final ts = data['incidentDate'] as Timestamp? ??
            data['timestamp'] as Timestamp?;
        if (ts != null) {
          final dt = ts.toDate();
          if (dt.year == selectedYear && incidentsByMonth.containsKey(dt.month)) {
            data['id'] = doc.id;
            data['dt'] = dt;
            incidentsByMonth[dt.month]!.add(data);
          }
        }
      }

      setState(() {
        _yearlyTasks = tasksByMonth;
        _yearlyRefuels = refuelsByMonth;
        _yearlyIncidents = incidentsByMonth;
        _startingTasks = tempStartingTasks;
        _startingRefuels = tempStartingRefuels;
        _startingIncidents = tempStartingIncidents;
        _isLoadingTasks = false;
      });
    } catch (e) {
      debugPrint("Erro ao buscar dados anuais: $e");
      setState(() {
        _isLoadingTasks = false;
      });
    }
  }

  void _showMonthCalendar(int monthIndex) {
    final month = monthIndex + 1;
    final tasksForMonth = _yearlyTasks[month] ?? [];
    final refuelsForMonth = _yearlyRefuels[month] ?? [];
    final incidentsForMonth = _yearlyIncidents[month] ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        return _MonthCalendarDialog(
          year: selectedYear,
          month: month,
          monthName: _monthNames[monthIndex],
          tasks: tasksForMonth,
          refuels: refuelsForMonth,
          incidents: incidentsForMonth,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF0F172A),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Row(
                      children: [
                        if (widget.onBack != null)
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: widget.onBack,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        if (widget.onBack != null) const SizedBox(width: 8),
                        const Text(
                          'Monitorização',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                   ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
          Container(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Motoristas Autorizados',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade600),
              )
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _usersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Erro ao carregar'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data?.docs ?? [];
                final authorized = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['isAuthorized'] != true) return false;
                  
                  if (_searchQuery.isNotEmpty) {
                    final String name = (data['name']?.toString() ?? '').toLowerCase();
                    final String nickname = (data['nickname']?.toString() ?? '').toLowerCase();
                    if (!name.contains(_searchQuery) && !nickname.contains(_searchQuery)) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (authorized.isEmpty) {
                  return const Center(
                    child: Text('Nenhum motorista encontrado.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: authorized.length,
                  itemBuilder: (context, index) {
                    final doc = authorized[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final String? tName = data['name']?.toString();
                    final String? tNickname = data['nickname']?.toString();
                    final nome = (tName != null && tName.trim().isNotEmpty)
                        ? tName
                        : ((tNickname != null && tNickname.trim().isNotEmpty) ? tNickname : 'Sem Nome');
                    
                    final uid = data['uid']?.toString() ?? doc.id;
                    final fleetId = data['driverId']?.toString() ?? '';
                    final photoUrl = data['photoUrl']?.toString();
                    final isSelected = selectedDriverId == uid;

                    if (selectedDriverId == uid && selectedFleetDriverId == null) {
                       WidgetsBinding.instance.addPostFrameCallback((_) {
                           _selectDriver(uid, fleetId);
                       });
                    }

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.blue.shade50,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.blueGrey) : null,
                      ),
                      title: Text(nome, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      onTap: () => _selectDriver(uid, fleetId),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (selectedDriverId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Selecione um motorista para ver o seu histórico',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      widget.driverName != null && widget.driverName!.isNotEmpty 
                          ? widget.driverName! 
                          : 'Atividades do Motorista',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 32),
                    _buildTabButton(0, 'Estatísticas', Icons.calendar_month),
                    const SizedBox(width: 12),
                    _buildTabButton(1, 'Relatório de Viagens', Icons.description),
                  ],
                ),
                if (_activeTab == 0)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 28),
                        onPressed: () => _changeYear(-1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          selectedYear.toString(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 28),
                        onPressed: () => _changeYear(1),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: _activeTab == 0
                ? (_isLoadingTasks
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final monthName = _monthNames[index];
                          final taskCount = (_yearlyTasks[month]?.length ?? 0) + (_startingTasks[month] ?? 0);
                          final refuelCount = (_yearlyRefuels[month]?.length ?? 0) + (_startingRefuels[month] ?? 0);
                          final incidentCount = (_yearlyIncidents[month]?.length ?? 0) + (_startingIncidents[month] ?? 0);
                          return _buildMonthCard(index, monthName, taskCount, refuelCount, incidentCount);
                        },
                      ))
                : _buildWorkReportsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCard(int monthIndex, String monthName, int taskCount, int refuelCount, int incidentCount) {
    return InkWell(
      onTap: () => _showMonthCalendar(monthIndex),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0,4))],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Text(
                monthName,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                     _buildMetricRow(Icons.assignment, 'Tarefas', taskCount.toString(), Colors.green),
                     _buildMetricRow(Icons.local_gas_station, 'Abast.', refuelCount.toString(), Colors.orange),
                     _buildMetricRow(Icons.warning, 'Incidentes', incidentCount.toString(), Colors.red),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)
          ),
          child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  Widget _buildWorkReportsView() {
    final String? mainDriverId = selectedDriverId;
    if (mainDriverId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: mainDriverId)
          .orderBy('startTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar relatórios de viagens: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tripDocs = snapshot.data?.docs ?? [];
        if (tripDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma viagem registada para este motorista.',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: tripDocs.length,
          itemBuilder: (context, index) {
            final doc = tripDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildTripReportCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildTripReportCard(String tripId, Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? 'completed';
    final isActive = status == 'active';
    
    // Dates
    DateTime? startTime;
    final stVal = data['startTime'] ?? data['actualStartTime'];
    if (stVal != null && stVal is Timestamp) {
      startTime = stVal.toDate();
    }
    
    DateTime? endTime;
    final etVal = data['endTime'];
    if (etVal != null && etVal is Timestamp) {
      endTime = etVal.toDate();
    }

    final dateStr = startTime != null ? _formatDatePt(startTime) : 'Data Desconhecida';
    final startHour = startTime != null ? DateFormat('HH:mm').format(startTime) : '—';
    final endHour = endTime != null 
        ? DateFormat('HH:mm').format(endTime) 
        : (isActive ? 'Em curso...' : '—');
    final titleWithHours = '$dateStr  •  Início: $startHour  •  Fim: $endHour';
    
    // KMs
    final double startKms = (data['startKms'] as num?)?.toDouble() ?? 0.0;
    final double? endKms = (data['endKms'] as num?)?.toDouble();
    final double? distance = endKms != null ? (endKms - startKms) : null;
    
    // Vehicle
    final String tractor = data['tractorPlate']?.toString() ?? '—';
    final String trailer = data['trailerPlate']?.toString() ?? '';

    // Locations
    final startLoc = data['startLocation'] as GeoPoint?;
    final endLoc = data['endLocation'] as GeoPoint?;

    // Duration calculation
    String durationStr = '—';
    if (startTime != null) {
      final endCompare = endTime ?? DateTime.now();
      final diff = endCompare.difference(startTime);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      durationStr = '${hours}h ${minutes}m';
    }

    final startKmsStr = startKms.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    final endKmsStr = endKms != null 
        ? endKms.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')
        : '—';
    final distanceStr = distance != null 
        ? '${distance.toStringAsFixed(1)} km' 
        : (isActive ? 'Em viagem...' : '—');

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isActive ? Colors.green.shade600 : Colors.blueGrey.shade600,
                width: 6,
              ),
            ),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            leading: Icon(
              isActive ? Icons.play_circle_fill : Icons.check_circle,
              color: isActive ? Colors.green.shade600 : Colors.blueGrey.shade600,
              size: 32,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    titleWithHours,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.shade50 : Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? Colors.green.shade300 : Colors.blueGrey.shade300,
                    ),
                  ),
                  child: Text(
                    isActive ? 'Ativo (Em Curso)' : 'Concluído',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green.shade700 : Colors.blueGrey.shade800,
                    ),
                  ),
                ),
              ],
            ),
            children: [
              Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Column 1: Veículo
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VEÍCULO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade400,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.local_shipping, size: 20, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Trator: $tractor',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                      if (trailer.isNotEmpty)
                                        Text(
                                          'Reboque: $trailer',
                                          style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Column 2: Horário
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HORÁRIO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade400,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 20, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Início: ${startTime != null ? DateFormat('HH:mm').format(startTime) : "—"}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                      Text(
                                        'Fim: ${endTime != null ? DateFormat('HH:mm').format(endTime) : (isActive ? "Em curso..." : "—")}',
                                        style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600),
                                      ),
                                      Text(
                                        'Tempo Total: $durationStr',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isActive ? Colors.green.shade700 : Colors.blueGrey.shade700),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Column 3: Quilómetros
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QUILÓMETROS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade400,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.add_road, size: 20, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Inicial: $startKmsStr km',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                      Text(
                                        'Final: ${endKms != null ? "$endKmsStr km" : (isActive ? "Em viagem..." : "—")}',
                                        style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600),
                                      ),
                                      Text(
                                        'Distância: $distanceStr',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: distance != null ? Colors.blue.shade700 : Colors.blueGrey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Column: Tarefas
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TAREFAS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade400,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.checklist, size: 20, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Concluídas: ${data['completedTasksCount'] ?? 0}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                      Text(
                                        'A Decorrer: ${data['inProgressTasksCount'] ?? 0}',
                                        style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Column 4: Localização e Google Maps
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LOCALIZAÇÕES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade400,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (startLoc != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: InkWell(
                                    onTap: () => _openMapLink(startLoc.latitude, startLoc.longitude),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: Colors.green),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Início: ${startLoc.latitude.toStringAsFixed(4)}, ${startLoc.longitude.toStringAsFixed(4)}',
                                            style: const TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.map, size: 14, color: Colors.blue.shade700),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (endLoc != null)
                                InkWell(
                                  onTap: () => _openMapLink(endLoc.latitude, endLoc.longitude),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on, size: 16, color: Colors.red),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Fim: ${endLoc.latitude.toStringAsFixed(4)}, ${endLoc.longitude.toStringAsFixed(4)}',
                                          style: const TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.map, size: 14, color: Colors.blue.shade700),
                                      ],
                                    ),
                                  ),
                                )
                              else if (isActive)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_searching, size: 16, color: Colors.green.shade400),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Em viagem...',
                                        style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ),
                                ),
                              if (startLoc != null) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showInteractiveMapDialog(startLoc, endLoc),
                                    icon: const Icon(Icons.map, size: 18),
                                    label: const Text('Mostrar mapa'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F172A),
                                      side: const BorderSide(color: Color(0xFF0F172A)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthCalendarDialog extends StatelessWidget {
  final int year;
  final int month;
  final String monthName;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> refuels;
  final List<Map<String, dynamic>> incidents;

  const _MonthCalendarDialog({
    required this.year,
    required this.month,
    required this.monthName,
    required this.tasks,
    required this.refuels,
    required this.incidents,
  });

  @override
  Widget build(BuildContext context) {
    final Set<int> taskDays = {};
    for (var t in tasks) {
      if (t['dt'] != null) {
        final dt = t['dt'] as DateTime;
        taskDays.add(dt.day);
      }
    }
    final Set<int> refuelDays = {};
    for (var r in refuels) {
      if (r['dt'] != null) {
        final dt = r['dt'] as DateTime;
        refuelDays.add(dt.day);
      }
    }
    final Set<int> incidentDays = {};
    for (var i in incidents) {
      if (i['dt'] != null) {
        final dt = i['dt'] as DateTime;
        incidentDays.add(dt.day);
      }
    }

    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final weekdayStart = firstDayOfMonth.weekday;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$monthName $year',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _WeekdayLabel('S'), _WeekdayLabel('T'), _WeekdayLabel('Q'),
                _WeekdayLabel('Q'), _WeekdayLabel('S'), _WeekdayLabel('S'), _WeekdayLabel('D'),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: daysInMonth + weekdayStart - 1,
              itemBuilder: (context, index) {
                if (index < weekdayStart - 1) {
                  return const SizedBox();
                }
                final day = index - weekdayStart + 2;
                final hasTask = taskDays.contains(day);
                final hasRefuel = refuelDays.contains(day);
                final hasIncident = incidentDays.contains(day);

                final hasActivity = hasTask || hasRefuel || hasIncident;
                
                Border border;
                if (hasActivity) {
                  List<Color> borderColors = [];
                  if (hasTask) borderColors.add(Colors.green.shade400);
                  if (hasRefuel) borderColors.add(Colors.orange.shade400);
                  if (hasIncident) borderColors.add(Colors.red.shade400);
                  
                  Color primaryBorderColor = borderColors.first;
                  border = Border.all(color: primaryBorderColor, width: 2);
                } else {
                  border = Border.all(color: Colors.grey.shade300, width: 1);
                }

                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasActivity ? Colors.grey.shade100 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: border,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.toString(),
                        style: TextStyle(
                          fontWeight: hasActivity ? FontWeight.bold : FontWeight.normal,
                          color: hasActivity ? Colors.black87 : Colors.grey.shade800
                        ),
                      ),
                      if (hasActivity)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasTask) Container(margin: const EdgeInsets.symmetric(horizontal: 1), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                            if (hasRefuel) Container(margin: const EdgeInsets.symmetric(horizontal: 1), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                            if (hasIncident) Container(margin: const EdgeInsets.symmetric(horizontal: 1), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                          ],
                        )
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(Colors.green, 'Tarefas'),
                _buildLegendItem(Colors.orange, 'Abastecimentos'),
                _buildLegendItem(Colors.red, 'Incidentes'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade400)),
    );
  }
}
