# GMarkdown 项目适配执行基线

> 历史项目适配计划：下文“`richTxt` 尚未实现”和“组件仍缺通知”等结论描述当时进度。受控 HTML、`CustomClickableSpan` 展示及 Markdown 路径的失败/降级通知现已在仓库实现并同步到候选交付包。当前能力边界见 [RichTxtHTMLSupportScope.md](./RichTxtHTMLSupportScope.md)；真实业务工程仍未接入。

状态：**阶段 1 的真实书籍数据盘点与已定义样本回归已完成；业务方已补充 `richTxt`、`CustomClickableSpan` 和失败降级要求。下一步按[项目接入执行计划](./ProjectIntegrationExecutionPlan.md)补齐明确缺口。** 本文是已有结果与接入基线的入口。

## 当前交接点（2026-09-29）

新窗口继续时，先阅读本文、[项目接入执行计划](./ProjectIntegrationExecutionPlan.md)、[项目接入需求与能力对照](./ProjectIntegrationCapabilityGap.md) 和 [项目 Markdown 兼容性矩阵](./ProjectMarkdownCompatibilityMatrix.md)。`wordIndexBeans` 已由业务方决定暂不接入；需要使用时再按[候选接入规格](./WordIndexBeansAdoptionSpec.md)讨论。

### 已完成并提交

| 提交 | 内容 | 结论 |
| --- | --- | --- |
| `e19e58c` | 9 本脱敏书籍（1,675 块）的内容类型盘点；公式原文保真回归 | 阶段 1 的内容类型均已有归属。 |
| `86cad43` | 真实 `\\tag{…}` 公式 TAG-01～TAG-04 的正式分块路径 UI 回归 | 编号、中文、花括号、连续编号、`cases`/`aligned` 和 HTML 后续公式边界均为默认支持；不需组件扩展。 |
| `f2ed004` | 真实 Markdown/HTML 图片的安全降级 UI 回归 | 无资源/语义占位图保留 `alt`，不吞并正文；不等同于真实图片下载成功。 |

### 当前明确结论

- Demo 基础能力已验收；本阶段没有重复执行它，也没有接入业务源码或做真机验证。
- 真实书籍没有已编码的块级业务 DSL，也没有非默认的 `hiddenBlock`、`problem`、`flip` 样本；**不要预先实现自定义业务块识别**。
- 真实图片资源没有随包提供。当前只能确认 `alt` 安全降级；业务若要求真图，必须另提供可访问的脱敏 URL/资源、鉴权方式、缓存/失效规则和失败文案。
- `wordIndexBeans` 是原始 Markdown 的 UTF-16 半开位置范围 `[start, end)`，不是富文本、关键词高亮或挖空标记。其范围会与公式和代码重叠，不能直接套用到解析后的富文本。

### 当前下一步：补齐实际业务要求的组件能力

2026-09-29 业务方补充了此前导出样本未覆盖的 `richTxt` 使用规则和 `<CustomClickableSpan>` 样本。`richTxt` 有内容时优先展示，空时才展示 `txt`；标准 HTML 富文本需要呈现正文和阅读样式；自定义标签标记可挖空文字，当前底部有虚线下划线。单独图片无法显示时由项目自定义 Cell 兜底。组件仍缺统一的渲染失败/受控降级通知。逐项结论见[能力对照](./ProjectIntegrationCapabilityGap.md)，实施顺序见[执行计划](./ProjectIntegrationExecutionPlan.md)。

`wordIndexBeans` 暂不使用、不展示、不接入；这不阻断上述能力工作。不要重新进行已通过的 Demo 基础验收。

## 已确认的结论

1. **基础渲染能力已通过 Demo 验收。**
   在已记录的模拟器范围内，Markdown、LaTeX、表格、代码高亮与 Copy、图片/长图、受限 HTML、Mermaid 源码、深色模式、Dynamic Type、iPhone/iPad 适配、异步加载和重复进入均无阻塞问题。
2. **项目 `txt` 内容已盘点，新增的 `richTxt` 要求尚未实现。**
   9 本导出书籍中的 `txt` 类型已有归属；业务方另提供了编辑器 HTML 富文本和 `<CustomClickableSpan>` 样本，见[能力对照](./ProjectIntegrationCapabilityGap.md)。真实图片 URL/鉴权、业务链接协议及业务工程页面结构仍未核对。
3. **现有项目的源码接入暂缓。**
   交付源码已完成本地 iOS 15 Simulator Debug/Release 编译验证；干净 Xcode framework target 接入不在当前阶段执行。

## 项目可接入的两个必要条件

### 条件一：真实项目数据兼容

对代表性的真实或脱敏 Markdown 数据逐块确认：

- 默认 GMarkdown 是否能按内容和业务样式正确展示；
- 哪些内容可以安全降级；
- 哪些业务格式必须由项目自定义展示；
- 图片加载、鉴权、链接跳转和内容更新由宿主如何接管。

完成标准：每一种实际内容类型都有明确归属——默认渲染、可接受降级、项目自定义块或待扩展；不存在无归属的内容类型。

### 条件二：源码方式接入现有项目

在条件一完成且扩展实现后：建立独立 `GMarkdown` framework target，加入交付的 `Sources/`、资源和依赖模块，编译并在业务工程打开真实内容。详见 [Integration.md](./Integration.md)。

完成标准：Debug/Release 构建通过，资源与许可证完整，真实内容可打开，业务图片/链接回调生效。真机和 iOS 15 运行时验证按资源可用性另行补充。

## 阶段 1：真实项目数据兼容性盘点

输入：从项目导出或脱敏后的代表性书籍/章节 Markdown。应包含典型正文、复杂章节、图片、公式、表格、代码、链接和已知特殊格式；不要只提供“正常文本”。

执行：

1. 以源 Markdown 为单位建立样本清单，记录书籍/章节、来源、内容类型、截图和期望样式。
2. 使用 `GMarkProcessor` + `GMarkdownMultiView` 走当前正式分块路径展示样本。
3. 为每种内容给出以下结论之一：
   - **默认支持**：直接由组件渲染；
   - **可接受降级**：保持可读原文或占位即可；
   - **需要项目自定义块**：由项目提供专用样式/交互；
   - **需要组件扩展**：当前没有足够的识别或渲染能力。
4. 输出《项目 Markdown 兼容性矩阵》，作为后续实现与回归样本。

阶段 1 的重点是确认“业务要什么”，不是再重复 Demo 的基础能力验收。

## 阶段 2：扩展能力

### 2.1 必做：已确认的富文本、业务标签与失败降级接口

按[能力对照](./ProjectIntegrationCapabilityGap.md)实现 `richTxt` 优先规则、编辑器 HTML 富文本的受控展示，以及实际出现的行内 `<CustomClickableSpan>` 标签范围和底部虚线。组件还须向宿主报告可识别的渲染失败与受控降级，供宿主选择业务兜底。不能仅通过视觉结果推断业务是否接受降级，也不能让失败日志代替公开回调。

当前 9 本书的 `txt` 没有已编码的块级业务 DSL，因此不预先开发 `:::exercise` 等通用块级识别框架。自定义标签的点击、挖空和恢复规则尚未口述，先保留范围与显示契约，不猜测业务状态机。

### 2.2 条件实施：宿主列表混排的单块渲染能力

仅当目标页面由业务 `UITableView`/`UICollectionView` 混排时实施。当前正式阅读路径是 `GMarkdownMultiView` 内部持有 `UICollectionView`，适合整篇/整章阅读。不要把完整可滚动的 `GMarkdownMultiView` 直接嵌套进业务 `UITableViewCell`：会产生嵌套滚动、动态高度、复用和性能风险。

需要补充可由宿主列表使用的单块能力：

```text
Markdown → Parser / ChunkGenerator → [GMarkChunk]
                                      ↓
                          单块渲染/尺寸计算接口
                                      ↓
                    宿主 UITableView / UICollectionView Cell
```

目标是让业务列表控制滚动、顺序、复用及普通业务 Cell；GMarkdown 只负责标准 Markdown 块的渲染和尺寸。自定义业务块可直接使用项目自己的 Cell。

## 推荐执行顺序

1. 先拿真实项目数据完成阶段 1，产出兼容性矩阵。
2. 根据业务方新增的 `richTxt` 和失败降级要求完成 2.1；仅对新增能力做定向验证。
3. 如果项目页面确实是业务列表混排，再完成 2.2；若页面是独立阅读页，继续使用 `GMarkdownMultiView`，无需为了抽象而提前实现 2.2。
4. 用真实数据回归通过后，再执行条件二的源码接入。

## 当前明确不做

- 不重复执行已经通过的 Demo 基础渲染验收；除非相关代码发生变更。
- 在 2.1 的能力缺口关闭前，不创建干净 Xcode framework target 或接入现有项目。
- 不将 Mermaid 变成图形预览，不执行 HTML/JavaScript，不引入 WebView。
- 真机 Release 性能、内存和 iOS 15 运行时在设备可用后补测。
