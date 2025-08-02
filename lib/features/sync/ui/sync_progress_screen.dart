import 'dart:async';
import 'package:flutter/material.dart';

import '../models/sync_models.dart';
import '../services/p2p_sync_service.dart';

/// Screen showing sync progress and allowing cancellation
class SyncProgressScreen extends StatefulWidget {
  final SyncSession session;
  final P2PSyncService syncService;

  const SyncProgressScreen({
    super.key,
    required this.session,
    required this.syncService,
  });

  @override
  State<SyncProgressScreen> createState() => _SyncProgressScreenState();
}

class _SyncProgressScreenState extends State<SyncProgressScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  
  SyncSession? _currentSession;
  SyncProgress? _currentProgress;
  List<SyncConflict> _conflicts = [];
  
  StreamSubscription<SyncSession>? _sessionSubscription;
  StreamSubscription<SyncProgress>? _progressSubscription;
  
  bool _showDetails = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    _currentSession = widget.session;
    
    // Initialize animations
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeInOut),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    
    // Set up listeners
    _sessionSubscription = widget.syncService.syncSessionUpdates.listen(_onSessionUpdate);
    _progressSubscription = widget.syncService.syncProgressUpdates.listen(_onProgressUpdate);
    
    // Start pulse animation for active sync
    if (_currentSession?.state == SyncSessionState.active) {
      _pulseAnimationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    _sessionSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _onSessionUpdate(SyncSession session) {
    if (session.sessionId == widget.session.sessionId) {
      setState(() {
        _currentSession = session;
        _conflicts = session.conflicts;
        
        if (session.state == SyncSessionState.completed) {
          _pulseAnimationController.stop();
          _showCompletionAnimation();
        } else if (session.state == SyncSessionState.failed || 
                   session.state == SyncSessionState.cancelled) {
          _pulseAnimationController.stop();
          _errorMessage = session.errorMessage ?? 'Sync ${session.state.name}';
        }
      });
    }
  }

  void _onProgressUpdate(SyncProgress progress) {
    setState(() {
      _currentProgress = progress;
    });
    
    // Animate progress bar
    final targetProgress = progress.progressPercentage / 100.0;
    _progressAnimationController.animateTo(targetProgress);
  }

  void _showCompletionAnimation() {
    _progressAnimationController.animateTo(1.0).then((_) {
      // Show completion for a moment, then return
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    });
  }

  Future<void> _cancelSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Sync'),
        content: const Text('Are you sure you want to cancel the sync operation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await widget.syncService.cancelSyncSession(widget.session.sessionId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel sync: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _currentSession!;
    final progress = _currentProgress ?? session.progress;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Progress'),
        automaticallyImplyLeading: false,
        actions: [
          if (session.state == SyncSessionState.active)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _cancelSync,
              tooltip: 'Cancel Sync',
            ),
          if (session.state == SyncSessionState.completed ||
              session.state == SyncSessionState.failed ||
              session.state == SyncSessionState.cancelled)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Sync status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Status icon and title
                    Row(
                      children: [
                        _buildStatusIcon(session.state),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStatusTitle(session.state),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '${session.participantDeviceIds.length} devices',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Progress bar
                    if (session.state == SyncSessionState.active) ...[
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            value: _progressAnimation.value,
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${progress.progressPercentage.toInt()}% complete',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ] else if (session.state == SyncSessionState.completed) ...[
                      LinearProgressIndicator(
                        value: 1.0,
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                      const SizedBox(height: 8),
                      const Text('100% complete'),
                    ],
                    
                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Progress details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progress Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: Icon(_showDetails ? Icons.expand_less : Icons.expand_more),
                          onPressed: () {
                            setState(() {
                              _showDetails = !_showDetails;
                            });
                          },
                        ),
                      ],
                    ),
                    
                    if (_showDetails) ...[
                      const Divider(),
                      _buildProgressDetailsContent(progress),
                    ] else ...[
                      const SizedBox(height: 8),
                      _buildProgressSummary(progress),
                    ],
                  ],
                ),
              ),
            ),
            
            // Conflicts section
            if (_conflicts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Conflicts Detected (${_conflicts.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._conflicts.take(3).map((conflict) {
                        return ListTile(
                          leading: const Icon(Icons.conflict),
                          title: Text('${conflict.itemType}: ${conflict.itemId}'),
                          subtitle: Text(conflict.type.name),
                          dense: true,
                        );
                      }),
                      if (_conflicts.length > 3)
                        TextButton(
                          onPressed: _showAllConflicts,
                          child: Text('View all ${_conflicts.length} conflicts'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            
            const Spacer(),
            
            // Current operation
            if (session.state == SyncSessionState.active) ...[
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              progress.currentOperation,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(SyncSessionState state) {
    switch (state) {
      case SyncSessionState.initializing:
        return const CircularProgressIndicator();
      case SyncSessionState.active:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: const Icon(Icons.sync, color: Colors.blue, size: 32),
            );
          },
        );
      case SyncSessionState.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 32);
      case SyncSessionState.failed:
        return const Icon(Icons.error, color: Colors.red, size: 32);
      case SyncSessionState.cancelled:
        return const Icon(Icons.cancel, color: Colors.orange, size: 32);
      default:
        return const Icon(Icons.help, size: 32);
    }
  }

  String _getStatusTitle(SyncSessionState state) {
    switch (state) {
      case SyncSessionState.initializing:
        return 'Initializing Sync...';
      case SyncSessionState.active:
        return 'Syncing Data';
      case SyncSessionState.completed:
        return 'Sync Completed';
      case SyncSessionState.failed:
        return 'Sync Failed';
      case SyncSessionState.cancelled:
        return 'Sync Cancelled';
      default:
        return 'Unknown Status';
    }
  }

  Widget _buildProgressSummary(SyncProgress progress) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('Total', progress.totalItems.toString()),
        _buildStatItem('Processed', progress.processedItems.toString()),
        _buildStatItem('Successful', progress.successfulItems.toString()),
        if (progress.failedItems > 0)
          _buildStatItem('Failed', progress.failedItems.toString(), Colors.red),
      ],
    );
  }

  Widget _buildProgressDetailsContent(SyncProgress progress) {
    return Column(
      children: [
        _buildDetailRow('Total Items', progress.totalItems.toString()),
        _buildDetailRow('Processed', progress.processedItems.toString()),
        _buildDetailRow('Successful', progress.successfulItems.toString()),
        _buildDetailRow('Failed', progress.failedItems.toString()),
        _buildDetailRow('Skipped', progress.skippedItems.toString()),
        const Divider(),
        _buildDetailRow('Bytes Transferred', _formatBytes(progress.bytesTransferred)),
        _buildDetailRow('Total Bytes', _formatBytes(progress.totalBytes)),
        if (progress.estimatedCompletion != null)
          _buildDetailRow('ETA', _formatDuration(
            progress.estimatedCompletion!.difference(DateTime.now())
          )),
        
        // Items by type
        if (progress.itemsByType.isNotEmpty) ...[
          const Divider(),
          const Text('Items by Type:', style: TextStyle(fontWeight: FontWeight.w500)),
          ...progress.itemsByType.entries.map((entry) {
            return _buildDetailRow(entry.key, entry.value.toString());
          }),
        ],
      ],
    );
  }

  Widget _buildStatItem(String label, String value, [Color? color]) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showAllConflicts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sync Conflicts (${_conflicts.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _conflicts.length,
            itemBuilder: (context, index) {
              final conflict = _conflicts[index];
              return ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: Text('${conflict.itemType}: ${conflict.itemId}'),
                subtitle: Text('${conflict.type.name}\nLocal: ${conflict.localModified}\nRemote: ${conflict.remoteModified}'),
                isThreeLine: true,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) return '${duration.inSeconds}s';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
}