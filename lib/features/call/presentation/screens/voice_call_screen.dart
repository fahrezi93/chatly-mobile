import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/call_provider.dart';

class VoiceCallScreen extends ConsumerWidget {
  const VoiceCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);

    // If call ended, maybe pop back.
    // The provider automatically resets to idle after 2s of ended status.
    // We could handle Navigator pop here if it becomes idle or ended.
    ref.listen<CallState>(callProvider, (previous, next) {
      if (next.status == CallStatus.idle && previous?.status != CallStatus.idle) {
        // Only pop if currently open
        if (Navigator.of(context).canPop()) {
           Navigator.of(context).pop();
        }
      }
    });

    final String name = callState.remoteUserName ?? 'Unknown';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Avatar
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Name
            Text(
              name,
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Call Status text
            Text(
              _getStatusText(callState),
              style: TextStyle(
                fontSize: 16,
                color: callState.status == CallStatus.inCall 
                    ? Colors.greenAccent 
                    : Colors.white70,
              ),
            ),
            const Spacer(),
            
            // Buttons
            _buildControls(context, ref, callState),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  String _getStatusText(CallState state) {
    switch (state.status) {
      case CallStatus.idle:
        return 'Connecting...';
      case CallStatus.ringing:
        return state.isCaller ? 'Memanggil...' : 'Panggilan Masuk...';
      case CallStatus.inCall:
        return 'Connected'; // Ideally show duration here
      case CallStatus.ended:
        return 'Panggilan Berakhir';
    }
  }

  Widget _buildControls(BuildContext context, WidgetRef ref, CallState state) {
    if (state.status == CallStatus.ringing && !state.isCaller) {
      // Incoming call controls
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end, color: Colors.white, size: 30),
            onPressed: () => ref.read(callProvider.notifier).rejectCall(),
          ),
          FloatingActionButton(
            backgroundColor: Colors.green,
            child: const Icon(Icons.call, color: Colors.white, size: 30),
            onPressed: () => ref.read(callProvider.notifier).acceptCall(),
          ),
        ],
      );
    } 
    
    // Ongoing call or outgoing call ringing
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FloatingActionButton(
          backgroundColor: state.isMuted ? Colors.white : Colors.white24,
          child: Icon(
            state.isMuted ? Icons.mic_off : Icons.mic, 
            color: state.isMuted ? Colors.black : Colors.white,
          ),
          onPressed: () => ref.read(callProvider.notifier).toggleMute(),
        ),
        FloatingActionButton(
          backgroundColor: Colors.red,
          child: const Icon(Icons.call_end, color: Colors.white, size: 30),
          onPressed: () => ref.read(callProvider.notifier).endCall(),
        ),
      ],
    );
  }
}
