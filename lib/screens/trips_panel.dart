import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Stream<QuerySnapshot> _usersStream;

  // Monthly stats: month (1..12) -> List of tasks
  Map<int, List<Map<String, dynamic>>> _yearlyTasks = {};
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
    if (selectedFleetDriverId == null && selectedDriverId == null) return;
    final driverIdToFetch = selectedFleetDriverId != null && selectedFleetDriverId!.isNotEmpty 
        ? selectedFleetDriverId! 
        : selectedDriverId!;

    setState(() {
      _isLoadingTasks = true;
      _yearlyTasks.clear();
    });

    final startOfYear = DateTime(selectedYear, 1, 1);
    final endOfYear = DateTime(selectedYear + 1, 1, 1);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('tasks')
          .where('driverId', isEqualTo: driverIdToFetch)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('date', isLessThan: Timestamp.fromDate(endOfYear))
          .get();

      Map<int, List<Map<String, dynamic>>> tasksByMonth = {
        for (var i = 1; i <= 12; i++) i: []
      };

      for (var doc in snap.docs) {
        final data = doc.data();
        final ts = data['date'] as Timestamp?;
        if (ts != null) {
          final dt = ts.toDate();
          if (tasksByMonth.containsKey(dt.month)) {
            data['id'] = doc.id;
            data['dt'] = dt;
            tasksByMonth[dt.month]!.add(data);
          }
        }
      }

      setState(() {
        _yearlyTasks = tasksByMonth;
        _isLoadingTasks = false;
      });
    } catch (e) {
      debugPrint("Erro ao buscar tarefas anuais: $e");
      setState(() {
        _isLoadingTasks = false;
      });
    }
  }

  void _showMonthCalendar(int monthIndex) {
    final month = monthIndex + 1;
    final tasksForMonth = _yearlyTasks[month] ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        return _MonthCalendarDialog(
          year: selectedYear,
          month: month,
          monthName: _monthNames[monthIndex],
          tasks: tasksForMonth,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Esquerda
          _buildSidebar(),
          // Área Principal
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
          // CABEÇALHO DO ANO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 32),
                  onPressed: () => _changeYear(-1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    selectedYear.toString(),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 32),
                  onPressed: () => _changeYear(1),
                ),
              ],
            ),
          ),
          
          // GRID DE MESES
          Expanded(
            child: _isLoadingTasks
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
                      final taskCount = _yearlyTasks[month]?.length ?? 0;
                      return _buildMonthCard(index, monthName, taskCount);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCard(int monthIndex, String monthName, int taskCount) {
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
                     _buildMetricRow(Icons.local_gas_station, 'Abast.', '0', Colors.orange),
                     _buildMetricRow(Icons.warning, 'Incidentes', '0', Colors.red),
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
}

class _MonthCalendarDialog extends StatelessWidget {
  final int year;
  final int month;
  final String monthName;
  final List<Map<String, dynamic>> tasks;

  const _MonthCalendarDialog({
    required this.year,
    required this.month,
    required this.monthName,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    // Collect active days
    final Set<int> activeDays = {};
    for (var t in tasks) {
      if (t['dt'] != null) {
        final dt = t['dt'] as DateTime;
        activeDays.add(dt.day);
      }
    }

    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final weekdayStart = firstDayOfMonth.weekday; // 1 = Seg, 7 = Dom

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
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
            // Weekday labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _WeekdayLabel('S'), _WeekdayLabel('T'), _WeekdayLabel('Q'),
                _WeekdayLabel('Q'), _WeekdayLabel('S'), _WeekdayLabel('S'), _WeekdayLabel('D'),
              ],
            ),
            const SizedBox(height: 8),
            // Calendar grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              // Calculate total cells needed considering offset
              itemCount: daysInMonth + weekdayStart - 1,
              itemBuilder: (context, index) {
                if (index < weekdayStart - 1) {
                  return const SizedBox(); // Empty padding for first week
                }
                final day = index - weekdayStart + 2;
                final hasTask = activeDays.contains(day);

                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasTask ? Colors.green.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasTask ? Colors.green.shade400 : Colors.grey.shade300,
                      width: hasTask ? 2 : 1,
                    )
                  ),
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontWeight: hasTask ? FontWeight.bold : FontWeight.normal,
                      color: hasTask ? Colors.green.shade800 : Colors.grey.shade800
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Legenda
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade400), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 8),
                const Text('Atividade Registada', style: TextStyle(color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
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
