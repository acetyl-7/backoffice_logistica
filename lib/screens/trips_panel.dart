import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  DateTime selectedDate = DateTime.now();
  DocumentSnapshot? selectedTripDoc;

  @override
  void initState() {
    super.initState();
    selectedDriverId = widget.driverId;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedTripDoc = null; // reset trip view
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Lista de Viagens do Dia (Esquerda) ──
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
          ),
          child: Column(
            children: [
              // Cabeçalho de Seleção
              Container(
                padding: const EdgeInsets.all(16.0),
                color: const Color(0xFF0F172A),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: widget.onBack,
                        ),
                      ),
                    const Text(
                      'Filtros de Viagem',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Dropdown de Motoristas
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('A carregar...'),
                            );
                          }
                          final docs = snapshot.data!.docs;
                          final driverItems = docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final nome = data['name'] ?? data['nome'] ?? 'Sem Nome';
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(nome, overflow: TextOverflow.ellipsis),
                            );
                          }).toList();

                          // Garantir que a seleção atual existe
                          if (selectedDriverId != null && !docs.any((d) => d.id == selectedDriverId)) {
                            selectedDriverId = null;
                          }

                          return DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('Selecionar Motorista'),
                              value: selectedDriverId,
                              items: driverItems,
                              // Disable dropdown if explicitly passed driver
                              onChanged: widget.driverId != null ? null : (val) {
                                setState(() {
                                  selectedDriverId = val;
                                  selectedTripDoc = null;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Seletor de Data
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd/MM/yyyy').format(selectedDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de Viagens
              Expanded(
                child: _buildTripsList(),
              ),
            ],
          ),
        ),

        // ── Painel Principal de Detalhe (Direita) ──
        Expanded(
          child: _buildTripDetail(),
        ),
      ],
    );
  }

  Widget _buildTripsList() {
    if (selectedDriverId == null) {
      return const Center(child: Text('Selecione um motorista', style: TextStyle(color: Colors.grey)));
    }

    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: selectedDriverId)
          .where('startTime', isGreaterThanOrEqualTo: startOfDay)
          .where('startTime', isLessThanOrEqualTo: endOfDay)
          .orderBy('startTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Nenhuma viagem encontrada neste dia.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final startKms = data['startKms'] ?? 0.0;
            final endKms = data['endKms'];
            final startTime = (data['startTime'] as Timestamp?)?.toDate();
            final endTime = (data['endTime'] as Timestamp?)?.toDate();
            final status = data['status'] ?? 'active';
            
            final totalKms = endKms != null ? (endKms - startKms).toStringAsFixed(1) : '---';
            final startTimeStr = startTime != null ? DateFormat('HH:mm').format(startTime) : '--:--';
            final endTimeStr = endTime != null ? DateFormat('HH:mm').format(endTime) : '--:--';

            final isSelected = selectedTripDoc?.id == doc.id;

            return ListTile(
              selected: isSelected,
              selectedTileColor: Colors.blue.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(
                status == 'completed' ? Icons.check_circle : Icons.play_circle_fill,
                color: status == 'completed' ? Colors.green : Colors.blue,
                size: 32,
              ),
              title: Text('$startTimeStr - $endTimeStr', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$totalKms km percorridos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  selectedTripDoc = doc;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTripDetail() {
    if (selectedTripDoc == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Selecione uma viagem para ver a Timeline',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final data = selectedTripDoc!.data() as Map<String, dynamic>;
    final tractor = data['tractorPlate'] ?? 'N/D';
    final trailer = data['trailerPlate'] ?? 'N/D';
    final startKms = data['startKms'] ?? 0.0;
    final endKms = data['endKms'];
    final startTime = (data['startTime'] as Timestamp?)?.toDate();
    final endTime = (data['endTime'] as Timestamp?)?.toDate();
    final startLoc = data['startLocation'] as GeoPoint?;
    final endLoc = data['endLocation'] as GeoPoint?;

    final totalKms = endKms != null ? (endKms - startKms).toStringAsFixed(1) : '---';
    final duration = startTime != null
        ? (endTime ?? DateTime.now()).difference(startTime)
        : Duration.zero;
        
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final durationStr = '${h}h ${m}m';

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // CABEÇALHO DA VIAGEM
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Resumo da Viagem',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                    ),
                    if (startLoc != null && endLoc != null)
                      ElevatedButton.icon(
                        onPressed: () => _openMapRoute(startLoc, endLoc),
                        icon: const Icon(Icons.map),
                        label: const Text('Ver Trajeto'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildMetricCard(Icons.directions_car, 'Veículos', '$tractor | $trailer'),
                    const SizedBox(width: 16),
                    _buildMetricCard(Icons.speed, 'Quilómetros', '$startKms a ${endKms ?? "..."} (Total: $totalKms km)'),
                    const SizedBox(width: 16),
                    _buildMetricCard(Icons.timer, 'Duração', durationStr),
                  ],
                ),
              ],
            ),
          ),
          
          // TIMELINE DE EVENTOS
          Expanded(
            child: _buildTimeline(startTime, endTime),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.blueGrey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(DateTime? start, DateTime? end) {
    if (start == null || selectedDriverId == null) {
      return const Center(child: Text('Data de início inválida.'));
    }
    
    final filterEnd = end ?? DateTime.now();

    return FutureBuilder(
      future: Future.wait([
        // Tarefas
        FirebaseFirestore.instance.collection('tasks')
          .where('driverId', isEqualTo: selectedDriverId)
          .get(),
        // Abastecimentos
        FirebaseFirestore.instance.collection('refuels')
          .where('driverId', isEqualTo: selectedDriverId)
          .get(),
        // Incidentes
        FirebaseFirestore.instance.collection('incidents')
          .where('driverId', isEqualTo: selectedDriverId)
          .get(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }

        final results = snapshot.data as List<QuerySnapshot>;
        final allEvents = <Map<String, dynamic>>[];

        // Process tarefas
        for (var doc in results[0].docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = (data['completedAt'] as Timestamp?)?.toDate() ?? (data['timestamp'] as Timestamp?)?.toDate();
          if (ts != null && ts.isAfter(start) && ts.isBefore(filterEnd)) {
            allEvents.add({'type': 'task', 'data': data, 'time': ts});
          }
        }

        // Process abastecimentos
        for (var doc in results[1].docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = (data['timestamp'] as Timestamp?)?.toDate();
          if (ts != null && ts.isAfter(start) && ts.isBefore(filterEnd)) {
            allEvents.add({'type': 'refuel', 'data': data, 'time': ts});
          }
        }

        // Process incidentes
        for (var doc in results[2].docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = (data['timestamp'] as Timestamp?)?.toDate();
          if (ts != null && ts.isAfter(start) && ts.isBefore(filterEnd)) {
            allEvents.add({'type': 'incident', 'data': data, 'time': ts});
          }
        }

        allEvents.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

        if (allEvents.isEmpty) {
          return const Center(
            child: Text('Nenhum evento registado durante esta viagem.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: allEvents.length,
          itemBuilder: (context, index) {
            final event = allEvents[index];
            final type = event['type'];
            final data = event['data'] as Map<String, dynamic>;
            final time = event['time'] as DateTime;
            
            return _buildTimelineItem(type, data, time);
          },
        );
      },
    );
  }

  Widget _buildTimelineItem(String type, Map<String, dynamic> data, DateTime time) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    final timeStr = DateFormat('HH:mm').format(time);

    switch (type) {
      case 'task':
        icon = data['status'] == 'completed' ? Icons.check_circle : Icons.schedule;
        color = data['status'] == 'completed' ? Colors.green : Colors.orange;
        title = data['title'] ?? 'Tarefa';
        subtitle = data['status'] == 'completed' ? 'Concluída' : 'Atribuída';
        break;
      case 'refuel':
        icon = Icons.local_gas_station;
        color = Colors.orange.shade700;
        title = 'Abastecimento';
        subtitle = "${data['liters']} L inseridos";
        break;
      case 'incident':
        icon = Icons.warning_amber_rounded;
        color = Colors.red.shade700;
        title = data['type'] ?? 'Incidente';
        subtitle = data['description'] ?? 'Sem detalhes';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        title = 'Desconhecido';
        subtitle = '';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              timeStr,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade600, fontSize: 16),
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              // Simular a linha
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 2,
                height: 40,
                color: Colors.grey.shade300,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMapRoute(GeoPoint startLoc, GeoPoint endLoc) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=${startLoc.latitude},${startLoc.longitude}&destination=${endLoc.latitude},${endLoc.longitude}');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Google Maps.')),
      );
    }
  }
}
