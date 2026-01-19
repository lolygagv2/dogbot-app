import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/robot_api.dart';
import '../../../data/models/mission.dart';
import '../../../domain/providers/connection_provider.dart';

class MissionDetailScreen extends ConsumerStatefulWidget {
  final String missionId;

  const MissionDetailScreen({super.key, required this.missionId});

  @override
  ConsumerState<MissionDetailScreen> createState() => _MissionDetailScreenState();
}

class _MissionDetailScreenState extends ConsumerState<MissionDetailScreen> {
  Mission? _mission;
  bool _loading = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadMission();
  }

  Future<void> _loadMission() async {
    if (!ref.read(connectionProvider).isConnected) return;
    try {
      final mission = await ref.read(robotApiProvider).getMission(widget.missionId);
      setState(() {
        _mission = mission;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleMission() async {
    if (_mission == null) return;
    setState(() => _starting = true);
    
    try {
      final api = ref.read(robotApiProvider);
      if (_mission!.isActive) {
        await api.stopMission(widget.missionId);
      } else {
        await api.startMission(widget.missionId);
      }
      await _loadMission();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_mission?.name ?? 'Mission')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mission == null
              ? const Center(child: Text('Mission not found'))
              : _buildContent(),
      floatingActionButton: _mission != null
          ? FloatingActionButton.extended(
              onPressed: _starting ? null : _toggleMission,
              icon: _starting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_mission!.isActive ? Icons.stop : Icons.play_arrow),
              label: Text(_mission!.isActive ? 'Stop' : 'Start'),
              backgroundColor: _mission!.isActive ? Colors.red : Colors.green,
            )
          : null,
    );
  }

  Widget _buildContent() {
    final m = _mission!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.description != null) ...[
            Text(m.description!, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
          ],
          _buildStatCard('Target Behavior', m.targetBehavior.toUpperCase(), Icons.pets),
          _buildStatCard('Hold Duration', '${m.requiredDuration}s', Icons.timer),
          _buildStatCard('Cooldown', '${m.cooldownSeconds}s between rewards', Icons.hourglass_empty),
          _buildStatCard('Daily Limit', '${m.rewardsGiven} / ${m.dailyLimit} treats', Icons.cookie),
          if (m.isActive) ...[
            const SizedBox(height: 24),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle, color: Colors.green, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mission Active', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          Text('Progress: ${(m.progress * 100).toInt()}%'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
