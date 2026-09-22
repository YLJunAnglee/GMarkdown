# GMarkdown 0.1.1 交付目录（候选）

状态：**候选交付目录已完成模拟器接入验证并冻结；未声明 L1/L2**。

本目录对应源码仓库当前候选基线，首发分发方式为源码文件夹。组件源码、依赖源码、资源和许可证已整理到目录；交付源码和最小宿主已完成 iOS 15 Simulator target 的 Debug/Release 构建。真机 Release 性能/内存和 iOS 15 实机运行未测，因此不声明 L1/L2。

## 目录组成

- `Integration.md`：接入、升级、回退和能力边界。
- `DemoAcceptanceChecklist.md`：Demo 能力验收、稳定版本冻结和证据记录清单。
- `SourceManifest.md`：应随版本交付的源码、依赖、资源和许可证清单。
- `CHANGELOG.md`：本候选版本变更与已知限制。
- `Checksums.sha256`：冻结候选内容的 SHA-256 完整性清单。

当前已知证据：全新最小宿主独立编译交付 `Sources/` 和本地依赖的 iOS 15 Simulator Debug/Release 均通过；Demo 已完成正常换行、深色模式和 Dynamic Type 验收；许可证、资源和校验哈希已核对。尚未完成真机 Release 性能/内存和 iOS 15 实机运行。

组件源码与第三方依赖在候选冻结时从仓库复制到本目录的 `Sources/`、`Dependencies/` 和 `Licenses/`；组件资源随 `Sources/Assets/` 交付。任何后续修改都必须重新生成哈希清单，并整体替换目录进行升级/回退。
