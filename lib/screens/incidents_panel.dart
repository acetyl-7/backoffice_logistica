import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class IncidentsPanel extends StatefulWidget {
  final String driverId;
  final String driverName;
  final VoidCallback onBack;

  const IncidentsPanel({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.onBack,
  });

  @override
  State<IncidentsPanel> createState() => _IncidentsPanelState();
}

class _IncidentsPanelState extends State<IncidentsPanel> {
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 50, color: Colors.white),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUnlockDialog(String docId) {
    _pinController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Desbloquear Incidente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Introduza o PIN de Administrador para desbloquear.'),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (_pinController.text == '1234') {
                  Navigator.of(context).pop();
                  await FirebaseFirestore.instance
                      .collection('incidents')
                      .doc(docId)
                      .update({'status': 'pending'});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Incidente desbloqueado com sucesso.')),
                    );
                    Navigator.of(context).pop(); // Fechar o dialog de detalhes
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN incorreto.'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Desbloquear', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showIncidentDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isApproved = data['status'] == 'approved';

    final TextEditingController plateCtrl = TextEditingController(text: data['plate'] ?? '');
    final TextEditingController kmsCtrl = TextEditingController(text: data['kms']?.toString() ?? '');
    final TextEditingController descCtrl = TextEditingController(text: data['description'] ?? '');

    final List<dynamic> imageUrls = data['imageUrls'] ?? [];
    final GeoPoint? location = data['location'];
    
    Timestamp? tsDate = data['incidentDate'];
    String formattedDate = 'Data desconhecida';
    if (tsDate != null) {
      formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(tsDate.toDate());
    }

    String typeText = data['type'] ?? 'Desconhecido';
    if (typeText == 'Outro' && data['customReason'] != null) {
      typeText += ' (${data['customReason']})';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('Incidente: $typeText')),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Data do Registo: $formattedDate', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  if (isApproved) ...[
                    const Text('Matrícula:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(data['plate'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    const Text('Quilómetros:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(data['kms']?.toString() ?? 'N/A'),
                    const SizedBox(height: 8),
                    const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(data['description'] ?? 'Sem descrição'),
                  ] else ...[
                    TextField(
                      controller: plateCtrl,
                      decoration: const InputDecoration(labelText: 'Matrícula', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kmsCtrl,
                      decoration: const InputDecoration(labelText: 'Quilómetros', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Text('Fotografias Anexadas:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  if (imageUrls.isEmpty)
                    const Text('Sem imagens anexadas.', style: TextStyle(fontStyle: FontStyle.italic))
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _showImageDialog(imageUrls[index]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    ),
                  if (location != null) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final lat = location.latitude;
                          final lng = location.longitude;
                          final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                          if (!await launchUrl(url)) {
                            debugPrint('Could not launch $url');
                          }
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('Ver Local da Incidência no Mapa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (isApproved)
              ElevatedButton.icon(
                icon: const Icon(Icons.lock_open),
                label: const Text('Desbloquear (Requer PIN)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showUnlockDialog(doc.id),
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.lock),
                label: const Text('Aprovar e Bloquear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('incidents')
                      .doc(doc.id)
                      .update({
                    'plate': plateCtrl.text.trim().toUpperCase(),
                    'kms': kmsCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'status': 'approved',
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Incidente aprovado e bloqueado!')),
                    );
                    Navigator.of(context).pop();
                  }
                },
              )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text('Incidentes: ${widget.driverName}'),
        backgroundColor: Colors.white,
        elevation: 1,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('incidents')
            .where('driverId', isEqualTo: widget.driverId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar incidentes: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum incidente registado por este motorista.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
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

              String groupDateStr;
              if (docDate == today) {
                groupDateStr = 'Hoje';
              } else if (docDate == yesterday) {
                groupDateStr = 'Ontem';
              } else {
                groupDateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
              }

              if (groupDateStr != lastDate) {
                lastDate = groupDateStr;
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
                        groupDateStr,
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

            final status = data['status'] ?? 'pending';
            final bool isApproved = status == 'approved';

            final String type = data['type'] ?? 'Desconhecido';
            final String plate = data['plate'] ?? 'Sem Matrícula';

            Timestamp? ts = data['incidentDate'];
            String dateStr = '';
            if (ts != null) {
              dateStr = DateFormat('HH:mm').format(ts.toDate());
            }

            listItems.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isApproved ? Colors.green.shade100 : Colors.orange.shade100,
                      child: Icon(
                        isApproved ? Icons.lock : Icons.lock_open,
                        color: isApproved ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    title: Text('$type • $plate'),
                    subtitle: Text(dateStr),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showIncidentDialog(doc),
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: listItems,
          );
        },
      ),
    );
  }
}
