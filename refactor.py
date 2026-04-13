import re
import sys

def modify_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Substitute the build method signature
    target_build = r"  @override\s+Widget build\(BuildContext context\) \{\s+return Scaffold\(\s+body: Row\(\s+children: \[\s+// ── Lista Lateral \(Esquerda\) ──"
    
    replacement_build = r"""  @override
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
        // ── Lista Lateral (Esquerda) ──"""
        
    content = re.sub(target_build, replacement_build, content)

    # 2. Close _buildMainDashboard()
    target_close = r"          // ── Área Principal \(Direita\) ──\s+Expanded\(\s+child: _buildRightPanel\(\),\s+\),\s+\],\s+\),\s+\);\s+\}\s+Widget _buildSectionHeader\(\{"
    
    replacement_close = r"""          // ── Área Principal (Direita) ──
          Expanded(
            child: _buildRightPanel(),
          ),
        ],
      );
  }

  Widget _buildSectionHeader({"""
  
    content = re.sub(target_close, replacement_close, content)

    # 3. Remove trips from _buildRightPanel
    target_trips = r"      case 'trips':\s+return TripsPanel\(\s+driverId: selectedDriverId!,\s+driverName: selectedDriverName \?\? 'Motorista',\s+onBack: \(\) => setState\(\(\) => currentView = 'menu'\),\s+\);\s+case 'profile':"
    replacement_trips = r"      case 'profile':"
    content = re.sub(target_trips, replacement_trips, content)

    # 4. Remove onOpenTrips from menu_panel.dart interaction
    target_menu = r"          onOpenTrips: \(\) => setState\(\(\) => currentView = 'trips'\),\s+onOpenProfile: \(\) => setState\(\(\) => currentView = 'profile'\),\s+onRevokeAuthorization: \(\) \{"
    replacement_menu = r"""          onOpenProfile: () => setState(() => currentView = 'profile'),
          onRevokeAuthorization: () {"""
    content = re.sub(target_menu, replacement_menu, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    modify_file(r'c:\Users\ttapm\backoffice_logistica\lib\screens\dashboard_screen.dart')
