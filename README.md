# PID调参助手

无人机黑盒日志分析工具，帮助飞手快速优化 PID 参数。

## 功能

- 上传黑盒日志（.bbl / .bfl / .csv）
- 阶跃响应分析
- 参数优化建议
- CLI 命令一键复制

## 构建

需要 Flutter SDK 3.22+

```bash
flutter pub get
flutter build apk --release
```

## 安装

将 APK 传输到 Android 手机安装即可使用。

## 使用方法

1. 打开 App
2. 点击上传黑盒日志
3. 查看分析结果
4. 按建议调整 PID 参数
