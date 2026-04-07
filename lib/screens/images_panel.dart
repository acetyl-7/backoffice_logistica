import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/upscale_service.dart';

class ImagesPanel extends StatefulWidget {
  final String driverId;
  final String driverName;
  final VoidCallback onBack;

  const ImagesPanel({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.onBack,
  });

  @override
  State<ImagesPanel> createState() => _ImagesPanelState();
}

class _ImagesPanelState extends State<ImagesPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UpscaleService _upscaleService = UpscaleService();

  late Future<List<NormalImage>> _normalImagesFuture;
  late Future<List<UpscaledImage>> _upscaledImagesFuture;

  void _loadImages() {
    setState(() {
      _normalImagesFuture = _upscaleService.getNormalImages(widget.driverId);
      _upscaledImagesFuture = _upscaleService.getUpscaledImages(widget.driverId);
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadImages();
      }
    });
    _loadImages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Hoje';
    if (d == yesterday) return 'Ontem';
    return DateFormat('dd MMMM yyyy', 'pt_PT').format(date);
  }

  Future<void> _downloadUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link.')),
        );
      }
    }
  }

  // ─── Dialogs/Actions ──────────────────────────────────────────────────────────

  void _showImageFullscreen(String imageUrl) {
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

  Future<void> _handleUpscale(String imageUrl) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fazer Upscale?'),
        content: const Text(
            'Deseja apagar a foto original (Normal) após o upscale para poupar espaço?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não, Manter Original'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sim, Apagar Original',
                style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar Upscale'),
          ),
        ],
      ),
    );

    if (confirm == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('A processar upscale com IA, aguarde...')),
          ],
        ),
      ),
    );

    try {
      await _upscaleService.processAndSaveUpscale(
        driverId: widget.driverId,
        originalImageUrl: imageUrl,
        deleteOriginal: confirm,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Upscale concluído com sucesso!'),
            backgroundColor: Colors.green),
      );

      _loadImages();
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleDeleteUpscaled(UpscaledImage image) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar imagem Upscaled?'),
        content: const Text(
            'Esta ação vai eliminar a imagem do Firebase Storage e também o registo desta operação. Não é reversível.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _upscaleService.deleteUpscaledImage(image);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Imagem apagada com sucesso.'),
            backgroundColor: Colors.green),
      );
      _loadImages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao apagar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleDeleteNormal(NormalImage image) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar imagem?'),
        content: const Text(
            'Esta ação vai eliminar a imagem do Firebase (Chat ou Incidente) e do Storage. Não é reversível.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _upscaleService.deleteNormalImage(image);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Imagem apagada com sucesso.'),
            backgroundColor: Colors.green),
      );
      _loadImages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao apagar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Image Card widgets ───────────────────────────────────────────────────────

  Widget _buildNormalImageCard(NormalImage image) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _showImageFullscreen(image.url),
                  child: Image.network(
                    image.url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, color: Colors.grey, size: 48),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _buildOptionsMenu(
                    url: image.url,
                    onDelete: () => _handleDeleteNormal(image),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Text(
              image.timestamp != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(image.timestamp!)
                  : 'Data desconhecida',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Upscale'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 4),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _handleUpscale(image.url),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpscaledImageCard(UpscaledImage image) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _showImageFullscreen(image.imageUrl),
                  child: Image.network(
                    image.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, color: Colors.grey, size: 48),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _buildOptionsMenu(
                    url: image.imageUrl,
                    onDelete: () => _handleDeleteUpscaled(image),
                  ),
                ),
                const Positioned(
                  bottom: 8,
                  left: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('AI',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              image.timestamp != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(image.timestamp!)
                  : 'Data desconhecida',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsMenu({
    required String url,
    VoidCallback? onDelete,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x99000000),
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onSelected: (value) async {
          if (value == 'download') {
            await _downloadUrl(url);
          } else if (value == 'delete' && onDelete != null) {
            onDelete();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'download',
            child: Row(children: [
              Icon(Icons.download, size: 18),
              SizedBox(width: 8),
              Text('Download'),
            ]),
          ),
          if (onDelete != null)
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text('Apagar', style: TextStyle(color: Colors.red[700])),
              ]),
            ),
        ],
      ),
    );
  }

  // ─── Grid builders ────────────────────────────────────────────────────────────

  Map<String, List<T>> _groupByDate<T>(
    List<T> items,
    DateTime? Function(T) getDate,
  ) {
    final Map<String, List<T>> groups = {};
    for (final item in items) {
      final date = getDate(item);
      final key = date != null ? _formatDateHeader(date) : 'Data desconhecida';
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  Widget _buildNormalGrid() {
    return FutureBuilder<List<NormalImage>>(
      future: _normalImagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('A verificar imagens no Storage...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        final images = snapshot.data ?? [];
        if (images.isEmpty) {
          return const Center(
              child: Text('Sem imagens normais para este motorista.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)));
        }

        final groups = _groupByDate<NormalImage>(
          images,
          (img) => img.timestamp,
        );

        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: groups.entries.map((entry) {
            return _buildSingleGroup<NormalImage>(
              items: entry.value,
              label: entry.key,
              builder: (img) => _buildNormalImageCard(img),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildUpscaledGrid() {
    return FutureBuilder<List<UpscaledImage>>(
      future: _upscaledImagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('A verificar imagens no Storage...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        final images = snapshot.data ?? [];
        if (images.isEmpty) {
          return const Center(
              child: Text('Sem imagens Upscaled para este motorista.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)));
        }

        final groups = _groupByDate<UpscaledImage>(
          images,
          (img) => img.timestamp,
        );

        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: groups.entries.map((entry) {
            return _buildSingleGroup<UpscaledImage>(
              items: entry.value,
              label: entry.key,
              builder: (img) => _buildUpscaledImageCard(img),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSingleGroup<T>({
    required List<T> items,
    required String label,
    required Widget Function(T) builder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: Colors.grey.shade300)),
              const SizedBox(width: 8),
              Text('${items.length}',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black38)),
            ],
          ),
        ),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => builder(items[i]),
        ),
      ],
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text('Imagens: ${widget.driverName}'),
        backgroundColor: Colors.white,
        elevation: 1,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(icon: Icon(Icons.photo_library), text: 'Fotos Normais'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Upscaled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNormalGrid(),
          _buildUpscaledGrid(),
        ],
      ),
    );
  }
}
