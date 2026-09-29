# GMarkdown 0.1.1 交付目录（候选）

状态：**Demo 基础渲染能力和现有 `txt` 数据盘点已完成；`richTxt`、业务标签及失败降级接口待实现；原生 Xcode source/framework 接入暂缓；未声明 L1/L2**。

本目录对应源码仓库当前候选基线，首发分发方式为源码文件夹。组件源码、依赖源码、资源和许可证已整理到目录；交付源码和本地验证宿主已完成 iOS 15 Simulator target 的 Debug/Release 构建，但这不等同于文档所述的干净 Xcode framework target 接入。真机 Release 性能/内存和 iOS 15 实机运行未测，因此不声明 L1/L2。

## 目录组成

- `Integration.md`：接入、升级、回退和能力边界。
- `DemoAcceptanceChecklist.md`：已完成的 Demo 能力验收与证据记录。
- `ProjectAdoptionPlan.md`：项目适配和源码接入执行基线。
- `ProjectIntegrationExecutionPlan.md`：当前接入任务的实施顺序、交付标准与边界。
- `ProjectIntegrationCapabilityGap.md`：业务方已确认的输入、富文本和降级要求与组件能力对照。
- `SourceManifest.md`：应随版本交付的源码、依赖、资源和许可证清单。
- `CHANGELOG.md`：本候选版本变更与已知限制。
- `Checksums.sha256`：冻结候选内容的 SHA-256 完整性清单。

当前已知证据：本地验证宿主独立编译交付 `Sources/` 和本地依赖的 iOS 15 Simulator Debug/Release 均通过；Demo 基础能力验收、9 本项目书籍 `txt` 数据盘点和许可证/资源核对已完成。业务方新增的 `richTxt` 与 `<CustomClickableSpan>` 样本不在此前全为空的导出字段中；富文本展示、失败降级接口、干净 Xcode source/framework 接入、真机 Release 性能/内存和 iOS 15 实机运行尚未完成。下一步见 [ProjectAdoptionPlan.md](./ProjectAdoptionPlan.md)和[能力对照](./ProjectIntegrationCapabilityGap.md)。

组件源码与第三方依赖在候选冻结时从仓库复制到本目录的 `Sources/`、`Dependencies/` 和 `Licenses/`；组件资源随 `Sources/Assets/` 交付。当前正处于项目适配规划阶段，版本哈希暂不视为冻结；任意后续修改后都必须重新生成哈希清单，并整体替换目录进行升级/回退。下一步执行顺序见[项目接入执行计划](./ProjectIntegrationExecutionPlan.md)。
