# BiliTV Kids - 给孩子看好视频的电视客户端

> Fork 自 [Hyper-Beast/BiliTV](https://github.com/Hyper-Beast/BiliTV)，一款 Android TV 第三方哔哩哔哩客户端。

## 使用场景

家长提前在 B站关注优质的教育、科普、纪录片等 UP主，孩子打开电视后只能看到这些**家长筛选过的内容**。搜索、推荐、直播等开放性功能被家长锁保护，孩子无法自行访问。

**解决的问题：** 孩子想看电视，但 B站推荐算法不可控。这个方案让家长决定孩子能看什么，同时保留 B站丰富的优质内容库。

## 相比上游项目的改动

### 新增功能

| 功能 | 说明 |
|------|------|
| **我的关注（默认首页）** | 聚合所有关注 UP主 的视频，按发布时间倒序排列。使用 `type=video` API 确保每页全是视频（不夹杂图文/转发动态）。孩子打开电视直接看到家长筛选的内容 |
| **我的收藏** | 浏览 B站云端收藏夹，家长可以提前收藏好视频，孩子在电视上观看 |
| **家长锁** | 搜索、推荐、动态、直播 4 个 Tab 需要解数学方程才能进入。题目需计算器辅助（如 `37×14 + 23×9 - 156 = ?`），验证通过后本次会话有效，重启 app 重置 |
| **自动刷新** | 切换 Tab 时，如果距上次加载超过 10 分钟自动刷新数据；在当前 Tab 按确认键可强制刷新 |

### 保留的原有功能

视频播放（多画质 / 弹幕 / 进度记忆 / 连播）、观看历史、搜索、推荐、直播、QR码登录、插件系统等全部保留，未做删减。

### 技术变更

- 新增 `lib/screens/home/following_tab.dart` — 我的关注 Tab
- 新增 `lib/screens/home/favorite_tab.dart` — 我的收藏 Tab
- 新增 `lib/widgets/math_verify_dialog.dart` — 家长锁数学验证
- 新增 `video_api.dart` 中的 `getDynamicVideoFeed()` — 仅视频的动态 API（`type=video`）
- 新增 `interaction_api.dart` 中的收藏夹 API（`getFavoriteFolders` / `getFavoriteVideos`）
- 修改 `lib/screens/home_screen.dart` — Tab 注册、导航索引、家长锁拦截、600 秒自动刷新
- 新增 `.github/workflows/build-apk.yml` — GitHub Actions 自动编译

---

## 快速开始

### 1. 登录

在电视端打开 **设置** Tab → 扫描二维码登录你的 B站账号。

### 2. 准备内容

在手机/电脑的 B站上：
- **关注**你希望孩子看的 UP主（教育、科普、纪录片等）
- **收藏**优质视频到收藏夹

### 3. 孩子使用

孩子打开电视 → 默认进入「我的关注」→ 看到家长筛选的视频 → 遥控器选择播放。

如果孩子试图进入搜索 / 推荐 / 直播，会弹出数学题验证（需要计算器才能解出），孩子无法自行通过。

---

## 编译

### macOS 本地编译（无需 Android Studio）

**前置安装（一次性）：**
```bash
# 1. 安装 JDK 17
brew install openjdk@17

# 2. 安装 Flutter SDK
git clone --depth 1 --branch 3.41.2 https://github.com/flutter/flutter.git /opt/homebrew/opt/flutter
```

**编译 APK：**
```bash
# 获取依赖
JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" \
PATH="/opt/homebrew/opt/flutter/bin:$PATH" \
flutter pub get

# 编译 Release APK
JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" \
PATH="/opt/homebrew/opt/flutter/bin:$PATH" \
flutter build apk --release

# 产物位置: build/app/outputs/flutter-apk/app-release.apk
```

**卸载（完全清理）：**
```bash
brew uninstall openjdk@17
rm -rf /opt/homebrew/opt/flutter
```

### GitHub Actions 云端编译

推送到 `main` 分支后自动触发编译，在 Actions → Artifacts 下载 APK。

---

## 致谢

- **[Hyper-Beast/BiliTV](https://github.com/Hyper-Beast/BiliTV)** — 本项目的上游，提供了完整的 Android TV 哔哩哔哩客户端
- **[jay3-yy/BiliPai](https://github.com/jay3-yy/BiliPai)** — BiliTV 的原始基础项目

## 免责声明

本项目仅供学习交流和个人家庭使用，请勿用于商业用途。视频内容版权归哔哩哔哩及原作者所有。

## 许可证

MIT License
