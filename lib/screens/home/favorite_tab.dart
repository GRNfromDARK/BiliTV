import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/video.dart';
import '../../services/bilibili_api.dart';
import '../../services/auth_service.dart';
import '../../widgets/tv_video_card.dart';
import '../../widgets/time_display.dart';
import '../../core/focus/focus_navigation.dart';
import '../player/player_screen.dart';

/// 我的收藏 Tab
///
/// 两层结构：
/// 1. 收藏夹列表 - 展示所有收藏夹（名称 + 视频数），点击进入
/// 2. 视频列表 - 展示选中收藏夹中的视频，点击播放
class FavoriteTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final bool isVisible;

  const FavoriteTab({
    super.key,
    this.sidebarFocusNode,
    this.isVisible = false,
  });

  @override
  State<FavoriteTab> createState() => FavoriteTabState();
}

class FavoriteTabState extends State<FavoriteTab> {
  // ==================== 通用状态 ====================
  bool _hasLoaded = false;
  bool _isLoading = true;

  // ==================== 收藏夹列表层 ====================
  List<Map<String, dynamic>> _folders = [];
  final Map<int, FocusNode> _folderFocusNodes = {};
  int _focusedFolderIndex = -1;
  final ScrollController _folderScrollController = ScrollController();

  // ==================== 视频列表层 ====================
  bool _showVideoList = false;
  List<Video> _videos = [];
  bool _isLoadingVideos = true;
  bool _isLoadingMore = false;
  bool _hasMoreVideos = true;
  int _currentPage = 1;
  int _currentFolderId = 0;
  String _currentFolderTitle = '';
  final ScrollController _videoScrollController = ScrollController();
  final Map<int, FocusNode> _videoFocusNodes = {};

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _loadFolders();
      _hasLoaded = true;
    }
    _videoScrollController.addListener(_onVideoScroll);
  }

  @override
  void didUpdateWidget(FavoriteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible && !_hasLoaded) {
      _loadFolders();
      _hasLoaded = true;
    }
  }

  @override
  void dispose() {
    _folderScrollController.dispose();
    _videoScrollController.removeListener(_onVideoScroll);
    _videoScrollController.dispose();
    for (final node in _folderFocusNodes.values) {
      node.dispose();
    }
    _folderFocusNodes.clear();
    for (final node in _videoFocusNodes.values) {
      node.dispose();
    }
    _videoFocusNodes.clear();
    super.dispose();
  }

  // ==================== 焦点管理 ====================

  FocusNode _getFolderFocusNode(int index) {
    return _folderFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  FocusNode _getVideoFocusNode(int index) {
    return _videoFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  // ==================== 公开方法 ====================

  /// 刷新收藏夹列表
  void refresh() {
    _hasLoaded = true;
    if (_showVideoList) {
      _loadVideos(_currentFolderId, refresh: true);
    } else {
      _loadFolders();
    }
  }

  /// 处理返回键
  /// 返回 true 表示内部已处理（从视频列表返回到收藏夹列表）
  /// 返回 false 表示当前在收藏夹列表层，未处理
  bool handleBack() {
    if (_showVideoList) {
      setState(() {
        _showVideoList = false;
        _videos = [];
        _videoFocusNodes.forEach((_, node) => node.dispose());
        _videoFocusNodes.clear();
      });
      // 恢复焦点到之前选中的收藏夹
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_focusedFolderIndex >= 0 &&
            _focusedFolderIndex < _folders.length) {
          _getFolderFocusNode(_focusedFolderIndex).requestFocus();
        }
      });
      return true;
    }
    return false;
  }

  // ==================== 数据加载 ====================

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
    });

    final folders = await BilibiliApi.getFavoriteFolders();

    if (!mounted) return;

    setState(() {
      _folders = folders;
      _isLoading = false;
    });
  }

  Future<void> _loadVideos(int folderId, {bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoadingVideos = true;
        _videos = [];
        _currentPage = 1;
        _hasMoreVideos = true;
        _currentFolderId = folderId;
      });
    }

    final result = await BilibiliApi.getFavoriteVideos(
      folderId: folderId,
      page: _currentPage,
    );

    if (!mounted) return;

    final newVideos = result['videos'] as List<Video>? ?? [];
    final hasMore = result['hasMore'] as bool? ?? false;

    setState(() {
      if (refresh) {
        _videos = newVideos;
      } else {
        final existingBvids = _videos.map((v) => v.bvid).toSet();
        final filtered =
            newVideos.where((v) => !existingBvids.contains(v.bvid)).toList();
        _videos.addAll(filtered);
      }
      _hasMoreVideos = hasMore;
      _isLoadingVideos = false;
      _isLoadingMore = false;
    });
  }

  void _onVideoScroll() {
    if (_videoScrollController.position.pixels >=
        _videoScrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMoreVideos) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadVideos(_currentFolderId);
  }

  // ==================== 交互回调 ====================

  void _onFolderSelect(int index) {
    final folder = _folders[index];
    final folderId = folder['id'] as int;
    final folderTitle = folder['title'] as String;

    setState(() {
      _showVideoList = true;
      _currentFolderId = folderId;
      _currentFolderTitle = folderTitle;
      _focusedFolderIndex = index;
    });

    _loadVideos(folderId, refresh: true);
  }

  void _onVideoTap(Video video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => PlayerScreen(video: video)),
    );
  }

  // ==================== 构建 UI ====================

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              '请先登录',
              style: TextStyle(color: Colors.white70, fontSize: 20),
            ),
            SizedBox(height: 10),
            Text(
              '登录后可查看我的收藏',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_showVideoList) {
      return _buildVideoList();
    }

    return _buildFolderList();
  }

  // ==================== 收藏夹列表 ====================

  Widget _buildFolderList() {
    if (_folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/favorite.svg',
              width: 80,
              height: 80,
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.3),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '暂无收藏夹',
              style: TextStyle(color: Colors.white70, fontSize: 20),
            ),
          ],
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomScrollView(
            controller: _folderScrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(30, 80, 30, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final folder = _folders[index];
                      final title = folder['title'] as String? ?? '';
                      final mediaCount = folder['mediaCount'] as int? ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TvFocusScope(
                          pattern: FocusPattern.vertical,
                          focusNode: _getFolderFocusNode(index),
                          autofocus: index == 0,
                          isFirst: index == 0,
                          isLast: index == _folders.length - 1,
                          onExitLeft: () =>
                              widget.sidebarFocusNode?.requestFocus(),
                          onSelect: () => _onFolderSelect(index),
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              _ensureFolderVisible(context, index);
                            }
                          },
                          child: Builder(
                            builder: (ctx) {
                              final hasFocus = Focus.of(ctx).hasFocus;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: hasFocus
                                      ? const Color(0xFFfb7299)
                                      : const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: hasFocus
                                      ? Border.all(
                                          color: Colors.white, width: 2)
                                      : null,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder_special_rounded,
                                      color: hasFocus
                                          ? Colors.white
                                          : Colors.white70,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          color: hasFocus
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 18,
                                          fontWeight: hasFocus
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '$mediaCount 个视频',
                                      style: TextStyle(
                                        color: hasFocus
                                            ? Colors.white70
                                            : Colors.white38,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right,
                                      color: hasFocus
                                          ? Colors.white70
                                          : Colors.white24,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    childCount: _folders.length,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 固定标题
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
            child: const Text(
              '我的收藏',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // 右上角时间
        const Positioned(top: 20, right: 30, child: TimeDisplay()),
      ],
    );
  }

  /// 确保被聚焦的收藏夹项在可视范围内
  void _ensureFolderVisible(BuildContext context, int index) {
    if (!_folderScrollController.hasClients) return;
    final RenderObject? object = context.findRenderObject();
    if (object != null && object is RenderBox) {
      final viewport = RenderAbstractViewport.of(object);
      final offsetToReveal =
          viewport.getOffsetToReveal(object, 0.0).offset;
      final targetOffset = (offsetToReveal - 120).clamp(
        0.0,
        _folderScrollController.position.maxScrollExtent,
      );

      if ((_folderScrollController.offset - targetOffset).abs() > 50) {
        _folderScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  // ==================== 视频列表 ====================

  Widget _buildVideoList() {
    if (_isLoadingVideos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/icons/favorite.svg',
                  width: 80,
                  height: 80,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.3),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '该收藏夹暂无视频',
                  style: TextStyle(color: Colors.white70, fontSize: 20),
                ),
              ],
            ),
          ),
          // 固定标题
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color(0xFF121212),
              padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
              child: Text(
                _currentFolderTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const Positioned(top: 20, right: 30, child: TimeDisplay()),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _videoScrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(30, 80, 30, 80),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 320 / 280,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 30,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final video = _videos[index];

                            return Builder(
                              builder: (ctx) {
                                return TvVideoCard(
                                  video: video,
                                  focusNode: _getVideoFocusNode(index),
                                  autofocus: index == 0,
                                  disableCache: false,
                                  onTap: () => _onVideoTap(video),
                                  onMoveLeft: (index % 4 == 0)
                                      ? () => widget.sidebarFocusNode
                                          ?.requestFocus()
                                      : () => _getVideoFocusNode(index - 1)
                                          .requestFocus(),
                                  onMoveRight: (index + 1 < _videos.length)
                                      ? () => _getVideoFocusNode(index + 1)
                                          .requestFocus()
                                      : null,
                                  onMoveUp: index >= 4
                                      ? () => _getVideoFocusNode(index - 4)
                                          .requestFocus()
                                      : () {}, // 最顶行阻止向上
                                  onMoveDown: (index + 4 < _videos.length)
                                      ? () => _getVideoFocusNode(index + 4)
                                          .requestFocus()
                                      : null,
                                  onFocus: () {
                                    if (!_videoScrollController.hasClients) {
                                      return;
                                    }

                                    final RenderObject? object =
                                        ctx.findRenderObject();
                                    if (object != null &&
                                        object is RenderBox) {
                                      final viewport =
                                          RenderAbstractViewport.of(object);
                                      final offsetToReveal = viewport
                                          .getOffsetToReveal(object, 0.0)
                                          .offset;
                                      final targetOffset =
                                          (offsetToReveal - 120).clamp(
                                        0.0,
                                        _videoScrollController
                                            .position.maxScrollExtent,
                                      );

                                      if ((_videoScrollController.offset -
                                                  targetOffset)
                                              .abs() >
                                          50) {
                                        _videoScrollController.animateTo(
                                          targetOffset,
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          curve: Curves.easeOutCubic,
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                            );
                          },
                          childCount: _videos.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        // 固定标题
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
            child: Text(
              _currentFolderTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // 右上角时间
        const Positioned(top: 20, right: 30, child: TimeDisplay()),
      ],
    );
  }
}
