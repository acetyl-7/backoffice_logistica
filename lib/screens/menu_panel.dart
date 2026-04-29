import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MenuPanel extends StatelessWidget {
  final String driverId;
  final String driverName;
  final String? driverPhotoUrl;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenRefuels;
  final VoidCallback onOpenIncidents;
  final VoidCallback onOpenImages;
  final VoidCallback onOpenProfile;
  final VoidCallback? onRevokeAuthorization;

  const MenuPanel({
    super.key,
    required this.driverId,
    required this.driverName,
    this.driverPhotoUrl,
    required this.onOpenChat,
    required this.onOpenTasks,
    required this.onOpenRefuels,
    required this.onOpenIncidents,
    required this.onOpenImages,
    required this.onOpenProfile,
    this.onRevokeAuthorization,
  });

  Future<void> _revokeAuthorization(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Revogar Autorização'),
          ],
        ),
        content: Text(
          'Tens a certeza que pretendes revogar a autorização de $driverName?\n\n'
          'O motorista ficará bloqueado e terá de ser autorizado novamente.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Revogar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Encontrar documento por uid
      final querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: driverId)
          .limit(1)
          .get();

      DocumentReference docRef;
      if (querySnap.docs.isNotEmpty) {
        docRef = querySnap.docs.first.reference;
      } else {
        docRef = FirebaseFirestore.instance.collection('users').doc(driverId);
      }

      await docRef.update({'isAuthorized': false});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.block, color: Colors.white),
                const SizedBox(width: 8),
                Text('Autorização de $driverName foi revogada.'),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        // Notificar o pai para atualizar o estado
        onRevokeAuthorization?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao revogar autorização: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu de Gestão: $driverName'),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── SECÇÃO DO PERFIL DO MOTORISTA ──
              CircleAvatar(
                radius: 64,
                backgroundColor: Colors.blue.shade100,
                backgroundImage:
                    (driverPhotoUrl != null && driverPhotoUrl!.isNotEmpty)
                        ? NetworkImage(driverPhotoUrl!)
                        : null,
                child: (driverPhotoUrl == null || driverPhotoUrl!.isEmpty)
                    ? Icon(Icons.person,
                        size: 64, color: Colors.blueGrey.shade700)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                driverName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // ── Fleet ID Badge (tempo real) ──
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('uid', isEqualTo: driverId)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  String? fleetId;
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                    fleetId = data['driverId']?.toString();
                  }
                  final hasFleetId = fleetId != null && fleetId.isNotEmpty;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hasFleetId ? Colors.indigo.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasFleetId ? Colors.indigo.shade200 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tag,
                          size: 15,
                          color: hasFleetId ? Colors.indigo.shade600 : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasFleetId ? 'Fleet ID: $fleetId' : 'Fleet ID: Não sincronizado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasFleetId ? Colors.indigo.shade700 : Colors.grey.shade500,
                            fontStyle: hasFleetId ? FontStyle.normal : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Painel de Controlo',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 48),

              // ── BOTOES DE AÇÃO ──
              Wrap(
                spacing: 32,
                runSpacing: 32,
                alignment: WrapAlignment.center,
                children: [
                  _buildMenuCard(
                    context,
                    icon: Icons.chat,
                    color: Colors.blue.shade600,
                    title: 'Abrir Chat',
                    subtitle: 'Falar com o Motorista',
                    onTap: onOpenChat,
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.checklist,
                    color: Colors.teal.shade600,
                    title: 'Ver Tarefas',
                    subtitle: 'Gerir atividades do motorista',
                    onTap: onOpenTasks,
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.local_gas_station,
                    color: Colors.orange.shade600,
                    title: 'Ver Abastecimentos',
                    subtitle: 'Histórico de combustível',
                    onTap: onOpenRefuels,
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red.shade600,
                    title: 'Ver Incidentes',
                    subtitle: 'Gerir registos de problemas',
                    onTap: onOpenIncidents,
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.image,
                    color: Colors.deepPurple.shade600,
                    title: 'Ver Imagens',
                    subtitle: 'Fotos normais e Upscaled',
                    onTap: onOpenImages,
                  ),
                  _buildMenuCard(
                    context,
                    icon: Icons.person_outline,
                    color: Colors.blueGrey.shade600,
                    title: 'Editar Perfil',
                    subtitle: 'Dados e Contactos do Motorista',
                    onTap: onOpenProfile,
                  ),
                ],
              ),

              const SizedBox(height: 48),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 16),

              // ── ZONA DE PERIGO ──
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Zona de Administração',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Revoga o acesso deste motorista à aplicação. Esta ação pode ser revertida através do processo de autorização.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.red.shade700),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _revokeAuthorization(context),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Revogar Autorização'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 300,
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
