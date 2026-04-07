import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/socket_service.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../domain/webrtc_service.dart';

enum CallStatus { idle, ringing, inCall, ended }

class CallState {
  final CallStatus status;
  final bool isCaller;
  final String? remoteUserId;
  final String? remoteUserName;
  final MediaStream? remoteStream;
  final bool isMuted;

  CallState({
    this.status = CallStatus.idle,
    this.isCaller = false,
    this.remoteUserId,
    this.remoteUserName,
    this.remoteStream,
    this.isMuted = false,
  });

  CallState copyWith({
    CallStatus? status,
    bool? isCaller,
    String? remoteUserId,
    String? remoteUserName,
    MediaStream? remoteStream,
    bool? isMuted,
  }) {
    return CallState(
      status: status ?? this.status,
      isCaller: isCaller ?? this.isCaller,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      remoteUserName: remoteUserName ?? this.remoteUserName,
      remoteStream: remoteStream ?? this.remoteStream,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

class CallNotifier extends Notifier<CallState> {
  final SocketService _socketService = SocketService();
  WebRTCService? _webRTCService;

  // Storing ICE candidates received before the remote description is set
  final List<RTCIceCandidate> _remoteIceCandidatesQueue = [];

  // Used for accepting an incoming call later
  RTCSessionDescription? _incomingOffer;

  @override
  CallState build() {
    _initSocketListeners();
    
    ref.onDispose(() {
      _cleanupCall();
    });

    return CallState();
  }

  void _initSocketListeners() {
    _socketService.on('incoming-call', _handleIncomingCall);
    _socketService.on('call-answered', _handleCallAnswered);
    _socketService.on('ice-candidate', _handleIceCandidate);
    _socketService.on('call-ended', _handleCallEnded);
    _socketService.on('call-rejected', _handleCallRejected);
    _socketService.on('call-failed', _handleCallFailed);
  }

  String get _currentUserId {
    final authState = ref.read(authProvider);
    if (authState is AuthSuccess) {
      return authState.user.id;
    }
    return '';
  }

  Future<void> _setupWebRTC(String remoteId) async {
    _webRTCService = WebRTCService();
    
    _webRTCService!.onIceCandidate = (candidate) {
      _socketService.emit('ice-candidate', {
        'targetUserId': remoteId,
        'senderId': _currentUserId,
        'candidate': candidate.toMap(),
      });
    };

    _webRTCService!.onAddRemoteStream = (stream) {
      state = state.copyWith(remoteStream: stream, status: CallStatus.inCall);
    };

    _webRTCService!.onConnectionState = (connState) {
      if (connState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        state = state.copyWith(status: CallStatus.inCall);
      } else if (connState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 connState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        endCall();
      }
    };

    await _webRTCService!.initializeConnection();
  }

  // CALLED BY CALLER TO START A CALL
  Future<void> startCall(String receiverId, String receiverName) async {
    if (state.status != CallStatus.idle) return;
    
    state = CallState(
      status: CallStatus.ringing,
      isCaller: true,
      remoteUserId: receiverId,
      remoteUserName: receiverName,
    );

    try {
      await _setupWebRTC(receiverId);

      final offer = await _webRTCService!.createOffer();
      if (offer != null) {
        _socketService.emit('call-user', {
          'callerId': _currentUserId,
          'receiverId': receiverId,
          'offer': offer.toMap(),
        });
      }
    } catch (e) {
      debugPrint("Failed to start call: \$e");
      endCall();
    }
  }

  // SOCKET HANDLER: INCOMING CALL
  void _handleIncomingCall(dynamic data) {
    if (state.status != CallStatus.idle) {
      // If we are already in another call, we should ideally emit User Busy, 
      // but for parity, we ignore or reject.
      return;
    }

    final callerId = data['callerId'];
    final callerName = data['callerName'] ?? 'Seseorang';
    final offerMap = data['offer'];

    _incomingOffer = RTCSessionDescription(offerMap['sdp'], offerMap['type']);

    state = CallState(
      status: CallStatus.ringing,
      isCaller: false,
      remoteUserId: callerId,
      remoteUserName: callerName,
    );
  }

  // CALLED BY RECEIVER TO ACCEPT THE CALL
  Future<void> acceptCall() async {
    if (_incomingOffer == null || state.remoteUserId == null) return;
    final callerId = state.remoteUserId!;

    try {
      await _setupWebRTC(callerId);
      
      await _webRTCService!.setRemoteDescription(_incomingOffer!);

      final answer = await _webRTCService!.createAnswer();
      if (answer != null) {
        _socketService.emit('answer-call', {
          'callerId': callerId,
          'receiverId': _currentUserId,
          'answer': answer.toMap(),
        });
      }

      // Process any queued candidates
      for (var cand in _remoteIceCandidatesQueue) {
        await _webRTCService!.addIceCandidate(cand);
      }
      _remoteIceCandidatesQueue.clear();

    } catch (e) {
      debugPrint("Failed to accept call: \$e");
      endCall();
    }
  }

  // CALLED BY RECEIVER TO REJECT THE CALL
  void rejectCall() {
    if (state.remoteUserId != null) {
      _socketService.emit('reject-call', {
        'callerId': state.remoteUserId,
        'receiverId': _currentUserId
      });
    }
    _cleanupCall();
  }

  // SOCKET HANDLER: CALL ANSWERED
  Future<void> _handleCallAnswered(dynamic data) async {
    if (!state.isCaller || _webRTCService == null) return;

    final answerMap = data['answer'];
    try {
      await _webRTCService!.setRemoteDescription(
        RTCSessionDescription(answerMap['sdp'], answerMap['type'])
      );

      // Process any queued candidates
      for (var cand in _remoteIceCandidatesQueue) {
        await _webRTCService!.addIceCandidate(cand);
      }
      _remoteIceCandidatesQueue.clear();
      
    } catch (e) {
      debugPrint("Failed to process answer: \$e");
    }
  }

  // SOCKET HANDLER: ICE CANDIDATE
  Future<void> _handleIceCandidate(dynamic data) async {
    final candidateMap = data['candidate'];
    final candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );

    if (_webRTCService != null && state.status != CallStatus.idle) {
      // If we haven't set a remote description yet, queue it.
      // (Simplified: we queue and immediately try adding if service is ready. 
      // Safe way is to queue unless we explicitly know remoteDesc is assigned)
      try {
        await _webRTCService!.addIceCandidate(candidate);
      } catch (e) {
        _remoteIceCandidatesQueue.add(candidate);
      }
    } else {
      _remoteIceCandidatesQueue.add(candidate);
    }
  }

  // CALLED TO END THE CALL
  void endCall() {
    if (state.remoteUserId != null) {
      _socketService.emit('end-call', {
        'targetUserId': state.remoteUserId,
      });
    }
    _cleanupCall();
  }

  // SOCKET HANDLERS FOR CALL TERMINATION
  void _handleCallEnded(dynamic data) {
    _cleanupCall();
  }

  void _handleCallRejected(dynamic data) {
    _cleanupCall();
  }

  void _handleCallFailed(dynamic data) {
    _cleanupCall();
  }

  void toggleMute() {
    final newMute = !state.isMuted;
    _webRTCService?.toggleMute(newMute);
    state = state.copyWith(isMuted: newMute);
  }

  void _cleanupCall() {
    _webRTCService?.dispose();
    _webRTCService = null;
    _incomingOffer = null;
    _remoteIceCandidatesQueue.clear();
    
    state = CallState(status: CallStatus.ended);

    // Reset to idle after 2 seconds to close UI automatically
    Future.delayed(const Duration(seconds: 2), () {
      // In a Notifier, we just check if it's still active or avoid changing state if disposed
      try {
        state = CallState(status: CallStatus.idle);
      } catch (_) {}
    });
  }
}

final callProvider = NotifierProvider<CallNotifier, CallState>(() {
  return CallNotifier();
});
