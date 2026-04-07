import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverAuthorizationPanel extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> driverData;

  const DriverAuthorizationPanel({
    super.key,
    required this.driverId,
    required this.driverData,
  });

  @override
  State<DriverAuthorizationPanel> createState() =>
      _DriverAuthorizationPanelState();
}

class _DriverAuthorizationPanelState extends State<DriverAuthorizationPanel> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _nomeController;
  late TextEditingController _emailController;
  late TextEditingController _telefoneController;
  late TextEditingController _matriculaController;
  late TextEditingController _empresaController;

  @override
  void initState() {
    super.initState();
    final data = widget.driverData;
    
    final emailVal = data['email']?.toString() ?? '';
    final String initialEmail = (emailVal.trim().isEmpty) ? 'Aguardando Sincronização' : emailVal;

    _nomeController =
        TextEditingController(text: data['name']?.toString() ?? data['nome']?.toString() ?? '');
    _emailController =
        TextEditingController(text: initialEmail);
    _telefoneController =
        TextEditingController(text: data['phone']?.toString() ?? data['telefone']?.toString() ?? '');
    _matriculaController =
        TextEditingController(text: data['matricula']?.toString() ?? '');
    _empresaController =
        TextEditingController(text: data['company']?.toString() ?? data['empresa']?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant DriverAuthorizationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driverId != widget.driverId) {
      final data = widget.driverData;
      final emailVal = data['email']?.toString() ?? '';
      final String initialEmail = (emailVal.trim().isEmpty) ? 'Aguardando Sincronização' : emailVal;

      _nomeController.text = data['name']?.toString() ?? data['nome']?.toString() ?? '';
      _emailController.text = initialEmail;
      _telefoneController.text = data['phone']?.toString() ?? data['telefone']?.toString() ?? '';
      _matriculaController.text = data['matricula']?.toString() ?? '';
      _empresaController.text = data['company']?.toString() ?? data['empresa']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _matriculaController.dispose();
    _empresaController.dispose();
    super.dispose();
  }

  Future<void> _authorizeDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Encontrar o documento pelo uid ou pelo id do documento
      final uid = widget.driverData['uid']?.toString() ?? widget.driverId;

      // Tentar encontrar o documento por uid
      QuerySnapshot querySnap = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      DocumentReference docRef;
      if (querySnap.docs.isNotEmpty) {
        docRef = querySnap.docs.first.reference;
      } else {
        // Fallback: usar o driverId como document ID
        docRef =
            FirebaseFirestore.instance.collection('users').doc(widget.driverId);
      }

      final emailToSave = _emailController.text.trim();

      await docRef.update({
        'name': _nomeController.text.trim(),
        'nome': _nomeController.text.trim(), // Para efeitos de legibilidade e sistemas antigos
        'email': emailToSave == 'Aguardando Sincronização' ? '' : emailToSave,
        'phone': _telefoneController.text.trim(),
        'telefone': _telefoneController.text.trim(), // Para sistemas antigos
        'matricula': _matriculaController.text.trim(),
        'company': _empresaController.text.trim(),
        'empresa': _empresaController.text.trim(), // Para sistemas antigos
        'isAuthorized': true,
      });

      final bool wasAlreadyAuthorized = widget.driverData['isAuthorized'] == true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                    wasAlreadyAuthorized 
                      ? 'Dados atualizados com sucesso!'
                      : '${_nomeController.text.trim()} foi autorizado com sucesso!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Erro ao autorizar motorista: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.driverData['photoUrl']?.toString();
    final isAuthorized = widget.driverData['isAuthorized'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isAuthorized ? 'Perfil do Motorista' : 'Perfil do Motorista — Por Autorizar'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 1,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isAuthorized ? Colors.green.shade100 : Colors.amber.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isAuthorized ? Colors.green.shade400 : Colors.amber.shade400),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAuthorized ? Icons.check_circle : Icons.pending_actions,
                  size: 16, 
                  color: isAuthorized ? Colors.green.shade800 : Colors.amber.shade800
                ),
                const SizedBox(width: 6),
                Text(
                  isAuthorized ? 'Motorista Autorizado' : 'Pendente de Autorização',
                  style: TextStyle(
                    color: isAuthorized ? Colors.green.shade800 : Colors.amber.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar + Cabeçalho ──
                Row(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.blueGrey.shade100,
                      backgroundImage:
                          (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Icon(Icons.person,
                              size: 48, color: Colors.blueGrey.shade400)
                          : null,
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.driverData['nome']?.toString() ?? 'Sem Nome',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Registo recebido da aplicação móvel',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                _buildSectionHeader('Dados de Identificação'),
                const SizedBox(height: 16),

                // Formulário
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: 'Nome Completo',
                              controller: _nomeController,
                              icon: Icons.person_outline,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Campo obrigatório'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildField(
                              label: 'E-mail',
                              controller: _emailController,
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              style: _emailController.text == 'Aguardando Sincronização'
                                  ? TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              label: 'Telefone',
                              controller: _telefoneController,
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildField(
                              label: 'Matrícula',
                              controller: _matriculaController,
                              icon: Icons.directions_car_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader('Dados Operacionais'),
                      const SizedBox(height: 16),

                      // Campo Empresa — obrigatório
                      _buildField(
                        label: 'Empresa',
                        controller: _empresaController,
                        icon: Icons.business_outlined,
                        hint: 'Introduza o nome da empresa do motorista',
                        isRequired: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'O campo Empresa é obrigatório para autorizar'
                            : null,
                      ),

                      const SizedBox(height: 40),

                      // ── Botão de Autorização ou Gravar Alterações ──
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _authorizeDriver,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(isAuthorized ? Icons.save : Icons.verified_user_outlined,
                                  size: 22),
                          label: Text(
                            _isSaving 
                                ? (isAuthorized ? 'A guardar...' : 'A autorizar...') 
                                : (isAuthorized ? 'Guardar Alterações' : 'Autorizar Motorista'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                Colors.green.shade200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),

                      if (!isAuthorized) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Ao autorizar, o motorista terá acesso total à aplicação.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Divider(color: Colors.grey.shade200, thickness: 1.5),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    String? Function(String?)? validator,
    TextStyle? style,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: style,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey.shade400),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF1E293B), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
      ),
    );
  }
}
