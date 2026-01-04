import 'package:flutter/foundation.dart';
import 'plugin.dart';
import 'plugin_store.dart';

class PluginManager {
  // 单例模式
  static final PluginManager _instance = PluginManager._internal();
  factory PluginManager() => _instance;
  PluginManager._internal();

  // 所有注册的插件
  final List<Plugin> _plugins = [];
  List<Plugin> get plugins => List.unmodifiable(_plugins);

  // 状态通知
  final ValueNotifier<List<Plugin>> enabledPluginsNotifier = ValueNotifier([]);

  // 初始化 (预留)
  Future<void> init() async {
    // 可以在这里加载初始状态
    await _refreshEnabledPlugins();
  }

  // 注册插件
  void register(Plugin plugin) {
    if (_plugins.any((p) => p.id == plugin.id)) {
      debugPrint('Warning: Plugin ${plugin.id} already registered.');
      return;
    }
    _plugins.add(plugin);
    debugPrint(
      'PluginManager: Registered ${plugin.name} (${plugin.id}). Total: ${_plugins.length}',
    );
    // 检查并自动启用（如果记录是启用的）
    _checkAndEnable(plugin);
  }

  // 检查并启用插件
  Future<void> _checkAndEnable(Plugin plugin) async {
    bool enabled = await PluginStore.isEnabled(plugin.id);
    if (enabled) {
      try {
        await plugin.onEnable();
        _refreshEnabledPlugins();
        debugPrint('Plugin enabled: ${plugin.name}');
      } catch (e) {
        debugPrint('Error enabling plugin ${plugin.name}: $e');
      }
    }
  }

  // 设置插件启用/禁用
  Future<void> setEnabled(Plugin plugin, bool enabled) async {
    await PluginStore.setEnabled(plugin.id, enabled);

    if (enabled) {
      try {
        await plugin.onEnable();
      } catch (e) {
        debugPrint('Error enabling plugin ${plugin.name}: $e');
        // 如果启用失败，回滚状态? 暂时不回滚，允许重试
      }
    } else {
      try {
        await plugin.onDisable();
      } catch (e) {
        debugPrint('Error disabling plugin ${plugin.name}: $e');
      }
    }
    await _refreshEnabledPlugins();
  }

  // 刷新已启用插件列表通知
  Future<void> _refreshEnabledPlugins() async {
    List<Plugin> enabledList = [];
    for (var plugin in _plugins) {
      if (await PluginStore.isEnabled(plugin.id)) {
        enabledList.add(plugin);
      }
    }
    enabledPluginsNotifier.value = enabledList;
  }

  // 获取特定类型的已启用插件
  List<T> getEnabledPlugins<T extends Plugin>() {
    return enabledPluginsNotifier.value.whereType<T>().toList();
  }

  // 根据 ID 获取特定插件
  T? getPlugin<T extends Plugin>(String id) {
    try {
      return _plugins.whereType<T>().firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
