import 'package:flutter/material.dart';
import 'plugin.dart';

// 这里的 VideoItem 和 DanmakuItem 需要根据实际项目中的模型进行调整
// 暂时使用 dynamic 或者定义简单的接口，后续集成时替换为真实类型

/// 首页/推荐流过滤插件接口
abstract class FeedPlugin extends Plugin {
  /// 是否显示该视频/动态
  /// 返回 false 表示过滤掉
  bool shouldShowItem(dynamic item);
}

/// 弹幕插件接口
abstract class DanmakuPlugin extends Plugin {
  /// 过滤弹幕
  /// 返回 null 表示过滤掉，否则返回处理后的弹幕（或原弹幕）
  dynamic filterDanmaku(dynamic item);

  /// 弹幕样式自定义
  /// 返回自定义样式，null 表示使用默认样式
  DanmakuStyle? styleDanmaku(dynamic item);
}

/// 播放器插件接口
abstract class PlayerPlugin extends Plugin {
  /// 视频加载时调用
  Future<void> onVideoLoad(String bvid, int cid);

  /// 播放进度更新时调用 (单位: 毫秒)
  /// 返回 SkipAction 决定是否跳过或显示按钮
  Future<SkipAction> onPositionUpdate(int positionMs);

  /// 视频结束时调用
  void onVideoEnd();
}

/// 弹幕样式定义
class DanmakuStyle {
  final Color? borderColor;
  final Color? backgroundColor;
  final bool bold;

  const DanmakuStyle({
    this.borderColor,
    this.backgroundColor,
    this.bold = false,
  });
}

/// 跳过动作定义
abstract class SkipAction {}

class SkipActionNone extends SkipAction {}

class SkipActionSkipTo extends SkipAction {
  final int positionMs;
  final String reason;

  SkipActionSkipTo(this.positionMs, this.reason);
}

class SkipActionShowButton extends SkipAction {
  final int skipToMs;
  final String label;
  final String segmentId;

  SkipActionShowButton(this.skipToMs, this.label, this.segmentId);
}
