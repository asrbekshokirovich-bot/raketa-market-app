import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import '../services/supabase_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final data = await SupabaseService.fetchAnnouncements();
    
    // Save seen status so badge disappears
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_seen_announcements_count', data.length);

    if (mounted) {
      setState(() {
        _announcements.clear();
        _announcements.addAll(data);
        _isLoading = false;
      });
    }
  }

  String _formatLocalizedDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      
      final day = int.parse(parts[2]);
      final month = int.parse(parts[1]);
      
      final months = [
        'january', 'february', 'march', 'april', 'may_month', 'june',
        'july', 'august', 'september', 'october', 'november', 'december'
      ];
      final monthName = context.watch<LocalizationProvider>().translate(months[month - 1]);
      
      return '$day $monthName';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFE5E5EA); // Telegram-like background

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          context.watch<LocalizationProvider>().translate('announcements'),
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        centerTitle: true,
      ),
      body: CustomPaint(
        painter: DoodlePainter(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.05),
        ),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00)))
            : _announcements.isEmpty 
                ? Center(
                    child: Text(
                      context.watch<LocalizationProvider>().translate('no_announcements'),
                      style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : GroupedListView<Map<String, dynamic>, String>(
                    elements: _announcements,
                    groupBy: (element) => element['date'] ?? '',
                    groupSeparatorBuilder: (String date) => Container(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _formatLocalizedDate(date),
                              style: GoogleFonts.montserrat(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context, dynamic item) => _buildMessageBubble(item, isDark),
                    useStickyGroupSeparators: true,
                    floatingHeader: true,
                    reverse: true,
                    sort: false,
                    padding: const EdgeInsets.all(12.0),
                  ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> item, bool isDark) {
    final bubbleColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final timeColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85, // max width like telegram
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 1),
                blurRadius: 2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item['type'] == 'image')
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: item['media_url'],
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00))),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
              if (item['type'] == 'video')
                const ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: _TelegramVideoPlayerPlaceholder(sizeMb: 15.6, duration: '0:45'),
                ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['content'],
                      style: GoogleFonts.rubik(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          item['timestamp'] ?? '',
                          style: GoogleFonts.montserrat(
                            color: timeColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: isDark ? Colors.blue[300] : const Color(0xFF4FA0F6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Telegram uslubidagi naqshinkor background uchun Native (kodli) chizgilar
class DoodlePainter extends CustomPainter {
  final Color color;
  DoodlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const spacing = 45.0; // Naqshlar qalinligi (zichligi)
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Pseudo-random xilma-xillik
        final r = ((x * 3) + (y * 7)) % 4; 
        double cx = x + (y % 20);
        double cy = y + (x % 20);
        
        if (r == 0) {
          // Doira (Circle)
          canvas.drawCircle(Offset(cx, cy), 3, paint);
        } else if (r == 1) {
          // X krestik (Cross)
          canvas.drawLine(Offset(cx - 3, cy - 3), Offset(cx + 3, cy + 3), paint);
          canvas.drawLine(Offset(cx + 3, cy - 3), Offset(cx - 3, cy + 3), paint);
        } else if (r == 2) {
          // Kvadrat (Square)
          canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 6), paint);
        } else {
          // Uchburchak (Triangle)
          final path = Path()
            ..moveTo(cx, cy - 4)
            ..lineTo(cx + 4, cy + 3)
            ..lineTo(cx - 4, cy + 3)
            ..close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TelegramVideoPlayerPlaceholder extends StatefulWidget {
  final double sizeMb;
  final String duration;
  const _TelegramVideoPlayerPlaceholder({super.key, required this.sizeMb, required this.duration});

  @override
  State<_TelegramVideoPlayerPlaceholder> createState() => _TelegramVideoPlayerPlaceholderState();
}

class _TelegramVideoPlayerPlaceholderState extends State<_TelegramVideoPlayerPlaceholder> {
  int _state = 0; // 0: not downloaded, 1: downloading, 2: downloaded
  double _progress = 0.0;
  Timer? _timer;
  VideoPlayerController? _controller;
  bool _isPlaying = false;

  void _handleTap() {
    if (_state == 0) {
      setState(() {
        _state = 1;
        _progress = 0.0;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _progress += 0.02; // simulating smooth download
          if (_progress >= 1.0) {
            _progress = 1.0;
            _state = 2;
            timer.cancel();
            _initPlayer(); // automatically start playing
          }
        });
      });
    } else if (_state == 1) {
      _timer?.cancel();
      setState(() {
        _state = 0;
        _progress = 0.0;
      });
    } else if (_state == 2) {
      if (_controller != null && _controller!.value.isInitialized) {
        setState(() {
          _isPlaying = !_isPlaying;
        });
        if (_isPlaying) {
          _controller!.play();
        } else {
          _controller!.pause();
        }
      }
    }
  }

  Future<void> _initPlayer() async {
    // Standard mock video: Big Buck Bunny
    _controller = VideoPlayerController.networkUrl(
      Uri.parse('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4'),
    );
    await _controller!.initialize();
    _controller!.setLooping(true);
    _controller!.addListener(() {
      if (mounted) setState(() {});
    });
    
    _controller!.play();
    setState(() {
      _isPlaying = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String topText = '${widget.sizeMb} MB';
    if (_state == 1) {
      topText = '${(_progress * widget.sizeMb).toStringAsFixed(1)} MB / ${widget.sizeMb} MB';
    } else if (_state == 2) {
      if (_controller != null && _controller!.value.isInitialized) {
        final duration = _controller!.value.duration;
        final position = _controller!.value.position;
        topText = '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')} / ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      } else {
        topText = widget.duration;
      }
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: double.infinity,
        height: 200,
        color: const Color(0xFF2C2C2C),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Player
            if (_controller != null && _controller!.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),

            // Dim overlay if not playing or paused
            if (_state < 2 || !_isPlaying)
              Container(color: Colors.black45),

            // Center Play/Download Button
            if (_state < 2 || !_isPlaying)
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_state == 1)
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    if (_state == 0)
                      const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 28),
                    if (_state == 1)
                      const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    if (_state == 2)
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ],
                ),
              ),
            
            // Top Left Info Tag
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  topText,
                  style: GoogleFonts.montserrat(
                    color: Colors.white, 
                    fontSize: 12, 
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

