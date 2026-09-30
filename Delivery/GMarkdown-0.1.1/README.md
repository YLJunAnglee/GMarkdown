# GMarkdown 0.1.1 交付目录（候选）

状态：**仓库源码的基础展示功能已完成，0.1.1 交付包尚待同步整理；真实项目尚未接入，未声明 L1/L2**。下次开机后的工作入口见 [NextSessionHandoff.md](./NextSessionHandoff.md)。

本目录目前是旧候选基线，首发分发方式计划为源码文件夹。仓库 `Sources/` 中的 `richTxt` 与 `CustomClickableSpan` 展示实现已提交，但尚未同步到本目录；现有哈希和历史构建结果不能证明更新后的交付包可用。真机 Release 性能/内存和 iOS 15 实机运行未测，因此不声明 L1/L2。

## 目录组成

- `NextSessionHandoff.md`：当前决定及下次开机后的交付整理步骤。
- `Integration.md`：接入、升级、回退和能力边界。
- `DemoAcceptanceChecklist.md`：已完成的 Demo 能力验收与证据记录。
- `ProjectAdoptionPlan.md`：项目适配和源码接入执行基线。
- `ProjectIntegrationExecutionPlan.md`：当前接入任务的实施顺序、交付标准与边界。
- `ProjectIntegrationCapabilityGap.md`：业务方已确认的输入、富文本和降级要求与组件能力对照。
- `SourceManifest.md`：应随版本交付的源码、依赖、资源和许可证清单。
- `CHANGELOG.md`：本候选版本变更与已知限制。
- `Checksums.sha256`：冻结候选内容的 SHA-256 完整性清单。

当前已知证据：旧交付源码及本地依赖此前通过 iOS 15 Simulator Debug/Release 独立构建；仓库源码的 HTML 展示与挖空标签 Review 及测试见 [CustomClickableSpanReview.md](./CustomClickableSpanReview.md)。两类证据对应不同源码快照，不能合并为更新后交付包的验证结果。目录内较早的项目计划和能力差距表记录当时状态；当前决策以 [NextSessionHandoff.md](./NextSessionHandoff.md) 为准。

组件源码与第三方依赖在候选冻结时从仓库复制到本目录的 `Sources/`、`Dependencies/` 和 `Licenses/`；组件资源随 `Sources/Assets/` 交付。版本哈希暂不视为冻结；本次文档更新及后续源码同步后，均须在交付整理结束时重新生成哈希清单。下一步先整理交付包，真实项目接入随后进行。
