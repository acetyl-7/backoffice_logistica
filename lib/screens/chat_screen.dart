import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ChatScreen extends StatefulWidget {
  final String? selectedDriverId;
  final String? selectedDriverName;
  final VoidCallback? onBack;

  const ChatScreen({
    super.key,
    this.selectedDriverId,
    this.selectedDriverName,
    this.onBack,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isUploading = false;
  Map<String, dynamic>? _replyingToMessage;

  Future<void> _sendMessage() async {
    if (widget.selectedDriverId == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      final Map<String, dynamic> messageData = {
        'text': text,
        'sender': 'hq',
        'role': 'hq',
        'type': 'text',
        'status': 'sent',
        'driverId': widget.selectedDriverId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_replyingToMessage != null) {
        messageData['replyToId'] = _replyingToMessage!['id'];
        messageData['replyToText'] = _replyingToMessage!['text'];
        messageData['replyToSender'] = _replyingToMessage!['sender'];
      }

      await FirebaseFirestore.instance.collection('messages').add(messageData);

      setState(() {
        _replyingToMessage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (widget.selectedDriverId == null) return;

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        setState(() {
          _isUploading = true;
        });

        Uint8List fileBytes = result.files.first.bytes!;
        final fileName = result.files.first.name;
        final extension = result.files.first.extension?.toLowerCase() ?? '';
        
        String type = 'document';
        if (['jpg', 'png', 'jpeg'].contains(extension)) {
          type = 'image';
        }

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_attachments/hq/${DateTime.now().millisecondsSinceEpoch}_$fileName');

        final uploadTask = storageRef.putData(fileBytes);
        final snapshot = await uploadTask.whenComplete(() {});
        final downloadUrl = await snapshot.ref.getDownloadURL();

        final Map<String, dynamic> messageData = {
          'text': fileName,
          'fileUrl': downloadUrl,
          'sender': 'hq',
          'role': 'hq',
          'type': type,
          'status': 'sent',
          'driverId': widget.selectedDriverId,
          'timestamp': FieldValue.serverTimestamp(),
        };

        if (_replyingToMessage != null) {
          messageData['replyToId'] = _replyingToMessage!['id'];
          messageData['replyToText'] = _replyingToMessage!['text'];
          messageData['replyToSender'] = _replyingToMessage!['sender'];
        }

        await FirebaseFirestore.instance.collection('messages').add(messageData);

        setState(() {
          _replyingToMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar ficheiro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (widget.selectedDriverId == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('driverId', isEqualTo: widget.selectedDriverId)
          .where('sender', isEqualTo: 'driver')
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Erro ao marcar mensagens como lidas: $e');
    }
  }

  Future<void> _showTaskAssignmentDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    // Referência ao contexto atual antes de await para evitar erros com unmounted
    final currentContext = context;

    await showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Nova Tarefa'),
          content: SingleChildScrollView(
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
                  maxLines: 3,
                ),
              ],
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

                if (title.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('O título da tarefa não pode estar vazio.')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('tasks').add({
                    'driverId': widget.selectedDriverId,
                    'title': title,
                    'description': description,
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
      },
    );
    
    titleController.dispose();
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedDriverId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Selecione um motorista na lista\npara iniciar a conversa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: Text('A falar com: ${widget.selectedDriverName ?? "Desconhecido"}'),
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
              icon: const Icon(Icons.assignment),
              label: const Text('Nova Tarefa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .where('driverId', isEqualTo: widget.selectedDriverId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('ERRO FIRESTORE (chat ${widget.selectedDriverId}): ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'Erro Firestore:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma mensagem encontrada.'),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead();
                });

                return ListView.builder(
                  reverse: true, // Auto-scroll inteligente para as mensagens recentes
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildMessageBubble(data, doc.id);
                  },
                );
              },
            ),
          ),
          
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),

          _buildInputArea(),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    final timeFormat = DateFormat('HH:mm');
    if (messageDate == today) {
      return timeFormat.format(date);
    } else if (messageDate == yesterday) {
      return 'Ontem ${timeFormat.format(date)}';
    } else {
      final dateFormat = DateFormat('dd/MM HH:mm');
      return dateFormat.format(date);
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, String docId) {
    final String role = data['role'] ?? data['sender'] ?? 'driver';
    final bool isHq = role == 'hq';

    return Align(
      alignment: isHq ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          _showContextMenu(context, details.globalPosition, data, docId);
        },
        child: Column(
          crossAxisAlignment: isHq ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 4.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isHq ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isHq ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isHq ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['replyToId'] != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: const Color(0x0D000000), // Colors.black with 5% opacity
                        borderRadius: BorderRadius.circular(8.0),
                        border: const Border(left: BorderSide(color: Colors.blueAccent, width: 4.0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['replyToSender'] == 'hq' ? 'Sede' : 'Motorista',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data['replyToText'] ?? '',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  _buildMessageContent(data, isHq),
                ],
              ),
            ),
            if (data['timestamp'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0, left: 4.0, right: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTimestamp(data['timestamp'] as Timestamp?),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (isHq) ...[
                      const SizedBox(width: 4),
                      if (data['status'] == 'read')
                        const Icon(Icons.done_all, size: 14, color: Colors.blue)
                      else if (data['status'] == 'delivered')
                        const Icon(Icons.done_all, size: 14, color: Colors.grey)
                      else
                        const Icon(Icons.check, size: 14, color: Colors.grey),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> data, bool isHq) {
    // A query móvel às vezes envia "type: null" por engano com imageUrl ou fileUrl em vez de text
    final String type = data['type'] ?? 'text';
    final String? text = data['text'];
    final String? fileUrl = data['fileUrl'] ?? data['imageUrl']; // Fallback robusto

    if (type == 'image' || (type == 'text' && fileUrl != null && fileUrl.contains('.jpg'))) {
      if (fileUrl != null) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenImageViewer(imageUrl: fileUrl),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: isHq ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  fileUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: 200,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            ),
            if (text != null && text.isNotEmpty && text != 'Documento enviado') ...[
              const SizedBox(height: 8),
              Text(
                text,
                style: const TextStyle(fontSize: 15),
              ),
            ]
          ],
        ),
        );
      }
    } else if (type == 'document') {
      return InkWell(
        onTap: () async {
          if (fileUrl != null) {
            try {
              final uri = Uri.parse(fileUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                throw 'Não foi possível abrir o link.';
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao baixar documento: $e')),
                );
              }
            }
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 32),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text?.isNotEmpty == true ? text! : 'Documento Anexo',
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download, color: Colors.grey),
          ],
        ),
      );
    } 

    return Text(
      text ?? '',
      style: const TextStyle(fontSize: 15),
    );
  }

  void _showContextMenu(BuildContext context, Offset position, Map<String, dynamic> data, String docId) {
    final String type = data['type'] ?? 'text';
    final String? fileUrl = data['fileUrl'] ?? data['imageUrl'];
    final bool hasDownload = (type == 'image' || type == 'document' || (type == 'text' && fileUrl != null && fileUrl.contains('.jpg'))) && fileUrl != null;

    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'reply',
        child: Row(
          children: [Icon(Icons.reply, size: 20), SizedBox(width: 8), Text('Responder')],
        ),
      ),
    ];

    if (hasDownload) {
      items.add(const PopupMenuDivider());
      items.add(
        const PopupMenuItem(
          value: 'download',
          child: Row(
            children: [Icon(Icons.download, size: 20), SizedBox(width: 8), Text('Download')],
          ),
        ),
      );
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: items,
    ).then((value) {
      if (value == 'reply') {
        setState(() {
          _replyingToMessage = {
            'id': docId,
            'text': type == 'document' ? (data['text'] ?? 'Documento') : (type == 'image' ? (data['text']?.isNotEmpty == true ? data['text'] : 'Imagem') : (data['text'] ?? 'Sem texto')),
            'sender': data['sender'] ?? 'driver',
            'type': type,
          };
        });
      } else if (value == 'download') {
        _downloadFile(fileUrl!);
      }
    });
  }

  Future<void> _downloadFile(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível baixar o ficheiro.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao baixar ficheiro: $e')),
        );
      }
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          if (_replyingToMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8.0),
                border: const Border(left: BorderSide(color: Colors.blueAccent, width: 4.0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A responder a ${_replyingToMessage!['sender'] == 'hq' ? 'Sede' : 'Motorista'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingToMessage!['text'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _replyingToMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.grey),
                onPressed: _pickAndUploadFile,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Digite a sua mensagem...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 14.0,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 24,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullscreenImageViewer({super.key, required this.imageUrl});

  Future<void> _downloadImage(BuildContext context) async {
    try {
      final uri = Uri.parse(imageUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível baixar a imagem.';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao baixar imagem: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadImage(context),
            tooltip: 'Download',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 100, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

