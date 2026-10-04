# GMarkdown 0.1.1 交付目录（候选）

状态：**已提交的组件源码已同步到 0.1.1 候选交付包；真实项目尚未接入，未声明 L1/L2，也未冻结或发布**。[NextSessionHandoff.md](./NextSessionHandoff.md) 保留整理前的历史交接记录。

首发分发方式计划为源码文件夹。仓库 `Sources/` 中已提交的受控编辑器 HTML 与 `CustomClickableSpan` 展示实现已同步到本目录的 `Sources/`。业务自行选择 `richTxt` 或 `txt` 输入；组件不读取业务字段。交付包状态与本轮检查结果见 [SourceManifest.md](./SourceManifest.md)。真机 Release 性能/内存和 iOS 15 实机运行未测，因此不声明 L1/L2。

## 目录组成

- `NextSessionHandoff.md`：当前决定及下次开机后的交付整理步骤。
- `Integration.md`：接入、升级、回退和能力边界。
- `DemoAcceptanceChecklist.md`：已完成的 Demo 能力验收与证据记录。
- `ProjectAdoptionPlan.md`：项目适配和源码接入执行基线。
- `ProjectIntegrationExecutionPlan.md`：当前接入任务的实施顺序、交付标准与边界。
- `ProjectIntegrationCapabilityGap.md`：业务方已确认的输入、富文本和降级要求与组件能力对照。
- `SourceManifest.md`：应随版本交付的源码、依赖、资源和许可证清单。
- `CHANGELOG.md`：本候选版本变更与已知限制。
- `Checksums.sha256`：当前候选内容的 SHA-256 完整性清单；不代表已冻结。

仓库源码的 HTML 展示与标记 Review 及历史测试见 [CustomClickableSpanReview.md](./CustomClickableSpanReview.md)。本轮交付检查只编译和核对已同步源码，没有重复 Demo 验证。目录内较早的项目计划和能力差距表是当时状态记录；当前展示范围以 [RichTxtHTMLSupportScope.md](./RichTxtHTMLSupportScope.md) 为准。

组件源码、锁定的第三方依赖、许可证和 `Sources/Assets/` 资源均随本目录交付。`Checksums.sha256` 用于当前候选目录的完整性核对，不代表版本冻结。下一步真实项目接入须另行确认。
