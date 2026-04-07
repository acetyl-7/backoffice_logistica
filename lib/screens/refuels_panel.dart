import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class RefuelsPanel extends StatefulWidget {
  final String driverId;
  final String driverName;
  final VoidCallback? onBack;

  const RefuelsPanel({
    super.key,
    required this.driverId,
    required this.driverName,
    this.onBack,
  });

  @override
  State<RefuelsPanel> createState() => _RefuelsPanelState();
}

class _RefuelsPanelState extends State<RefuelsPanel> {
  final String _adminPin = "1234"; // Simplificação. Idealmente deve vir do user role

  Future<bool> _showPinDialog(BuildContext parentContext) async {
    final pinController = TextEditingController();
    final bool? result = await showDialog<bool>(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Acesso Restrito'),
          content: TextField(
            controller: pinController,
            decoration: const InputDecoration(labelText: 'Código PIN (Admins)'),
            keyboardType: TextInputType.number,
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinController.text == _adminPin) {
                  Navigator.pop(dialogContext, true);
                } else {
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('PIN incorreto'), backgroundColor: Colors.red),
                    );
                  }
                  Navigator.pop(dialogContext, false);
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    return result ?? false;
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

  Future<void> _approveRefuel(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('refuels').doc(docId).update({
        'status': 'approved',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abastecimento aprovado!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aprovar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }



  void _showRefuelDetails(BuildContext parentContext, String docId, Map<String, dynamic> data) {
    bool isApproved = (data['status']?.toString() ?? 'pending') == 'approved';

    final plateController = TextEditingController(text: data['plate']?.toString() ?? 'N/A');
    final trailerPlateController = TextEditingController(text: data['trailerPlate']?.toString() ?? '');
    final litersController = TextEditingController(text: data['liters']?.toString() ?? '0.0');
    final notesController = TextEditingController(text: data['notes']?.toString() ?? 'Sem observações');
    String currentFuelType = data['fuelType']?.toString() ?? 'Gasóleo Simples';
    bool currentFullTank = data['fullTank'] is bool ? data['fullTank'] : false;

    final receiptUrl = data['receiptUrl']?.toString();
    final GeoPoint? location = data['location'] is GeoPoint ? data['location'] as GeoPoint : null;
    final timestamp = data['timestamp'] as Timestamp?;
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text('Detalhes do Abastecimento: ${plateController.text}'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timestamp != null) ...[
                        const Text('Data e Hora:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(dateFormatter.format(timestamp.toDate())),
                        const SizedBox(height: 16),
                      ],
                      if (isApproved) ...[
                        const Text('Matrícula:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(plateController.text),
                        const SizedBox(height: 8),
                        if (trailerPlateController.text.isNotEmpty) ...[
                          const Text('Matrícula do Reboque:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(trailerPlateController.text),
                          const SizedBox(height: 8),
                        ],
                        const Text('Quantidade:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${litersController.text} L'),
                        const SizedBox(height: 8),
                        const Text('Tipo de Combustível:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(currentFuelType),
                        const SizedBox(height: 8),
                        const Text('Atestado:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(currentFullTank ? 'Sim' : 'Não', style: TextStyle(color: currentFullTank ? Colors.green : Colors.black)),
                        const SizedBox(height: 8),
                        const Text('Observações:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(notesController.text),
                        const SizedBox(height: 8),
                        const Text('Estado:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Aprovado 🔒', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      ] else ...[
                        const Text('Matrícula:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: plateController,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 12),
                        const Text('Matrícula do Reboque:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: trailerPlateController,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 12),
                        const Text('Quantidade:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: litersController,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 12),
                        const Text('Tipo de Combustível:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: currentFuelType,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12), isDense: true),
                          items: ['Gasóleo Simples', 'Gasóleo Aditivado', 'AdBlue']
                              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setStateDialog(() => currentFuelType = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
                          child: SwitchListTile(
                            title: const Text('Atestou o depósito?', style: TextStyle(fontSize: 14)),
                            value: currentFullTank,
                            onChanged: (val) => setStateDialog(() => currentFullTank = val),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Observações:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: notesController,
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        const Text('Estado:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Pendente de Aprovação', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                      ],
                      if (receiptUrl != null && receiptUrl.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Talão:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showImageDialog(receiptUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              receiptUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
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
                            label: const Text('Ver Local de Abastecimento'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fechar'),
                ),
                if (!isApproved) ...[
                  ElevatedButton(
                    onPressed: () async {
                      final lts = double.tryParse(litersController.text.replaceAll(',', '.')) ?? 0.0;
                      await FirebaseFirestore.instance.collection('refuels').doc(docId).update({
                        'plate': plateController.text.trim().toUpperCase(),
                        'trailerPlate': trailerPlateController.text.trim().toUpperCase(),
                        'liters': lts,
                        'fuelType': currentFuelType,
                        'fullTank': currentFullTank,
                        'notes': notesController.text.trim(),
                      });
                      Navigator.of(dialogContext).pop();
                      if (parentContext.mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('Abastecimento guardado!'), backgroundColor: Colors.blue),
                        );
                      }
                    },
                    child: const Text('Guardar'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _approveRefuel(docId);
                      Navigator.of(dialogContext).pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Aprovar e Bloquear'),
                  ),
                ],
                if (isApproved)
                  TextButton.icon(
                    onPressed: () async {
                      final isAllowed = await _showPinDialog(parentContext);
                      if (isAllowed) {
                        await FirebaseFirestore.instance.collection('refuels').doc(docId).update({
                          'status': 'pending',
                        });
                        setStateDialog(() {
                          isApproved = false;
                        });
                      }
                    },
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: const Text('Desbloquear (Requer PIN)'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            );
          },
        );
      },
    );
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
        title: Text('Abastecimentos de ${widget.driverName}'),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('refuels')
            .where('driverId', isEqualTo: widget.driverId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar abastecimentos: ${snapshot.error}'));
          }

          var docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
          
          // Ordenação local para evitar erro de index em falta no Firestore
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Descending (mais recente primeiro)
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum abastecimento encontrado.',
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

            final plate = data['plate'] ?? 'Sem Matrícula';
            final liters = data['liters'] ?? 0.0;
            final fuelType = data['fuelType'] ?? 'Desconhecido';
            final fullTank = data['fullTank'] ?? false;
            final status = data['status'] ?? 'pending';
            final isApproved = status == 'approved';

            String dateStr = '';
            if (timestamp != null) {
              dateStr = DateFormat('HH:mm').format(timestamp.toDate());
            }

            listItems.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isApproved ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: Icon(
                      isApproved ? Icons.verified : Icons.local_gas_station,
                      color: isApproved ? Colors.green : Colors.orange,
                      size: 36,
                    ),
                    title: Text('$plate${dateStr.isNotEmpty ? ' - $dateStr' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$liters L • $fuelType'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (fullTank)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.battery_full, color: Colors.green),
                                Text('Atestado', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        Icon(
                          isApproved ? Icons.lock : Icons.lock_open,
                          color: isApproved ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _showRefuelDetails(context, doc.id, data),
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
