import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bili_tv_app/models/video.dart';
import 'home/home_tab.dart';
import 'home/history_tab.dart';
import 'home/search_tab.dart';
import 'home/login_tab.dart';
import 'home/dynamic_tab.dart';
import 'home/live_tab.dart';
import 'home/following_tab.dart';
import 'home/favorite_tab.dart';
import '../widgets/tv_focusable_item.dart';
import '../widgets/math_verify_dialog.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';

/// 主页框架 - 完全按照 animeone_tv_app 的方式
class HomeScreen extends StatefulWidget {
  final List<Video>? preloadedVideos;

  const HomeScreen({super.key, this.preloadedVideos});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0; // 默认选中"我的关注"
  DateTime? _lastBackPressed;
  DateTime? _backFromSearchHandled; // 防止搜索键盘返回键重复处理

  // 家长锁：需要数学验证的 Tab 索引（搜索、推荐、动态、直播）
  static const _restrictedTabs = {2, 3, 4, 6};
  bool _parentVerified = false; // 本次会话是否已通过验证

  // 自动刷新：记录每个 Tab 上次加载的时间，超过 600 秒自动刷新
  static const _autoRefreshSeconds = 600;
  final Map<int, DateTime> _tabLastLoadTime = {};

  // Tab 顺序: 我的关注、我的收藏、搜索、首页、动态、历史、直播、登录
  final List<String> _tabIcons = [
    'assets/icons/dynamic.svg',   // 0: 我的关注
    'assets/icons/favorite.svg',  // 1: 我的收藏
    'assets/icons/search.svg',    // 2: 搜索
    'assets/icons/home.svg',      // 3: 首页
    'assets/icons/dynamic.svg',   // 4: 动态
    'assets/icons/history.svg',   // 5: 历史
    'assets/icons/live.svg',      // 6: 直播
    'assets/icons/user.svg',      // 7: 登录
  ];

  late List<FocusNode> _sideBarFocusNodes;

  // 用于访问 SearchTab 状态
  final GlobalKey<SearchTabState> _searchTabKey = GlobalKey<SearchTabState>();
  // 用于访问 HomeTab 状态 (刷新功能)
  final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();
  // 动态和历史记录 Tab - 每次切换时刷新
  final GlobalKey<DynamicTabState> _dynamicTabKey =
      GlobalKey<DynamicTabState>();
  final GlobalKey<HistoryTabState> _historyTabKey =
      GlobalKey<HistoryTabState>();
  final GlobalKey<LoginTabState> _loginTabKey = GlobalKey<LoginTabState>();
  // 直播 Tab
  final GlobalKey<LiveTabState> _liveTabKey = GlobalKey<LiveTabState>();
  // 关注 Tab
  final GlobalKey<FollowingTabState> _followingTabKey =
      GlobalKey<FollowingTabState>();
  // 收藏 Tab
  final GlobalKey<FavoriteTabState> _favoriteTabKey =
      GlobalKey<FavoriteTabState>();

  @override
  void initState() {
    super.initState();
    _sideBarFocusNodes = List.generate(
      _tabIcons.length,
      (index) => FocusNode(),
    );

    // 可以在这里做一些初始化，但不再强制请求 sidebar 焦点
    // 而是等待 HomeTab 加载完成后请求内容焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保 Highlight 策略正确
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    });
  }

  // 激活焦点系统
  void _activateFocusSystem() {
    if (!mounted) return;

    // 强制设置高亮策略为传统模式 (TV 模式)
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    final currentFocusNode = _sideBarFocusNodes[_selectedTabIndex];
    if (!currentFocusNode.hasFocus) {
      currentFocusNode.requestFocus();
    }

    // 首页加载完成后，延迟后台预加载动态和历史记录
    _preloadOtherTabs();
  }

  // 后台预加载其他标签（FollowingTab 作为默认首页已自动加载，无需预加载）
  void _preloadOtherTabs() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (AuthService.isLoggedIn) {
        _dynamicTabKey.currentState?.refresh();
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (AuthService.isLoggedIn) {
        _historyTabKey.currentState?.refresh();
      }
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _liveTabKey.currentState?.refresh();
    });
  }

  @override
  void dispose() {
    for (var node in _sideBarFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// 检查是否需要自动刷新（距上次加载 > 600 秒）
  void _autoRefreshIfNeeded(int index) {
    final lastLoad = _tabLastLoadTime[index];
    if (lastLoad == null ||
        DateTime.now().difference(lastLoad).inSeconds >= _autoRefreshSeconds) {
      _refreshTabByIndex(index);
    }
  }

  /// 刷新指定 Tab 并记录时间
  void _refreshTabByIndex(int index) {
    _tabLastLoadTime[index] = DateTime.now();
    switch (index) {
      case 0:
        _followingTabKey.currentState?.refresh();
        break;
      case 1:
        _favoriteTabKey.currentState?.refresh();
        break;
      case 3:
        _homeTabKey.currentState?.refreshCurrentCategory();
        break;
      case 4:
        _dynamicTabKey.currentState?.refresh();
        break;
      case 5:
        _historyTabKey.currentState?.refresh();
        break;
      case 6:
        _liveTabKey.currentState?.refresh();
        break;
    }
  }

  void _handleSideBarTap(int index) async {
    // 家长锁：受限 Tab 需要数学验证
    if (_restrictedTabs.contains(index) && !_parentVerified) {
      final passed = await MathVerifyDialog.show(context);
      if (!passed) {
        // 验证失败或取消，回到当前安全 Tab
        _sideBarFocusNodes[_selectedTabIndex].requestFocus();
        return;
      }
      _parentVerified = true; // 本次会话通过验证
    }

    // 按确认键：强制刷新当前 Tab
    if (index == _selectedTabIndex) {
      _refreshTabByIndex(index);
      return;
    }

    setState(() => _selectedTabIndex = index);
    _sideBarFocusNodes[index].requestFocus();
    _refreshTabByIndex(index);
  }

  void _refreshCurrentTab() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 检查是否刚刚被搜索键盘的返回键处理过
        if (_backFromSearchHandled != null &&
            DateTime.now().difference(_backFromSearchHandled!) <
                const Duration(milliseconds: 200)) {
          return; // 已被处理，忽略
        }

        // 搜索标签
        if (_selectedTabIndex == 2) {
          final handled = _searchTabKey.currentState?.handleBack() ?? false;
          if (!handled) {
            setState(() => _selectedTabIndex = 0);
            _sideBarFocusNodes[0].requestFocus();
          }
          return;
        }

        // 收藏标签：视频列表 → 收藏夹列表
        if (_selectedTabIndex == 1) {
          final handled = _favoriteTabKey.currentState?.handleBack() ?? false;
          if (!handled) {
            setState(() => _selectedTabIndex = 0);
            _sideBarFocusNodes[0].requestFocus();
          }
          return;
        }

        if (_selectedTabIndex != 0) {
          // 其他标签按返回键都回到我的关注
          setState(() => _selectedTabIndex = 0);
          _sideBarFocusNodes[0].requestFocus();
          return;
        }

        // 我的关注标签：按两次退出
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;

          Fluttertoast.showToast(
            msg: '再按一次返回键退出应用',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            textColor: Colors.white,
            fontSize: 18.0,
          );
        } else {
          // 退出前清理缓存
          await SettingsService.clearImageCache();
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧边栏
            Expanded(
              flex: 8,
              child: Container(
                color: const Color(0xFF1E1E1E),
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(_tabIcons.length, (index) {
                    final isUserTab = index == 7; // User tab is now at index 7
                    final avatarUrl = isUserTab && AuthService.isLoggedIn
                        ? AuthService.face
                        : null;

                    return TvFocusableItem(
                      iconPath: _tabIcons[index],
                      avatarUrl: avatarUrl,
                      isSelected: _selectedTabIndex == index,
                      focusNode: _sideBarFocusNodes[index],
                      onFocus: () {
                        // 焦点移动时切换标签页（受限 Tab 未验证时不切换内容）
                        if (_restrictedTabs.contains(index) && !_parentVerified) {
                          return;
                        }
                        final previousIndex = _selectedTabIndex;
                        setState(() => _selectedTabIndex = index);
                        // 自动刷新：切换到新 Tab 时，如果超过 600 秒则自动刷新
                        if (index != previousIndex) {
                          _autoRefreshIfNeeded(index);
                        }
                      },
                      onTap: () => _handleSideBarTap(index), // 按确定键才刷新
                      // 用户标签按右键导航到设置分类标签
                      onMoveRight: index == 6
                          ? () {
                              _liveTabKey.currentState?.focusFirstItem();
                            }
                          : isUserTab && AuthService.isLoggedIn
                          ? () =>
                                _loginTabKey.currentState?.focusFirstCategory()
                          : null,
                    );
                  }),
                ),
              ),
            ),
            // 右侧内容区
            Expanded(flex: 92, child: _buildRightContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildRightContent() {
    return IndexedStack(
      index: _selectedTabIndex,
      children: [
        // 0: 我的关注 (新增)
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
            setState(() => _selectedTabIndex = 0);
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
}
