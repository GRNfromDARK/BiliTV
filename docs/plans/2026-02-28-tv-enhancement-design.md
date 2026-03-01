# BiliTV 增量改造 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在现有 BiliTV Flutter 项目上新增"我的关注"和"我的收藏"两个 Tab，将"我的关注"设为默认首页。

**Architecture:** 保留所有现有功能不动，新增两个 Tab 页面和对应的 API 方法。"我的关注"复用现有动态 API（已返回按时间排序的关注者视频）。"我的收藏"需要新增两个 API（收藏夹列表 + 收藏夹内容）。

**Tech Stack:** Flutter/Dart, Bilibili Web API, Compose TV-style focus navigation

---

## Task 1: 新增"我的关注" Tab 页面文件

**Files:**
- Create: `lib/screens/home/following_tab.dart`

**Step 1: 创建 following_tab.dart**

复制 `lib/screens/home/dynamic_tab.dart` 的完整模式，修改标题和 API 调用。"我的关注"的数据源与"动态"完全相同（`BilibiliApi.getDynamicFeed`），因为该 API 已经返回关注者的视频并按时间排序。

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/video.dart';
import '../../services/bilibili_api.dart';
import 'package:keframe/keframe.dart';
import '../../services/auth_service.dart';
import '../../widgets/tv_video_card.dart';
import '../../widgets/time_display.dart';
import '../player/player_screen.dart';

/// 我的关注 Tab - 展示所有关注 UP主 的视频，按发布时间倒序
class FollowingTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final bool isVisible;
  final VoidCallback? onFirstLoadComplete;

  const FollowingTab({
    super.key,
    this.sidebarFocusNode,
    this.isVisible = false,
    this.onFirstLoadComplete,
  });

  @override
  State<FollowingTab> createState() => FollowingTabState();
}

class FollowingTabState extends State<FollowingTab> {
  List<Video> _videos = [];
  bool _isLoading = true;
  String _offset = '';
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  bool _isRefreshing = false;
  final Map<int, FocusNode> _videoFocusNodes = {};
  bool _firstLoadNotified = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _loadFollowing(refresh: true);
      _hasLoaded = true;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(FollowingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible && !_hasLoaded) {
      _loadFollowing(refresh: true);
      _hasLoaded = true;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (final node in _videoFocusNodes.values) {
      node.dispose();
    }
    _videoFocusNodes.clear();
    super.dispose();
  }

  FocusNode _getFocusNode(int index) {
    return _videoFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// 公开的刷新方法
  void refresh() {
    _hasLoaded = true;
    _loadFollowing(refresh: true);
  }

  Future<void> _loadFollowing({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _isRefreshing = true;
        _videos = [];
        _offset = '';
        _hasMore = true;
      });
    }

    if (!_hasMore && !refresh) return;

    // 复用动态 API - 它返回关注者视频并按时间排序
    final feed = await BilibiliApi.getDynamicFeed(
      offset: refresh ? '' : _offset,
    );

    if (!mounted) return;

    setState(() {
      if (refresh) {
        _videos = feed.videos;
      } else {
        final existingBvids = _videos.map((v) => v.bvid).toSet();
        final newVideos = feed.videos
            .where((v) => !existingBvids.contains(v.bvid))
            .toList();
        _videos.addAll(newVideos);
      }
      _offset = feed.offset;
      _hasMore = feed.hasMore;
      _isLoading = false;
      _isLoadingMore = false;
      _isRefreshing = false;
    });

    // 首次加载完成回调
    if (!_firstLoadNotified && _videos.isNotEmpty) {
      _firstLoadNotified = true;
      widget.onFirstLoadComplete?.call();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _loadFollowing(refresh: false);
  }

  void _onVideoTap(Video video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => PlayerScreen(video: video)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('请先登录',
                style: TextStyle(color: Colors.white70, fontSize: 20)),
            const SizedBox(height: 10),
            const Text('登录后可查看关注的 UP主 视频',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/icons/dynamic.svg',
                width: 80, height: 80,
                colorFilter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.3), BlendMode.srcIn)),
            const SizedBox(height: 20),
            const Text('暂无关注内容',
                style: TextStyle(color: Colors.white70, fontSize: 20)),
          ],
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: SizeCacheWidget(
                  child: CustomScrollView(
                    controller: _scrollController,
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
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final video = _videos[index];

                            Widget buildCard(BuildContext ctx) {
                              return TvVideoCard(
                                video: video,
                                focusNode: _getFocusNode(index),
                                disableCache: false,
                                onTap: () => _onVideoTap(video),
                                onMoveLeft: (index % 4 == 0)
                                    ? () => widget.sidebarFocusNode?.requestFocus()
                                    : () => _getFocusNode(index - 1).requestFocus(),
                                onMoveRight: (index + 1 < _videos.length)
                                    ? () => _getFocusNode(index + 1).requestFocus()
                                    : null,
                                onMoveUp: index >= 4
                                    ? () => _getFocusNode(index - 4).requestFocus()
                                    : () {},
                                onMoveDown: (index + 4 < _videos.length)
                                    ? () => _getFocusNode(index + 4).requestFocus()
                                    : null,
                                onFocus: () {
                                  if (!_scrollController.hasClients) return;
                                  final RenderObject? object =
                                      ctx.findRenderObject();
                                  if (object != null && object is RenderBox) {
                                    final viewport =
                                        RenderAbstractViewport.of(object);
                                    final offsetToReveal = viewport
                                        .getOffsetToReveal(object, 0.0)
                                        .offset;
                                    final targetOffset =
                                        (offsetToReveal - 120).clamp(0.0,
                                            _scrollController.position.maxScrollExtent);
                                    if ((_scrollController.offset - targetOffset).abs() > 50) {
                                      _scrollController.animateTo(targetOffset,
                                          duration: const Duration(milliseconds: 500),
                                          curve: Curves.easeOutCubic);
                                    }
                                  }
                                },
                              );
                            }

                            if (_isRefreshing) {
                              return FrameSeparateWidget(
                                index: index,
                                placeHolder: const Center(
                                    child: SizedBox(width: 30, height: 30,
                                        child: CircularProgressIndicator(strokeWidth: 2))),
                                child: Builder(builder: buildCard),
                              );
                            }
                            return Builder(builder: buildCard);
                          }, childCount: _videos.length),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoadingMore)
                const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        // 固定标题
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
            child: const Text('我的关注',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
        const Positioned(top: 20, right: 30, child: TimeDisplay()),
      ],
    );
  }
}
```

**Step 2: 验证文件语法**

Run: `cd /Users/rex/Documents/Program2026/BiliTV && dart analyze lib/screens/home/following_tab.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/home/following_tab.dart
git commit -m "feat: add FollowingTab - 我的关注视频列表页面"
```

---

## Task 2: 新增收藏夹 API 方法

**Files:**
- Modify: `lib/services/api/interaction_api.dart` (在文件末尾 class 结束前添加)
- Modify: `lib/services/bilibili_api.dart` (添加门面方法)

**Step 1: 在 interaction_api.dart 中新增 API 方法**

在 `InteractionApi` class 内（`checkFollowStatus` 方法之后，class 结束 `}` 之前）添加两个新方法：

```dart
  /// 获取用户所有收藏夹列表
  static Future<List<Map<String, dynamic>>> getFavoriteFolders() async {
    if (!AuthService.isLoggedIn) return [];
    try {
      final mid = AuthService.mid;
      if (mid == null) return [];

      final uri = Uri.parse(
        '${BaseApi.apiBase}/x/v3/fav/folder/created/list-all',
      ).replace(queryParameters: {'up_mid': mid.toString()});
      final response = await http.get(
        uri,
        headers: BaseApi.getHeaders(withCookie: true),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0 && json['data'] != null) {
          final list = json['data']['list'] as List? ?? [];
          return list.map((item) => {
            'id': item['id'] ?? 0,
            'title': item['title'] ?? '',
            'mediaCount': item['media_count'] ?? 0,
          }).toList();
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return [];
  }

  /// 获取收藏夹内的视频列表
  static Future<Map<String, dynamic>> getFavoriteVideos({
    required int folderId,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (!AuthService.isLoggedIn) return {'videos': <Video>[], 'hasMore': false};
    try {
      final uri = Uri.parse(
        '${BaseApi.apiBase}/x/v3/fav/resource/list',
      ).replace(queryParameters: {
        'media_id': folderId.toString(),
        'pn': page.toString(),
        'ps': pageSize.toString(),
        'order': 'mtime',
        'platform': 'web',
      });
      final response = await http.get(
        uri,
        headers: BaseApi.getHeaders(withCookie: true),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0 && json['data'] != null) {
          final data = json['data'];
          final medias = data['medias'] as List? ?? [];
          final hasMore = data['has_more'] as bool? ?? false;

          final videos = <Video>[];
          for (final item in medias) {
            try {
              final upper = item['upper'] as Map<String, dynamic>? ?? {};
              final cntInfo = item['cnt_info'] as Map<String, dynamic>? ?? {};
              videos.add(Video(
                bvid: item['bvid'] ?? '',
                title: item['title'] ?? '',
                pic: BaseApi.fixPicUrl(item['cover'] ?? ''),
                ownerName: upper['name'] ?? '',
                ownerFace: BaseApi.fixPicUrl(upper['face'] ?? ''),
                ownerMid: upper['mid'] ?? 0,
                view: BaseApi.toInt(cntInfo['play']),
                danmaku: BaseApi.toInt(cntInfo['danmaku']),
                duration: item['duration'] ?? 0,
                pubdate: item['pubtime'] ?? 0,
              ));
            } catch (e) {
              continue;
            }
          }

          return {'videos': videos, 'hasMore': hasMore};
        }
      }
    } catch (e) {
      // 忽略错误
    }
    return {'videos': <Video>[], 'hasMore': false};
  }
```

注意：需要在 `interaction_api.dart` 顶部添加 import：
```dart
import '../../models/video.dart';
```

**Step 2: 在 bilibili_api.dart 添加门面方法**

在 `BilibiliApi` class 中"用户操作相关"部分末尾添加：

```dart
  /// 获取用户收藏夹列表
  static Future<List<Map<String, dynamic>>> getFavoriteFolders() =>
      InteractionApi.getFavoriteFolders();

  /// 获取收藏夹内视频
  static Future<Map<String, dynamic>> getFavoriteVideos({
    required int folderId,
    int page = 1,
    int pageSize = 20,
  }) => InteractionApi.getFavoriteVideos(
    folderId: folderId, page: page, pageSize: pageSize,
  );
```

**Step 3: 验证**

Run: `cd /Users/rex/Documents/Program2026/BiliTV && dart analyze lib/services/`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/services/api/interaction_api.dart lib/services/bilibili_api.dart
git commit -m "feat: add favorite folders & videos API endpoints"
```

---

## Task 3: 新增"我的收藏" Tab 页面文件

**Files:**
- Create: `lib/screens/home/favorite_tab.dart`

**Step 1: 创建 favorite_tab.dart**

收藏 Tab 有两层：收藏夹列表 → 收藏夹内视频列表。使用内部状态切换两层。

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/video.dart';
import '../../services/bilibili_api.dart';
import 'package:keframe/keframe.dart';
import '../../services/auth_service.dart';
import '../../widgets/tv_video_card.dart';
import '../../widgets/time_display.dart';
import '../../core/focus/focus_navigation.dart';
import '../player/player_screen.dart';

/// 我的收藏 Tab - B站云端收藏夹浏览
class FavoriteTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final bool isVisible;

  const FavoriteTab({super.key, this.sidebarFocusNode, this.isVisible = false});

  @override
  State<FavoriteTab> createState() => FavoriteTabState();
}

class FavoriteTabState extends State<FavoriteTab> {
  // 收藏夹列表层
  List<Map<String, dynamic>> _folders = [];
  bool _isFoldersLoading = true;
  final Map<int, FocusNode> _folderFocusNodes = {};

  // 视频列表层
  int? _selectedFolderId;
  String _selectedFolderTitle = '';
  List<Video> _videos = [];
  bool _isVideosLoading = false;
  int _videoPage = 1;
  bool _hasMoreVideos = true;
  bool _isLoadingMore = false;
  final ScrollController _videoScrollController = ScrollController();
  final Map<int, FocusNode> _videoFocusNodes = {};

  bool _hasLoaded = false;

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
    _videoScrollController.removeListener(_onVideoScroll);
    _videoScrollController.dispose();
    for (final node in _folderFocusNodes.values) node.dispose();
    for (final node in _videoFocusNodes.values) node.dispose();
    super.dispose();
  }

  FocusNode _getFolderFocusNode(int index) {
    return _folderFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  FocusNode _getVideoFocusNode(int index) {
    return _videoFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  void refresh() {
    _hasLoaded = true;
    if (_selectedFolderId != null) {
      _loadVideos(_selectedFolderId!, _selectedFolderTitle, refresh: true);
    } else {
      _loadFolders();
    }
  }

  /// 处理返回键 - 从视频列表返回到收藏夹列表
  bool handleBack() {
    if (_selectedFolderId != null) {
      setState(() {
        _selectedFolderId = null;
        _videos = [];
        _videoPage = 1;
        _hasMoreVideos = true;
      });
      return true;
    }
    return false;
  }

  Future<void> _loadFolders() async {
    setState(() => _isFoldersLoading = true);
    final folders = await BilibiliApi.getFavoriteFolders();
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _isFoldersLoading = false;
    });
  }

  Future<void> _loadVideos(int folderId, String title, {bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _selectedFolderId = folderId;
        _selectedFolderTitle = title;
        _isVideosLoading = true;
        _videos = [];
        _videoPage = 1;
        _hasMoreVideos = true;
      });
    }

    final result = await BilibiliApi.getFavoriteVideos(
      folderId: folderId,
      page: refresh ? 1 : _videoPage,
    );

    if (!mounted) return;

    final newVideos = result['videos'] as List<Video>;
    setState(() {
      if (refresh) {
        _videos = newVideos;
      } else {
        final existingBvids = _videos.map((v) => v.bvid).toSet();
        _videos.addAll(newVideos.where((v) => !existingBvids.contains(v.bvid)));
      }
      _hasMoreVideos = result['hasMore'] as bool;
      _isVideosLoading = false;
      _isLoadingMore = false;
      if (!refresh) _videoPage++;
    });
  }

  void _onVideoScroll() {
    if (_videoScrollController.position.pixels >=
        _videoScrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMoreVideos || _selectedFolderId == null) return;
    setState(() {
      _isLoadingMore = true;
      _videoPage++;
    });
    await _loadVideos(_selectedFolderId!, _selectedFolderTitle);
  }

  void _onVideoTap(Video video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => PlayerScreen(video: video)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('请先登录',
                style: TextStyle(color: Colors.white70, fontSize: 20)),
            const SizedBox(height: 10),
            const Text('登录后可浏览收藏夹',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }

    if (_selectedFolderId != null) {
      return _buildVideoList();
    }
    return _buildFolderList();
  }

  /// 收藏夹列表
  Widget _buildFolderList() {
    if (_isFoldersLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/icons/favorite.svg',
                width: 80, height: 80,
                colorFilter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.3), BlendMode.srcIn)),
            const SizedBox(height: 20),
            const Text('暂无收藏夹',
                style: TextStyle(color: Colors.white70, fontSize: 20)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 80, 30, 30),
            child: ListView.builder(
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];
                return TvFocusScope(
                  pattern: FocusPattern.vertical,
                  focusNode: _getFolderFocusNode(index),
                  autofocus: index == 0,
                  onSelect: () => _loadVideos(folder['id'], folder['title'], refresh: true),
                  onExitLeft: () => widget.sidebarFocusNode?.requestFocus(),
                  child: Builder(builder: (ctx) {
                    final focused = Focus.of(ctx).hasFocus;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: focused ? const Color(0xFFfb7299) : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: focused ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                      child: Row(
                        children: [
                          SvgPicture.asset('assets/icons/favorite.svg',
                              width: 24, height: 24,
                              colorFilter: ColorFilter.mode(
                                  focused ? Colors.white : Colors.white54, BlendMode.srcIn)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(folder['title'],
                                style: TextStyle(
                                    color: focused ? Colors.white : Colors.white70,
                                    fontSize: 18, fontWeight: FontWeight.w500)),
                          ),
                          Text('${folder['mediaCount']} 个视频',
                              style: TextStyle(
                                  color: focused ? Colors.white70 : Colors.white38,
                                  fontSize: 14)),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right,
                              color: focused ? Colors.white : Colors.white38),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
        // 标题
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
            child: const Text('我的收藏',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
        const Positioned(top: 20, right: 30, child: TimeDisplay()),
      ],
    );
  }

  /// 收藏夹内视频列表
  Widget _buildVideoList() {
    if (_isVideosLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return Stack(
        children: [
          const Center(
            child: Text('收藏夹为空', style: TextStyle(color: Colors.white70, fontSize: 20)),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              color: const Color(0xFF121212),
              padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
              child: Text('$_selectedFolderTitle',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
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
                child: SizeCacheWidget(
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
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final video = _videos[index];

                            Widget buildCard(BuildContext ctx) {
                              return TvVideoCard(
                                video: video,
                                focusNode: _getVideoFocusNode(index),
                                disableCache: false,
                                onTap: () => _onVideoTap(video),
                                onMoveLeft: (index % 4 == 0)
                                    ? () => widget.sidebarFocusNode?.requestFocus()
                                    : () => _getVideoFocusNode(index - 1).requestFocus(),
                                onMoveRight: (index + 1 < _videos.length)
                                    ? () => _getVideoFocusNode(index + 1).requestFocus()
                                    : null,
                                onMoveUp: index >= 4
                                    ? () => _getVideoFocusNode(index - 4).requestFocus()
                                    : () {},
                                onMoveDown: (index + 4 < _videos.length)
                                    ? () => _getVideoFocusNode(index + 4).requestFocus()
                                    : null,
                                onFocus: () {
                                  if (!_videoScrollController.hasClients) return;
                                  final RenderObject? object = ctx.findRenderObject();
                                  if (object != null && object is RenderBox) {
                                    final viewport = RenderAbstractViewport.of(object);
                                    final offsetToReveal = viewport
                                        .getOffsetToReveal(object, 0.0).offset;
                                    final targetOffset = (offsetToReveal - 120).clamp(
                                        0.0, _videoScrollController.position.maxScrollExtent);
                                    if ((_videoScrollController.offset - targetOffset).abs() > 50) {
                                      _videoScrollController.animateTo(targetOffset,
                                          duration: const Duration(milliseconds: 500),
                                          curve: Curves.easeOutCubic);
                                    }
                                  }
                                },
                              );
                            }

                            return Builder(builder: buildCard);
                          }, childCount: _videos.length),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoadingMore)
                const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        // 标题
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 15),
            child: Text(_selectedFolderTitle,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
        const Positioned(top: 20, right: 30, child: TimeDisplay()),
      ],
    );
  }
}
```

**Step 2: 验证**

Run: `cd /Users/rex/Documents/Program2026/BiliTV && dart analyze lib/screens/home/favorite_tab.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/home/favorite_tab.dart
git commit -m "feat: add FavoriteTab - 我的收藏夹浏览页面"
```

---

## Task 4: 注册新 Tab 到 HomeScreen

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: 添加 import（文件顶部，在现有 import 之后）**

在 `import 'home/live_tab.dart';`（第 10 行）之后添加：

```dart
import 'home/following_tab.dart';
import 'home/favorite_tab.dart';
```

**Step 2: 修改 _tabIcons 数组（第 31-38 行）**

替换为新增两个图标在最前面：

```dart
  // Tab 顺序: 我的关注、我的收藏、搜索、首页、动态、历史、直播、登录
  final List<String> _tabIcons = [
    'assets/icons/dynamic.svg',   // 我的关注（复用 dynamic 图标）
    'assets/icons/favorite.svg',  // 我的收藏
    'assets/icons/search.svg',
    'assets/icons/home.svg',
    'assets/icons/dynamic.svg',
    'assets/icons/history.svg',
    'assets/icons/live.svg',
    'assets/icons/user.svg',
  ];
```

**Step 3: 修改默认选中 Tab（第 26 行）**

```dart
  int _selectedTabIndex = 0; // 默认选中"我的关注"
```

**Step 4: 添加新的 GlobalKey（在现有 GlobalKey 之后）**

在 `_liveTabKey`（第 53 行）之后添加：

```dart
  final GlobalKey<FollowingTabState> _followingTabKey =
      GlobalKey<FollowingTabState>();
  final GlobalKey<FavoriteTabState> _favoriteTabKey =
      GlobalKey<FavoriteTabState>();
```

**Step 5: 更新 _preloadOtherTabs（第 90-114 行）**

在方法开头添加"我的关注"预加载（第一优先），并将其他 Tab 的延迟时间依次推后：

```dart
  void _preloadOtherTabs() {
    // 预加载"我的关注"（默认首页，最先加载）
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (AuthService.isLoggedIn) {
        _followingTabKey.currentState?.refresh();
      }
    });

    // 预加载动态
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (AuthService.isLoggedIn) {
        _dynamicTabKey.currentState?.refresh();
      }
    });

    // 预加载历史记录
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (AuthService.isLoggedIn) {
        _historyTabKey.currentState?.refresh();
      }
    });

    // 预加载直播
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _liveTabKey.currentState?.refresh();
    });
  }
```

**Step 6: 更新 _handleSideBarTap（第 124-150 行）**

更新所有索引偏移（+2），并添加新 Tab 的处理：

```dart
  void _handleSideBarTap(int index) {
    if (index == _selectedTabIndex) {
      if (index == 0) {
        _followingTabKey.currentState?.refresh();
      } else if (index == 1) {
        _favoriteTabKey.currentState?.refresh();
      } else if (index == 3) {
        _homeTabKey.currentState?.refreshCurrentCategory();
      } else if (index == 4) {
        _dynamicTabKey.currentState?.refresh();
      } else if (index == 5) {
        _historyTabKey.currentState?.refresh();
      } else if (index == 6) {
        _liveTabKey.currentState?.refresh();
      }
      return;
    }

    setState(() => _selectedTabIndex = index);
    _sideBarFocusNodes[index].requestFocus();

    if (index == 0) {
      _followingTabKey.currentState?.refresh();
    } else if (index == 1) {
      _favoriteTabKey.currentState?.refresh();
    } else if (index == 4) {
      _dynamicTabKey.currentState?.refresh();
    } else if (index == 5) {
      _historyTabKey.currentState?.refresh();
    } else if (index == 6) {
      _liveTabKey.currentState?.refresh();
    }
  }
```

**Step 7: 更新 build 方法中的侧边栏逻辑**

更新 User tab 索引判断（原 `index == 5` 改为 `index == 7`）和 onMoveRight 中的直播 Tab 索引（原 `index == 4` 改为 `index == 6`）：

在 `List.generate` 中：
```dart
final isUserTab = index == 7; // User tab is now at index 7
```

在 `onMoveRight` 中：
```dart
onMoveRight: index == 6  // Live tab at index 6
    ? () { _liveTabKey.currentState?.focusFirstItem(); }
    : isUserTab && AuthService.isLoggedIn
    ? () => _loginTabKey.currentState?.focusFirstCategory()
    : null,
```

**Step 8: 更新 _buildRightContent（第 260-308 行）**

在 IndexedStack 的 children 最前面插入两个新 Tab，更新 Back 键返回逻辑使其返回到 index 0（我的关注）：

```dart
  Widget _buildRightContent() {
    return IndexedStack(
      index: _selectedTabIndex,
      children: [
        // 0: 我的关注 (新增 - 默认首页)
        FollowingTab(
          key: _followingTabKey,
          sidebarFocusNode: _sideBarFocusNodes[0],
          isVisible: _selectedTabIndex == 0,
          onFirstLoadComplete: _activateFocusSystem,
        ),
        // 1: 我的收藏 (新增)
        FavoriteTab(
          key: _favoriteTabKey,
          sidebarFocusNode: _sideBarFocusNodes[1],
          isVisible: _selectedTabIndex == 1,
        ),
        // 2: 搜索
        SearchTab(
          key: _searchTabKey,
          sidebarFocusNode: _sideBarFocusNodes[2],
          onBackToHome: () {
            _backFromSearchHandled = DateTime.now();
            setState(() => _selectedTabIndex = 0); // 回到"我的关注"
            _sideBarFocusNodes[0].requestFocus();
          },
        ),
        // 3: 首页
        HomeTab(
          key: _homeTabKey,
          sidebarFocusNode: _sideBarFocusNodes[3],
          onFirstLoadComplete: _activateFocusSystem,
          preloadedVideos: widget.preloadedVideos,
        ),
        // 4: 动态
        DynamicTab(
          key: _dynamicTabKey,
          sidebarFocusNode: _sideBarFocusNodes[4],
          isVisible: _selectedTabIndex == 4,
        ),
        // 5: 历史
        HistoryTab(
          key: _historyTabKey,
          sidebarFocusNode: _sideBarFocusNodes[5],
          isVisible: _selectedTabIndex == 5,
        ),
        // 6: 直播
        LiveTab(
          key: _liveTabKey,
          sidebarFocusNode: _sideBarFocusNodes[6],
          isVisible: _selectedTabIndex == 6,
        ),
        // 7: 登录/用户
        LoginTab(
          key: _loginTabKey,
          sidebarFocusNode: _sideBarFocusNodes[7],
          onLoginSuccess: _refreshCurrentTab,
        ),
      ],
    );
  }
```

**Step 9: 更新 PopScope 中的 Back 键逻辑**

更新搜索 Tab 判断（`_selectedTabIndex == 2`）和主页判断（`_selectedTabIndex != 0`）以及返回目标（index 0）：

```dart
// 搜索标签
if (_selectedTabIndex == 2) {
  final handled = _searchTabKey.currentState?.handleBack() ?? false;
  if (!handled) {
    setState(() => _selectedTabIndex = 0); // 回到"我的关注"
    _sideBarFocusNodes[0].requestFocus();
  }
  return;
}

// 收藏标签：处理返回键（从视频列表返回到收藏夹列表）
if (_selectedTabIndex == 1) {
  final handled = _favoriteTabKey.currentState?.handleBack() ?? false;
  if (!handled) {
    setState(() => _selectedTabIndex = 0);
    _sideBarFocusNodes[0].requestFocus();
  }
  return;
}

if (_selectedTabIndex != 0) {
  // 其他标签按返回键回到"我的关注"
  setState(() => _selectedTabIndex = 0);
  _sideBarFocusNodes[0].requestFocus();
  return;
}

// "我的关注"标签：按两次退出
```

**Step 10: 验证**

Run: `cd /Users/rex/Documents/Program2026/BiliTV && dart analyze lib/screens/home_screen.dart`
Expected: No errors

**Step 11: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: register FollowingTab and FavoriteTab in HomeScreen navigation"
```

---

## Task 5: 全项目编译验证

**Step 1: 运行完整 Dart 分析**

Run: `cd /Users/rex/Documents/Program2026/BiliTV && dart analyze lib/`
Expected: No errors (warnings OK)

**Step 2: 验证 Flutter 构建**

Run: `cd /Users/rex/Documents/Program2026/BiliTV && flutter build apk --debug 2>&1 | tail -20`
Expected: BUILD SUCCESSFUL

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: BiliTV 增量改造 - 新增我的关注和我的收藏 Tab"
```
