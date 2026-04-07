import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TasksPanel extends StatefulWidget {
  final String driverId;
  final String driverName;
  final VoidCallback? onBack;

  const TasksPanel({
    super.key,
    required this.driverId,
    required this.driverName,
    this.onBack,
  });

  @override
  State<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends State<TasksPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showTaskAssignmentDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final freightIdController = TextEditingController();
    final operationLocationController = TextEditingController();
    final operationAddressController = TextEditingController();
    final operationReferenceController = TextEditingController();
    final tractorPlateController = TextEditingController();
    final trailerPlateController = TextEditingController();
    final operationTypeOtherController = TextEditingController();
    final currentContext = context;

    String operationType = 'Carga';
    bool requiresPhotos = false;

    await showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nova Tarefa'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título da Tarefa',
                          hintText: 'ex: Descarregar no Porto',
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          hintText: 'ex: Armazém 4, Porta B',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: freightIdController,
                        decoration: const InputDecoration(
                          labelText: 'ID do Frete',
                          hintText: 'ex: FR-12345',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: operationLocationController,
                        decoration: const InputDecoration(
                          labelText: 'Local de Operação',
                          hintText: 'ex: Porto de Sines',
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: operationType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Operação',
                        ),
                        items: ['Carga', 'Descarga', 'Outras'].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => operationType = value);
                          }
                        },
                      ),
                      if (operationType == 'Outras') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: operationTypeOtherController,
                          decoration: const InputDecoration(
                            labelText: 'Qual a outra operação?',
                            hintText: 'ex: Manutenção, Reboque...',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Requer Fotografias'),
                        subtitle: const Text('Obrigatório tirar fotos na operação'),
                        value: requiresPhotos,
                        onChanged: (value) {
                          setState(() => requiresPhotos = value ?? false);
                        },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: operationAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Morada da Operação (Opcional)',
                          hintText: 'ex: Rua Principal, Lote 2',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: operationReferenceController,
                        decoration: const InputDecoration(
                          labelText: 'Referência da Operação (Opcional)',
                          hintText: 'ex: REF-999',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tractorPlateController,
                              decoration: const InputDecoration(
                                labelText: 'Matrícula Trator',
                                hintText: 'ex: AB-12-CD',
                              ),
                              inputFormatters: [TractorPlateFormatter()],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: trailerPlateController,
                              decoration: const InputDecoration(
                                labelText: 'Matrícula Reboque',
                                hintText: 'ex: L-123456',
                              ),
                              inputFormatters: [TrailerPlateFormatter()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();
                    final freightId = freightIdController.text.trim();
                    final operationLocation = operationLocationController.text.trim();
                    final operationAddress = operationAddressController.text.trim();
                    final operationReference = operationReferenceController.text.trim();
                    final tractorPlate = tractorPlateController.text.trim();
                    final trailerPlate = trailerPlateController.text.trim();
                    final operationTypeOther = operationTypeOtherController.text.trim();

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('O título da tarefa não pode estar vazio.')),
                      );
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance.collection('tasks').add({
                        'driverId': widget.driverId,
                        'title': title,
                        'description': description,
                        'freightId': freightId,
                        'operationLocation': operationLocation,
                        'operationType': operationType,
                        'operationTypeOther': operationTypeOther,
                        'requiresPhotos': requiresPhotos,
                        'operationAddress': operationAddress,
                        'operationReference': operationReference,
                        'tractorPlate': tractorPlate,
                        'trailerPlate': trailerPlate,
                        'status': 'pending',
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                      
                      if (!mounted) return;
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        const SnackBar(
                          content: Text('Tarefa atribuída com sucesso!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao atribuir tarefa: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Atribuir'),
                ),
              ],
            );
          }
        );
      },
    );
    titleController.dispose();
    descriptionController.dispose();
    freightIdController.dispose();
    operationLocationController.dispose();
    operationAddressController.dispose();
    operationReferenceController.dispose();
    tractorPlateController.dispose();
    trailerPlateController.dispose();
    operationTypeOtherController.dispose();
  }

  Timestamp? _getTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  GeoPoint? _getGeoPoint(dynamic value) {
    if (value is GeoPoint) return value;
    return null;
  }

  void _showTaskDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        final title = data['title']?.toString() ?? 'Sem título';
        final description = data['description']?.toString() ?? 'Sem descrição';
        final timestamp = _getTimestamp(data['timestamp']);
        final startedAt = _getTimestamp(data['startedAt']);
        final startLocation = _getGeoPoint(data['startLocation']);
        final completedAt = _getTimestamp(data['completedAt']);
        final completeLocation = _getGeoPoint(data['completeLocation']);
        final status = data['status']?.toString() ?? 'pending';
        final guiaNumber = data['guiaNumber']?.toString();
        final guiaImageUrl = data['guiaImageUrl']?.toString();
        final operationImageUrl = data['operationImageUrl']?.toString();

        final freightId = data['freightId']?.toString();
        final operationLocation = data['operationLocation']?.toString();
        final operationType = data['operationType']?.toString();
        final operationTypeOther = data['operationTypeOther']?.toString();
        final requiresPhotos = data['requiresPhotos'] as bool? ?? false;
        final operationAddress = data['operationAddress']?.toString();
        final operationReference = data['operationReference']?.toString();
        final tractorPlate = data['tractorPlate']?.toString();
        final trailerPlate = data['trailerPlate']?.toString();

        final dateFormatter = DateFormat('dd/MM/yyyy HH:mm:ss');

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(description),
                const SizedBox(height: 16),
                
                if (freightId != null && freightId.isNotEmpty) ...[
                  const Text('ID do Frete:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(freightId),
                  const SizedBox(height: 8),
                ],
                
                if (operationLocation != null && operationLocation.isNotEmpty) ...[
                  const Text('Local de Operação:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(operationLocation),
                  const SizedBox(height: 8),
                ],
                
                if (operationType != null && operationType.isNotEmpty) ...[
                  const Text('Tipo de Operação:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${operationType == "Outras" && operationTypeOther != null && operationTypeOther.isNotEmpty ? "$operationType - $operationTypeOther" : operationType} ${requiresPhotos ? "(Requer Fotos)" : ""}'),
                  const SizedBox(height: 8),
                ],

                if (operationAddress != null && operationAddress.isNotEmpty) ...[
                  const Text('Morada da Operação:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(operationAddress),
                  const SizedBox(height: 8),
                ],

                if (operationReference != null && operationReference.isNotEmpty) ...[
                  const Text('Referência:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(operationReference),
                  const SizedBox(height: 8),
                ],
                
                if ((tractorPlate != null && tractorPlate.isNotEmpty) || (trailerPlate != null && trailerPlate.isNotEmpty)) ...[
                  const Text('Veículos:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text([
                    if (tractorPlate != null && tractorPlate.isNotEmpty) 'Trator: $tractorPlate',
                    if (trailerPlate != null && trailerPlate.isNotEmpty) 'Reboque: $trailerPlate',
                  ].join(' | ')),
                  const SizedBox(height: 8),
                ],
                
                if (freightId != null || operationLocation != null || operationType != null || tractorPlate != null) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                ],
                
                if (timestamp != null) ...[
                  const Text('Data de Criação:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(dateFormatter.format(timestamp.toDate())),
                  const SizedBox(height: 16),
                ],

                if (startedAt != null) ...[
                  const Text('Hora de Início:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(dateFormatter.format(startedAt.toDate())),
                  if (startLocation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: TextButton.icon(
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('Ver Início no Mapa'),
                        onPressed: () => _openMap(startLocation.latitude, startLocation.longitude),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],

                if (completedAt != null) ...[
                  const Text('Hora de Conclusão:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(dateFormatter.format(completedAt.toDate())),
                  if (completeLocation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextButton.icon(
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('Ver Fim no Mapa'),
                        onPressed: () => _openMap(completeLocation.latitude, completeLocation.longitude),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                if (status == 'completed') ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Comprovativo de Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                  const SizedBox(height: 12),
                  if (guiaNumber != null && guiaNumber.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt, color: Colors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Número da Guia', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(guiaNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (guiaImageUrl != null && guiaImageUrl.isNotEmpty && guiaImageUrl.startsWith('http')) ...[
                    const Text('Foto da Guia:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showFullScreenImage(guiaImageUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          guiaImageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (operationImageUrl != null && operationImageUrl.isNotEmpty && operationImageUrl.startsWith('http')) ...[
                    const Text('Foto da Operação:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showFullScreenImage(operationImageUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          operationImageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 35),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o mapa.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: Text('Tarefas de ${widget.driverName}'),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: _showTaskAssignmentDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nova Tarefa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal.shade700,
          tabs: const [
            Tab(text: 'Ativas'),
            Tab(text: 'Passadas'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('driverId', isEqualTo: widget.driverId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar tarefas.'));
          }

          var allDocs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
          
          // Ordenação local para evitar erro de index em falta no Firestore
          allDocs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Descending (mais recente primeiro)
          });

          final activeDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] != 'completed';
          }).toList();

          final pastDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'completed';
          }).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTaskList(activeDocs, groupByDate: false),
              _buildTaskList(pastDocs, groupByDate: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaskList(List<QueryDocumentSnapshot> docs, {bool groupByDate = false}) {
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma tarefa encontrada.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (!groupByDate) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>;
          
          final title = data['title'] ?? 'Sem título';
          final status = data['status'] ?? 'pending';
          
          IconData iconData;
          Color iconColor;
          
          if (status == 'completed') {
            iconData = Icons.check_circle;
            iconColor = Colors.green;
          } else if (status == 'in_progress') {
            iconData = Icons.play_circle_fill;
            iconColor = Colors.blue;
          } else {
            iconData = Icons.schedule;
            iconColor = Colors.orange;
          }

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(iconData, color: iconColor, size: 36),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Estado: $status'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTaskDetails(data),
            ),
          );
        },
      );
    }

    String? lastDate;
    final List<Widget> listItems = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;

      if (timestamp != null) {
        final dt = timestamp.toDate();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final docDate = DateTime(dt.year, dt.month, dt.day);

        String dateStr;
        if (docDate == today) {
          dateStr = 'Hoje';
        } else if (docDate == yesterday) {
          dateStr = 'Ontem';
        } else {
          dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        }

        if (dateStr != lastDate) {
          lastDate = dateStr;
          listItems.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateStr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ),
          );
        }
      }

      final title = data['title'] ?? 'Sem título';
      final status = data['status'] ?? 'pending';
      
      IconData iconData;
      Color iconColor;
      
      if (status == 'completed') {
        iconData = Icons.check_circle;
        iconColor = Colors.green;
      } else if (status == 'in_progress') {
        iconData = Icons.play_circle_fill;
        iconColor = Colors.blue;
      } else {
        iconData = Icons.schedule;
        iconColor = Colors.orange;
      }

      listItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(iconData, color: iconColor, size: 36),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Estado: $status'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTaskDetails(data),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: listItems,
    );
  }
}

class TractorPlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    
    String cleanText = newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleanText.length > 6) {
      cleanText = cleanText.substring(0, 6);
    }
    
    String formatted = '';
    for (int i = 0; i < cleanText.length; i++) {
        formatted += cleanText[i];
        if ((i % 2 == 1) && i != cleanText.length - 1) {
            formatted += '-';
        }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class TrailerPlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.toUpperCase();
    if (text.isEmpty) return newValue;

    text = text.replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
    
    int firstHyphen = text.indexOf('-');
    if (firstHyphen != -1) {
      String before = text.substring(0, firstHyphen + 1);
      String after = text.substring(firstHyphen + 1).replaceAll('-', '');
      text = before + after;
    }

    int offset = newValue.selection.end;
    if (offset > text.length) offset = text.length;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
