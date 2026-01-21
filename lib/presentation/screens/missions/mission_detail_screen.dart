import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/mission.dart';

class MissionDetailScreen extends ConsumerStatefulWidget {
  final String missionId;

  const MissionDetailScreen({super.key, required this.missionId});

  @override
  ConsumerState<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends ConsumerState<MissionDetailScreen> {
  // TODO: Missions will be managed via WebSocket when implemented on relay
  final Mission? _mission = null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Missions not yet available', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('Coming soon via cloud relay', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
