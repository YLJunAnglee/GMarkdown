# GMarkdown 0.1.1 交付目录（候选）

状态：**Demo 基础渲染能力已通过；项目数据适配与扩展能力待开始；原生 Xcode source/framework 接入暂缓；未声明 L1/L2**。

本目录对应源码仓库当前候选基线，首发分发方式为源码文件夹。组件源码、依赖源码、资源和许可证已整理到目录；交付源码和本地验证宿主已完成 iOS 15 Simulator target 的 Debug/Release 构建，但这不等同于文档所述的干净 Xcode framework target 接入。真机 Release 性能/内存和 iOS 15 实机运行未测，因此不声明 L1/L2。

## 目录组成

- `Integration.md`：接入、升级、回退和能力边界。
- `DemoAcceptanceChecklist.md`：已完成的 Demo 能力验收与证据记录。
- `ProjectAdoptionPlan.md`：下一阶段的项目数据兼容、扩展能力和源码接入执行基线。
- `SourceManifest.md`：应随版本交付的源码、依赖、资源和许可证清单。
- `CHANGELOG.md`：本候选版本变更与已知限制。
- `Checksums.sha256`：冻结候选内容的 SHA-256 完整性清单。

当前已知证据：本地验证宿主独立编译交付 `Sources/` 和本地依赖的 iOS 15 Simulator Debug/Release 均通过；Demo 基础能力验收已完成；许可证和资源已核对。尚未完成真实项目 Markdown 兼容性矩阵、自定义业务块扩展、干净 Xcode source/framework 接入、真机 Release 性能/内存和 iOS 15 实机运行。项目适配的下一步见 [ProjectAdoptionPlan.md](./ProjectAdoptionPlan.md)。

组件源码与第三方依赖在候选冻结时从仓库复制到本目录的 `Sources/`、`Dependencies/` 和 `Licenses/`；组件资源随 `Sources/Assets/` 交付。当前正处于项目适配规划阶段，版本哈希暂不视为冻结；任意后续修改后都必须重新生成哈希清单，并整体替换目录进行升级/回退。
