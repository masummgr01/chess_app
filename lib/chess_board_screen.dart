import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'call_service.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

// ---------- Data models ----------

enum PieceType { pawn, rook, knight, bishop, queen, king }
enum PieceColor { white, black }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  bool hasMoved;

  ChessPiece({required this.type, required this.color, this.hasMoved = false});

  String get symbol {
    const symbols = {
      PieceType.king: {'white': '♔', 'black': '♚'},
      PieceType.queen: {'white': '♕', 'black': '♛'},
      PieceType.rook: {'white': '♖', 'black': '♜'},
      PieceType.bishop: {'white': '♗', 'black': '♝'},
      PieceType.knight: {'white': '♘', 'black': '♞'},
      PieceType.pawn: {'white': '♙', 'black': '♟'},
    };
    return symbols[type]![color == PieceColor.white ? 'white' : 'black']!;
  }
}

class Position {
  final int row;
  final int col;
  const Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

// ---------- Board screen ----------

class ChessBoardScreen extends StatefulWidget {
  const ChessBoardScreen({super.key});

  @override
  State<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends State<ChessBoardScreen> {
  late List<List<ChessPiece?>> board;
  Position? selectedPosition;
  List<Position> validMoves = [];
  PieceColor currentTurn = PieceColor.white;
  String statusMessage = "White's turn";
  bool gameOver = false;

  final _auth = AuthService();
  String? _username;

  // Call variables
  final _callService = CallService();
  bool _isInCall = false;
  int? _remoteUid;
  bool _localUserJoined = false;

  @override
  void initState() {
    super.initState();
    board = _initialBoard();
    _loadUsername();
  }

  @override
  void dispose() {
    _callService.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final name = await _auth.getUsername();
    if (mounted) setState(() => _username = name);
  }

  Future<void> _toggleCall() async {
    if (_isInCall) {
      await _callService.leaveChannel();
      setState(() {
        _isInCall = false;
        _remoteUid = null;
        _localUserJoined = false;
      });
    } else {
      setState(() => _isInCall = true);
      try {
        await _callService.init();
        
        // Listen for events
        _callService.engine.registerEventHandler(
          RtcEngineEventHandler(
            onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
              debugPrint("Local user ${connection.localUid} joined");
              setState(() => _localUserJoined = true);
            },
            onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
              debugPrint("Remote user $remoteUid joined");
              setState(() => _remoteUid = remoteUid);
            },
            onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
              debugPrint("Remote user $remoteUid left");
              setState(() => _remoteUid = null);
            },
          ),
        );

        // Join a fixed channel for demo. In a real app, use the Match ID.
        await _callService.joinChannel("chess_match_123", 0);
      } catch (e) {
        debugPrint("Error joining call: $e");
        setState(() => _isInCall = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to start call. Check Agora App ID.")),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  List<List<ChessPiece?>> _initialBoard() {
    List<List<ChessPiece?>> b = List.generate(8, (_) => List.filled(8, null));

    const backRow = [
      PieceType.rook, PieceType.knight, PieceType.bishop, PieceType.queen,
      PieceType.king, PieceType.bishop, PieceType.knight, PieceType.rook,
    ];

    for (int col = 0; col < 8; col++) {
      b[0][col] = ChessPiece(type: backRow[col], color: PieceColor.black);
      b[1][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.black);
      b[6][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.white);
      b[7][col] = ChessPiece(type: backRow[col], color: PieceColor.white);
    }
    return b;
  }

  void _onSquareTap(int row, int col) {
    if (gameOver) return;

    final tapped = Position(row, col);
    final piece = board[row][col];

    setState(() {
      if (selectedPosition == null) {
        if (piece != null && piece.color == currentTurn) {
          selectedPosition = tapped;
          validMoves = _getValidMoves(piece, tapped);
        }
      } else {
        if (validMoves.contains(tapped)) {
          _movePiece(selectedPosition!, tapped);
          selectedPosition = null;
          validMoves = [];
        } else if (piece != null && piece.color == currentTurn) {
          selectedPosition = tapped;
          validMoves = _getValidMoves(piece, tapped);
        } else {
          selectedPosition = null;
          validMoves = [];
        }
      }
    });
  }

  void _movePiece(Position from, Position to) {
    final piece = board[from.row][from.col]!;
    final capturedPiece = board[to.row][to.col];

    // Simple pawn promotion
    if (piece.type == PieceType.pawn) {
      if ((piece.color == PieceColor.white && to.row == 0) ||
          (piece.color == PieceColor.black && to.row == 7)) {
        board[to.row][to.col] = ChessPiece(type: PieceType.queen, color: piece.color);
      } else {
        board[to.row][to.col] = piece;
      }
    } else {
      board[to.row][to.col] = piece;
    }

    board[from.row][from.col] = null;
    piece.hasMoved = true;

    if (capturedPiece != null && capturedPiece.type == PieceType.king) {
      statusMessage =
      "${currentTurn == PieceColor.white ? 'White' : 'Black'} wins! Tap Restart to play again.";
      gameOver = true;
      return;
    }

    currentTurn =
    currentTurn == PieceColor.white ? PieceColor.black : PieceColor.white;
    statusMessage =
    currentTurn == PieceColor.white ? "White's turn" : "Black's turn";
  }

  bool _isInBounds(int row, int col) => row >= 0 && row < 8 && col >= 0 && col < 8;

  List<Position> _getValidMoves(ChessPiece piece, Position pos) {
    switch (piece.type) {
      case PieceType.pawn:
        return _pawnMoves(piece, pos);
      case PieceType.rook:
        return _slidingMoves(piece, pos, [[1, 0], [-1, 0], [0, 1], [0, -1]]);
      case PieceType.bishop:
        return _slidingMoves(piece, pos, [[1, 1], [1, -1], [-1, 1], [-1, -1]]);
      case PieceType.queen:
        return _slidingMoves(piece, pos, [
          [1, 0], [-1, 0], [0, 1], [0, -1],
          [1, 1], [1, -1], [-1, 1], [-1, -1],
        ]);
      case PieceType.king:
        return _kingMoves(piece, pos);
      case PieceType.knight:
        return _knightMoves(piece, pos);
    }
  }

  List<Position> _pawnMoves(ChessPiece piece, Position pos) {
    List<Position> moves = [];
    int direction = piece.color == PieceColor.white ? -1 : 1;
    int startRow = piece.color == PieceColor.white ? 6 : 1;

    int r1 = pos.row + direction;
    if (_isInBounds(r1, pos.col) && board[r1][pos.col] == null) {
      moves.add(Position(r1, pos.col));
      int r2 = pos.row + 2 * direction;
      if (pos.row == startRow && _isInBounds(r2, pos.col) && board[r2][pos.col] == null) {
        moves.add(Position(r2, pos.col));
      }
    }

    for (int dc in [-1, 1]) {
      int r = pos.row + direction;
      int c = pos.col + dc;
      if (_isInBounds(r, c)) {
        final target = board[r][c];
        if (target != null && target.color != piece.color) {
          moves.add(Position(r, c));
        }
      }
    }
    return moves;
  }

  List<Position> _slidingMoves(
      ChessPiece piece, Position pos, List<List<int>> directions) {
    List<Position> moves = [];
    for (var d in directions) {
      int r = pos.row + d[0];
      int c = pos.col + d[1];
      while (_isInBounds(r, c)) {
        final target = board[r][c];
        if (target == null) {
          moves.add(Position(r, c));
        } else {
          if (target.color != piece.color) moves.add(Position(r, c));
          break;
        }
        r += d[0];
        c += d[1];
      }
    }
    return moves;
  }

  List<Position> _knightMoves(ChessPiece piece, Position pos) {
    List<Position> moves = [];
    const offsets = [
      [2, 1], [2, -1], [-2, 1], [-2, -1],
      [1, 2], [1, -2], [-1, 2], [-1, -2],
    ];
    for (var o in offsets) {
      int r = pos.row + o[0];
      int c = pos.col + o[1];
      if (_isInBounds(r, c)) {
        final target = board[r][c];
        if (target == null || target.color != piece.color) {
          moves.add(Position(r, c));
        }
      }
    }
    return moves;
  }

  List<Position> _kingMoves(ChessPiece piece, Position pos) {
    List<Position> moves = [];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        int r = pos.row + dr;
        int c = pos.col + dc;
        if (_isInBounds(r, c)) {
          final target = board[r][c];
          if (target == null || target.color != piece.color) {
            moves.add(Position(r, c));
          }
        }
      }
    }
    return moves;
  }

  void _restart() {
    setState(() {
      board = _initialBoard();
      currentTurn = PieceColor.white;
      selectedPosition = null;
      validMoves = [];
      statusMessage = "White's turn";
      gameOver = false;
    });
  }

  Widget _buildVideoCallOverlays() {
    if (!_isInCall) return const SizedBox.shrink();

    return Stack(
      children: [
        // Opponent Video (Remote) - Small window top right
        if (_remoteUid != null)
          Positioned(
            top: 10,
            right: 10,
            width: 120,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _callService.engine,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: const RtcConnection(channelId: "chess_match_123"),
                  ),
                ),
              ),
            ),
          )
        else if (_localUserJoined)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: const Text("Waiting for opponent...", style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),

        // Your Video (Local) - Small window bottom right
        if (_localUserJoined)
          Positioned(
            bottom: 10,
            right: 10,
            width: 100,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.brown, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _callService.engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Basic Chess'),
        actions: [
          IconButton(
            icon: Icon(_isInCall ? Icons.videocam_off : Icons.videocam, color: _isInCall ? Colors.red : null),
            onPressed: _toggleCall,
            tooltip: _isInCall ? 'End Video Call' : 'Start Video Call',
          ),
          if (_username != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(_username!, style: const TextStyle(fontSize: 14)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  statusMessage,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                      itemCount: 64,
                      itemBuilder: (context, index) {
                        final row = index ~/ 8;
                        final col = index % 8;
                        final isLight = (row + col) % 2 == 0;
                        final piece = board[row][col];
                        final pos = Position(row, col);
                        final isSelected = selectedPosition == pos;
                        final isValidMove = validMoves.contains(pos);

                        return GestureDetector(
                          onTap: () => _onSquareTap(row, col),
                          child: Container(
                            color: isSelected
                                ? Colors.yellow[600]
                                : isValidMove
                                ? Colors.green[300]
                                : (isLight
                                ? const Color(0xFFEEEED2)
                                : const Color(0xFF769656)),
                            child: Center(
                              child: piece != null
                                  ? Text(piece.symbol, style: const TextStyle(fontSize: 32))
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton(
                  onPressed: _restart,
                  child: const Text('Restart Game'),
                ),
              ),
            ],
          ),
          _buildVideoCallOverlays(),
        ],
      ),
    );
  }
}
