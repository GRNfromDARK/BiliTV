import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/plugin/plugin_types.dart';
import '../models/video.dart';

class AdFilterPlugin extends FeedPlugin {
  @override
  String get id => 'ad_filter';

  @override
  String get name => '去广告增强';

  @override
  String get description => '过滤广告、拉黑UP主、屏蔽关键词';

  @override
  String get version => '2.0.0';

  @override
  String get author => 'YangY (Ported)';

  @override
  IconData? get icon => Icons.block_outlined;

  AdFilterConfig _config = AdFilterConfig();

  @override
  bool get hasSettings => true;

  @override
  Widget? get settingsWidget => _AdFilterSettings(plugin: this);

  // 🔥 内置广告关键词
  static const List<String> _adKeywords = [
    // 商业合作类
    '商业合作', '恰饭', '推广', '广告', '赞助', '植入',
    '合作推广', '品牌合作', '本期合作', '本视频由',
    // 平台推广类
    '官方活动', '官方推荐', '平台活动', '创作激励',
    // 淘宝/电商类
    '淘宝', '天猫', '京东', '拼多多', '双十一', '双11',
    '优惠券', '领券', '限时优惠', '好物推荐', '种草',
    // 游戏推广类
    '新游推荐', '游戏推广', '首发', '公测', '不删档',
  ];

  // 🔥 标题党关键词
  static const List<String> _clickbaitKeywords = [
    '震惊',
    '惊呆了',
    '太厉害了',
    '绝了',
    '离谱',
    '疯了',
    '价值几万',
    '价值百万',
    '价值千万',
    '一定要看',
    '必看',
    '看哭了',
    '泪目',
    '破防了',
    'DNA动了',
    'YYDS',
    '封神',
    '炸裂',
    '神作',
    '预定年度',
    '史诗级',
    '99%的人不知道',
    '你一定不知道',
    '居然是这样',
    '原来是这样',
    '真相了',
    '曝光',
    '揭秘',
    '独家',
  ];

  // 🔥 简繁体转换表
  static const Map<String, String> _simplifiedToTraditional = {
    '说': '說',
    '话': '話',
    '语': '語',
    '请': '請',
    '让': '讓',
    '这': '這',
    '时': '時',
    '间': '間',
    '门': '門',
    '网': '網',
    '电': '電',
    '视': '視',
    '频': '頻',
    '机': '機',
    '会': '會',
    '员': '員',
    '学': '學',
    '习': '習',
    '写': '寫',
    '画': '畫',
    '图': '圖',
    '书': '書',
    '读': '讀',
    '听': '聽',
    '见': '見',
    '现': '現',
    '发': '發',
    '开': '開',
    '关': '關',
    '头': '頭',
    '脑': '腦',
    '乐': '樂',
    '欢': '歡',
    '爱': '愛',
    '国': '國',
    '华': '華',
    '东': '東',
    '车': '車',
    '马': '馬',
    '鸟': '鳥',
  };

  @override
  Future<void> onEnable() async {
    await _loadConfig();
    debugPrint('✅ 去广告增强v2.0已启用');
    debugPrint(
      '📋 拉黑UP主: ${_config.blockedUpNames.length}个, 屏蔽关键词: ${_config.blockedKeywords.length}个',
    );
  }

  @override
  Future<void> onDisable() async {
    debugPrint('🔴 去广告增强已禁用');
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('plugin_config_$id');
    if (jsonStr != null) {
      try {
        _config = AdFilterConfig.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        debugPrint('Error loading config: $e');
      }
    }
  }

  Future<void> saveConfig(AdFilterConfig config) async {
    _config = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plugin_config_$id', jsonEncode(config.toJson()));
  }

  // 添加屏蔽关键词
  void addKeyword(String keyword) {
    if (!_config.blockedKeywords.contains(keyword)) {
      _config.blockedKeywords.add(keyword);
      saveConfig(_config);
    }
  }

  // 移除屏蔽关键词
  void removeKeyword(String keyword) {
    if (_config.blockedKeywords.contains(keyword)) {
      _config.blockedKeywords.remove(keyword);
      saveConfig(_config);
    }
  }

  // 获取屏蔽关键词列表 (API 使用)
  List<String> getKeywords() => List.unmodifiable(_config.blockedKeywords);

  // 获取屏蔽的UP主MID列表 (API 使用)
  List<int> getBlockedMids() => List.unmodifiable(_config.blockedMids);

  // 获取屏蔽的UP主名称列表 (API 使用)
  List<String> getBlockedUpNames() => List.unmodifiable(_config.blockedUpNames);

  // 屏蔽 UP 主 (按名称和MID)
  void blockUploader(String name, int mid) {
    bool changed = false;
    if (name.isNotEmpty && !_config.blockedUpNames.contains(name)) {
      _config.blockedUpNames.add(name);
      changed = true;
    }
    if (mid > 0 && !_config.blockedMids.contains(mid)) {
      _config.blockedMids.add(mid);
      changed = true;
    }
    if (changed) {
      saveConfig(_config);
      debugPrint('➕ 已拉黑UP主: $name (MID: $mid)');
    }
  }

  // 取消屏蔽 UP 主 (按MID)
  void unblockUploader(int mid) {
    if (_config.blockedMids.contains(mid)) {
      _config.blockedMids.remove(mid);
      saveConfig(_config);
    }
  }

  // 取消屏蔽 UP 主 (按名称)
  void unblockUploaderByName(String name) {
    if (_config.blockedUpNames.contains(name)) {
      _config.blockedUpNames.remove(name);
      saveConfig(_config);
    }
  }

  // 添加UP主名称到黑名单
  void addBlockedUpName(String name) {
    if (name.isNotEmpty && !_config.blockedUpNames.contains(name)) {
      _config.blockedUpNames.add(name);
      saveConfig(_config);
    }
  }

  // 获取配置 (API 使用)
  AdFilterConfig getConfig() => _config;

  // 设置过滤开关
  void setFilterSponsored(bool value) {
    _config.filterSponsored = value;
    saveConfig(_config);
  }

  void setFilterClickbait(bool value) {
    _config.filterClickbait = value;
    saveConfig(_config);
  }

  void setFilterLowQuality(bool value) {
    _config.filterLowQuality = value;
    saveConfig(_config);
  }

  void setMinViewCount(int value) {
    _config.minViewCount = value;
    saveConfig(_config);
  }

  /// 🔥 检查UP主名称是否在拉黑列表中 (支持简繁体)
  bool _isUpNameBlocked(String upName) {
    final normalizedUpName = _normalizeChineseChars(upName.toLowerCase());

    return _config.blockedUpNames.any((blockedName) {
      final normalizedBlocked = _normalizeChineseChars(
        blockedName.toLowerCase(),
      );
      // 精确匹配或模糊匹配
      return normalizedUpName == normalizedBlocked ||
          normalizedUpName.contains(normalizedBlocked) ||
          normalizedBlocked.contains(normalizedUpName);
    });
  }

  /// 将繁体字转换为简体字 (用于比较)
  String _normalizeChineseChars(String text) {
    // 创建繁体→简体映射
    final traditionalToSimplified = <String, String>{};
    for (final entry in _simplifiedToTraditional.entries) {
      traditionalToSimplified[entry.value] = entry.key;
    }

    final buffer = StringBuffer();
    for (final char in text.characters) {
      buffer.write(traditionalToSimplified[char] ?? char);
    }
    return buffer.toString();
  }

  @override
  bool shouldShowItem(dynamic item) {
    if (item is! Video) return true;

    final title = item.title;
    final upName = item.ownerName;
    final upMid = item.ownerMid;
    final viewCount = item.view;

    // 1️⃣ 检查UP主拉黑列表（按名称）- 支持模糊匹配和简繁体
    if (_isUpNameBlocked(upName)) {
      debugPrint('🚫 拉黑UP主[名称]: $upName - $title');
      return false;
    }

    // 2️⃣ 检查UP主拉黑列表（按MID）
    if (_config.blockedMids.contains(upMid)) {
      debugPrint('🚫 拉黑UP主[MID]: $upMid - $title');
      return false;
    }

    // 3️⃣ 检测广告/推广关键词
    if (_config.filterSponsored) {
      for (final keyword in _adKeywords) {
        if (title.toLowerCase().contains(keyword.toLowerCase())) {
          debugPrint('🚫 过滤广告: $title (UP: $upName)');
          return false;
        }
      }
    }

    // 4️⃣ 检测标题党
    if (_config.filterClickbait) {
      for (final keyword in _clickbaitKeywords) {
        if (title.toLowerCase().contains(keyword.toLowerCase())) {
          debugPrint('🚫 过滤标题党: $title');
          return false;
        }
      }
    }

    // 5️⃣ 检测自定义屏蔽关键词
    for (final keyword in _config.blockedKeywords) {
      if (keyword.isNotEmpty &&
          title.toLowerCase().contains(keyword.toLowerCase())) {
        debugPrint('🚫 自定义屏蔽: $title (关键词: $keyword)');
        return false;
      }
    }

    // 6️⃣ 过滤低质量视频（播放量过低）
    if (_config.filterLowQuality &&
        viewCount > 0 &&
        viewCount < _config.minViewCount) {
      debugPrint('🚫 低播放量: $title (播放: $viewCount)');
      return false;
    }

    return true;
  }
}

/// 去广告配置 v2.0
class AdFilterConfig {
  // 基础过滤开关
  bool filterSponsored; // 过滤广告推广
  bool filterClickbait; // 过滤标题党
  bool filterLowQuality; // 过滤低质量
  int minViewCount; // 最低播放量

  // UP主拉黑
  List<String> blockedUpNames; // 拉黑UP主名称
  List<int> blockedMids; // 拉黑UP主MID

  // 自定义关键词
  List<String> blockedKeywords; // 自定义屏蔽词

  AdFilterConfig({
    this.filterSponsored = true,
    this.filterClickbait = true,
    this.filterLowQuality = false,
    this.minViewCount = 1000,
    List<String>? blockedUpNames,
    List<int>? blockedMids,
    List<String>? blockedKeywords,
  }) : blockedUpNames = blockedUpNames ?? [],
       blockedMids = blockedMids ?? [],
       blockedKeywords = blockedKeywords ?? [];

  factory AdFilterConfig.fromJson(Map<String, dynamic> json) {
    return AdFilterConfig(
      filterSponsored: json['filterSponsored'] ?? true,
      filterClickbait: json['filterClickbait'] ?? true,
      filterLowQuality: json['filterLowQuality'] ?? false,
      minViewCount: json['minViewCount'] ?? 1000,
      blockedUpNames: List<String>.from(json['blockedUpNames'] ?? []),
      blockedMids: List<int>.from(json['blockedMids'] ?? []),
      blockedKeywords: List<String>.from(
        json['blockedKeywords'] ?? json['keywords'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'filterSponsored': filterSponsored,
    'filterClickbait': filterClickbait,
    'filterLowQuality': filterLowQuality,
    'minViewCount': minViewCount,
    'blockedUpNames': blockedUpNames,
    'blockedMids': blockedMids,
    'blockedKeywords': blockedKeywords,
  };
}

class _AdFilterSettings extends StatefulWidget {
  final AdFilterPlugin plugin;
  const _AdFilterSettings({required this.plugin});

  @override
  State<_AdFilterSettings> createState() => _AdFilterSettingsState();
}

class _AdFilterSettingsState extends State<_AdFilterSettings> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _upNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final config = widget.plugin._config;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== 过滤开关 ==========
            const Text(
              '过滤开关',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              title: const Text(
                '过滤广告推广',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '隐藏商业合作、恰饭、推广等内容',
                style: TextStyle(color: Colors.white70),
              ),
              value: config.filterSponsored,
              onChanged: (val) {
                setState(() => widget.plugin.setFilterSponsored(val));
              },
            ),

            SwitchListTile(
              title: const Text('过滤标题党', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                '隐藏震惊体、夸张标题视频',
                style: TextStyle(color: Colors.white70),
              ),
              value: config.filterClickbait,
              onChanged: (val) {
                setState(() => widget.plugin.setFilterClickbait(val));
              },
            ),

            SwitchListTile(
              title: const Text(
                '过滤低播放量',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '隐藏播放量低于 ${config.minViewCount} 的视频',
                style: const TextStyle(color: Colors.white70),
              ),
              value: config.filterLowQuality,
              onChanged: (val) {
                setState(() => widget.plugin.setFilterLowQuality(val));
              },
            ),

            const Divider(color: Colors.white24),

            // ========== UP主拉黑 ==========
            const SizedBox(height: 16),
            const Text(
              'UP主拉黑',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _upNameController,
                    decoration: const InputDecoration(
                      hintText: '输入UP主名称',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white12,
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _addUpName(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addUpName,
                  icon: const Icon(Icons.add, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (config.blockedUpNames.isEmpty)
              const Text(
                '暂无拉黑的UP主',
                style: TextStyle(
                  color: Colors.white38,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: config.blockedUpNames
                    .map(
                      (name) => Chip(
                        label: Text(name),
                        backgroundColor: Colors.red.withValues(alpha: 0.2),
                        onDeleted: () {
                          setState(() {
                            widget.plugin.unblockUploaderByName(name);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),

            const Divider(color: Colors.white24),

            // ========== 自定义关键词 ==========
            const SizedBox(height: 16),
            const Text(
              '自定义屏蔽关键词',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    decoration: const InputDecoration(
                      hintText: '输入关键词',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white12,
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _addKeyword(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addKeyword,
                  icon: const Icon(Icons.add, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (config.blockedKeywords.isEmpty)
              const Text(
                '暂无自定义屏蔽词',
                style: TextStyle(
                  color: Colors.white38,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: config.blockedKeywords
                    .map(
                      (k) => Chip(
                        label: Text(k),
                        onDeleted: () {
                          setState(() {
                            widget.plugin.removeKeyword(k);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),

            const SizedBox(height: 24),
            const Text(
              '已屏蔽UP主 (MID)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (config.blockedMids.isEmpty)
              const Text(
                '暂无通过MID屏蔽的UP主',
                style: TextStyle(
                  color: Colors.white38,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: config.blockedMids
                    .map(
                      (mid) => Chip(
                        label: Text(mid.toString()),
                        backgroundColor: Colors.red.withValues(alpha: 0.2),
                        onDeleted: () {
                          setState(() {
                            widget.plugin.unblockUploader(mid);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _addKeyword() {
    final text = _keywordController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        widget.plugin.addKeyword(text);
        _keywordController.clear();
      });
    }
  }

  void _addUpName() {
    final text = _upNameController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        widget.plugin.addBlockedUpName(text);
        _upNameController.clear();
      });
    }
  }
}
