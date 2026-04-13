import 'dart:io';

void main() {
  final file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();

  final buildRegex = RegExp(
      r'  @override\s+Widget build\(BuildContext context\) \{\s+return Scaffold\(\s+body: Row\(\s+children: \[\s+// ── Lista Lateral \(Esquerda\) ──');
  
  final buildReplacement = '''  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _globalSelectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _globalSelectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: const Color(0xFF0F172A),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Motoristas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: Text('Rotas'),
              ),
            ],
          ),
          Expanded(
            child: _globalSelectedIndex == 0
                ? _buildMainDashboard()
                : const TripsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDashboard() {
    return Row(
      children: [
        // ── Lista Lateral (Esquerda) ──''';

  content = content.replaceFirst(buildRegex, buildReplacement);

  final closeRegex = RegExp(
      r'          // ── Área Principal \(Direita\) ──\s+Expanded\(\s+child: _buildRightPanel\(\),\s+\),\s+\],\s+\),\s+\);\s+\}\s+Widget _buildSectionHeader\(\{');

  final closeReplacement = '''          // ── Área Principal (Direita) ──
          Expanded(
            child: _buildRightPanel(),
          ),
        ],
      );
  }

  Widget _buildSectionHeader({''';

  content = content.replaceFirst(closeRegex, closeReplacement);

  final tripsRegex = RegExp(
      r"      case 'trips':\s+return TripsPanel\(\s+driverId: selectedDriverId!,\s+driverName: selectedDriverName \?\? 'Motorista',\s+onBack: \(\) => setState\(\(\) => currentView = 'menu'\),\s+\);\s+case 'profile':");

  final tripsReplacement = "      case 'profile':";
  content = content.replaceFirst(tripsRegex, tripsReplacement);

  final menuRegex = RegExp(
      r"          onOpenTrips: \(\) => setState\(\(\) => currentView = 'trips'\),\s+onOpenProfile: \(\) => setState\(\(\) => currentView = 'profile'\),\s+onRevokeAuthorization: \(\) \{");

  final menuReplacement = '''          onOpenProfile: () => setState(() => currentView = 'profile'),
          onRevokeAuthorization: () {''';

  content = content.replaceFirst(menuRegex, menuReplacement);

  file.writeAsStringSync(content);
  print('Done!');
}
