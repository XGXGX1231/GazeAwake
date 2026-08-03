# GazeAwake — MacBook 注视感知

**一个面向 MacBook 的隐私优先实验：只使用原生 Swift 系统框架，补上用户熟悉的注视感知显示体验。**

[English](README.md) · [架构](docs/ARCHITECTURE.md) · [基准测试](docs/BENCHMARKS.md) · [隐私](docs/PRIVACY.md) · [路线图](docs/ROADMAP.md)

> [!WARNING]
> GazeAwake 当前为 **v0.1 Experimental / Proof of Concept**。它不是精确眼动仪、专业测量工具、医疗设备或无障碍认证产品。当前 Vision landmarks 模式具有较明显的实测内存和 CPU 开销，具体数值与测试方法参见[基准测试](docs/BENCHMARKS.md)。

## 为什么要做 GazeAwake

长期使用支持 Face ID 的 iPhone 或 iPad 后，一些用户会逐渐习惯设备对“自己是否仍在看屏幕”作出反应。当他们回到 MacBook 工作时，如果缺少同类的注视—显示器联动，体验可能会产生明显断层：用户会下意识期待自己重新看向电脑时屏幕能够响应、阅读期间不要无谓熄屏、移开视线后再恢复正常节能。

**GazeAwake 想在 MacBook 上探索并补足这种交互连续性。** 它通过 Mac 摄像头近似实现其中一个明确而有限的闭环：

- 重新看向 MacBook 时，唤醒因空闲而熄灭的显示器；
- 持续注视时，避免显示器因空闲计时而意外熄灭；
- 移开视线后，把显示器休眠控制权交还给 macOS 的正常节能机制。

GazeAwake 是独立开源实验，不是 Apple 官方功能，也不是 Face ID 或 TrueDepth 注视感知的 Mac 版实现。它不会复刻 iPhone/iPad 上所有“注视感知功能”；普通摄像头启发式判断的精度更低，现阶段资源开销也明显更高。这里强调的是**跨设备交互习惯与产品动机**，不是技术能力等同。

## 功能

GazeAwake 是一个主要面向 MacBook、没有 Dock 图标和主窗口的菜单栏后台应用，使用摄像头粗略估计用户是否正在注视屏幕，并完成以下闭环：

1. 在本机判断粗粒度注意力状态；
2. 用户重新注视时唤醒因空闲而熄灭的显示器；
3. 持续注视期间保持亮屏；
4. 移开视线、暂停或退出时释放电源 assertion，恢复正常节能；
5. 通过回调和通知向其他 macOS 应用发布状态。

仅使用：

- **AVFoundation**：低分辨率摄像头采集
- **Vision**：人脸关键点与头部姿态
- **IOKit**：显示器唤醒和防止空闲熄屏
- **AppKit**：菜单栏 Agent

项目没有第三方模型或依赖，不使用 Python、OpenCV 或网络服务。摄像头画面不会写入磁盘或上传。

## 检测逻辑

当前实现属于启发式注意力判断，不是精确眼动追踪：

- 摄像头 12 fps，优先使用 320×240，其次 352×288、640×480；
- 每 3 帧执行一次 `VNDetectFaceLandmarksRequest`，约 4 次推理/秒；
- 选择最大人脸并排除过小人脸；
- 根据 yaw、roll、pitch 排除明显转头；
- 有瞳孔关键点时，判断左右瞳孔是否处于眼睛中央区域；
- 没有瞳孔关键点时，退化为“检测到人脸且脸部大致朝向屏幕”；
- 连续 2 个正样本确认注视，连续 3 个负样本确认离开。

精确阈值和数据流参见[架构说明](docs/ARCHITECTURE.md)。

## 唤醒边界

状态切换为注视时，应用调用 `IOPMAssertionDeclareUserActivity` 点亮显示器，并在持续注视期间持有 `kIOPMAssertionTypePreventUserIdleDisplaySleep`。移开视线、暂停、关闭唤醒选项或退出时立即释放。

它只能唤醒因空闲显示器休眠而关闭的屏幕，不能：

- 从整机深度睡眠中唤醒 Mac；
- 在摄像头被系统挂起时继续检测；
- 从合盖睡眠中唤醒；
- 绕过锁屏、密码或 Touch ID。

## 环境

- macOS 13 Ventura 或更高
- Xcode 15 或更高
- Swift 5.9 或更高
- MacBook 内置摄像头或兼容的 Mac 外接摄像头

## 下载与安装

从 [v0.1.0 Release](https://github.com/XGXGX1231/GazeAwake/releases/tag/v0.1.0) 下载 `GazeAwake-v0.1.0-macOS-universal.dmg`，打开后把 `GazeAwake.app` 拖到 **Applications（应用程序）**。该 Universal 应用同时支持 Apple Silicon 和 Intel Mac。

当前实验版 DMG 使用 ad-hoc 签名，且**尚未经过 Apple 公证**，因为项目目前没有 Developer ID 证书。macOS 首次启动时可能阻止运行：先尝试打开一次，然后前往 **系统设置 → 隐私与安全性 → 安全性 → 仍要打开**，确认启动并允许摄像头访问。请只安装从项目官方 GitHub Release 页面下载的 DMG。

## 构建运行

1. 在 Xcode 中打开 `GazeAwake.xcodeproj`；
2. 选择 `GazeAwake` scheme 和 **My Mac**；
3. 如有需要，选择自己的签名 Team；
4. 运行并允许摄像头权限；
5. 通过菜单栏眼睛图标暂停、继续、切换唤醒或退出。

命令行 Release 构建：

```bash
./Scripts/build-release.sh
```

## 快速测试唤醒

1. 移开视线，等待菜单显示未注视；
2. 保持移开视线，在终端执行 `pmset displaysleepnow`；
3. 再看向摄像头；
4. 正样本防抖完成后，通常约 0.5 秒点亮显示器。

## 状态接口

- 进程内回调：`onStateChanged: (Bool) -> Void`
- 本地通知：`GazeAwakeStateDidChange`
- 跨进程通知：`net.xgxgx.GazeAwake.stateDidChange`
- Payload：`["isLookingAtScreen": Bool]`

监听示例：

```bash
swift Samples/NotificationListener.swift
```

## 现阶段实测性能

Apple M5 MacBook Pro、Vision 预热后的结果：

| 指标 | 结果 |
|---|---:|
| 活跃 physical footprint | 约 207 MiB / 217 MB |
| 峰值 physical footprint | 约 292 MiB / 306 MB |
| Vision neural peak | 约 126 MiB / 132 MB |
| `ps` RSS | 约 104 MiB / 107 MB |
| 短时 CPU | 约 21–27% |

未进入摄像头和 Vision 工作态时观察到的 11–12 MB 不能代表真实检测。主要开销来自 Vision neural/landmarks 资源，而不是应用缓存视频帧。完整测试信息参见[基准测试](docs/BENCHMARKS.md)。

## 隐私

- 帧只在内存中同步处理；
- 应用不维护视频帧缓存；
- 不保存、不上传、不记录摄像头画面；
- 没有分析、遥测或网络服务；
- 检测运行期间摄像头持续启用，因此 macOS 摄像头指示灯会亮。

详见[隐私模型](docs/PRIVACY.md)。

## 已知限制

- 粗粒度注意力估计，不是精确眼动追踪；
- 瞳孔检测失败时会退化为脸部朝向判断，可能产生误判；
- 眼镜反光、逆光、侧脸和摄像头位置会影响结果；
- 当前 landmarks 模式内存和 CPU 开销高；
- 整机或摄像头挂起后无法工作；
- 只能点亮屏幕，不能解锁；
- v0.1 没有个人校准和灵敏度配置。

## 路线图

后续计划包括低功耗人脸存在模式、灵敏度选项、登录时启动、单元测试、截图/演示 GIF，以及更多 Mac 型号的长时间基准测试。详见[路线图](docs/ROADMAP.md)。

## 许可证

项目采用 [MIT License](LICENSE)。

Apple、iPhone、iPad、MacBook、Face ID 和 TrueDepth 是 Apple Inc. 的商标。GazeAwake 是独立项目，与 Apple 无隶属或官方认可关系。
