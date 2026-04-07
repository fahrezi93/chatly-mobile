import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  // Callbacks for CallProvider
  void Function(RTCIceCandidate)? onIceCandidate;
  void Function(MediaStream)? onAddRemoteStream;
  void Function(RTCPeerConnectionState)? onConnectionState;

  Future<void> initializeConnection() async {
    // 1. Get user media (Audio Only)
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    // 2. Create peer connection
    _peerConnection = await createPeerConnection(_iceServers);

    // 3. Add local tracks to peer connection
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    }

    // 4. Listeners
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      onIceCandidate?.call(candidate);
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onAddRemoteStream?.call(_remoteStream!);
      }
    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      onConnectionState?.call(state);
    };
  }

  Future<RTCSessionDescription?> createOffer() async {
    if (_peerConnection == null) return null;
    
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(description);
  }

  Future<RTCSessionDescription?> createAnswer() async {
    if (_peerConnection == null) return null;

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) return;
    await _peerConnection!.addCandidate(candidate);
  }

  void toggleMute(bool isMuted) {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
    }
  }

  Future<void> dispose() async {
    try {
      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          track.stop();
        }
        await _localStream?.dispose();
        _localStream = null;
      }
      
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }
    } catch (e) {
      debugPrint('Error disposing WebRTCService: $e');
    }
  }

  MediaStream? get remoteStream => _remoteStream;
}
