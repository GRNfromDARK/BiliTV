import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart'; // 包含 BiliCacheManager
import '../services/update_service.dart';
import '../services/bilibili_api.dart';
import '../models/video.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  bool _showSplash = false; // 只有启用动画时才显示占位图
  Completer<void>? _videoCompleter; // 用于等待视频播放完成

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    List<Video> preloadedVideos = [];

    // 1. 初始化视频播放器 (尽早开始，与服务初始化并行)
    _videoController = VideoPlayerController.asset('assets/icons/startup.mp4');
    _videoCompleter = Completer<void>();

    final videoInitFuture = _videoController!.initialize().then((_) {
      _videoController!.setVolume(0); // 无声

      // 添加播放完成监听器
      _videoController!.addListener(_onVideoPositionChanged);

      _videoController!.play();
      if (mounted) setState(() {});
    });

    // 3. 初始化基础服务 (与视频初始化并行)
    await Future.wait([
      videoInitFuture,
      AuthService.init(),
      SettingsService.init(),
      UpdateService.init(),
    ]);

    // 检查是否禁用了启动动画
    if (!SettingsService.splashAnimationEnabled) {
      _videoController?.removeListener(_onVideoPositionChanged);
      _videoController?.dispose();
      _videoController = null;
      _showSplash = false;
      if (!_videoCompleter!.isCompleted) {
        _videoCompleter!.complete();
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, a1, a2) => const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
      }
      return;
    }

    // 启用动画，显示占位图和视频
    _showSplash = true;
    if (mounted) setState(() {});

    // 4. 异步预加载数据 (不 await，让它并行跑)
    final preloadFuture = Future(() async {
      try {
        final videos = await BilibiliApi.getRecommendVideos(idx: 0);
        preloadedVideos = videos;

        if (mounted && preloadedVideos.isNotEmpty) {
          final int count = preloadedVideos.length > 12
              ? 12
              : preloadedVideos.length;

          // 【核心修复】创建预加载任务列表
          List<Future<void>> imageTasks = [];

          for (int i = 0; i < count; i++) {
            final url = preloadedVideos[i].pic;
            if (url.isNotEmpty) {
              // 【必须完全匹配 TvVideoCard 的参数】
              // 1. maxWidth: 360
              // 2. maxHeight: 200 (原本缺失导致缓存不匹配)
              // 3. cacheManager: BiliCacheManager.instance (原本缺失导致路径不匹配)
              final imageProvider = CachedNetworkImageProvider(
                url,
                maxWidth: 360,
                maxHeight: 200,
                cacheManager: BiliCacheManager.instance,
              );

              imageTasks.add(
                precacheImage(imageProvider, context).catchError((e) {
                  debugPrint('Image preload failed: $url');
                }),
              );
            }
          }
          // 并行等待所有图片下载
          if (imageTasks.isNotEmpty) {
            await Future.wait(imageTasks);
          }
        }
      } catch (e) {
        debugPrint('Preload videos failed: $e');
      }
    });

    // 3. 等待视频真正播放完成 (而不是用 Future.delayed)
    await _videoCompleter!.future;

    // 尝试获取预加载结果 (如果预加载还没跑完，就不用等了，直接 timeout 拿空数据进主页)
    try {
      await preloadFuture.timeout(Duration.zero);
    } catch (e) {
      // 预加载未完成，忽略异常，preloadedVideos 可能是空的
    }

    if (mounted) {
      // 转场前暂停视频，防止继续播放
      _videoController?.pause();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, a1, a2) =>
              HomeScreen(preloadedVideos: preloadedVideos),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  /// 监听视频播放进度，当播放完成时触发 Completer
  void _onVideoPositionChanged() {
    final controller = _videoController;
    if (controller == null || _videoCompleter == null) return;

    final position = controller.value.position;
    final duration = controller.value.duration;

    // 当播放位置接近结尾时（允许 100ms 误差），认为播放完成
    if (duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 100) {
      if (!_videoCompleter!.isCompleted) {
        _videoCompleter!.complete();
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoPositionChanged);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SizedBox.expand(
        child: _videoController != null && _videoController!.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            : _showSplash
            ? Image.asset(
                'assets/icons/startup_frame.jpg',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
