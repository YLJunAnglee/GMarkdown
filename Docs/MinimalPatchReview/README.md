# 原生 TABLE 最小补丁审查

## 审查结论

- 审查基线：上游 `0.1.1`，提交 `c235d3a8d884f8da308236f84a894421287ef3c9`。
- 审查终点：`feature/native-table-rendering` 的 `69c3343`。
- 结论：**实验阶段维护成本有条件可控，可以进入包体积与轻量化决策；当前不等于可以直接接入业务或合并上游。**
- 原因：补丁按解析修复、独立 API、布局样式、缓存与复用分成 6 个可回退提交，测试和样例证据完整；上游已有公共方法没有被删除或改签名。
- 限制：生产代码不是完全零侵入。12 个生产文件中只有 2 个是新增文件，另外 10 个修改了既有实现；其中共享表格布局、默认不限行、滚动修正和公式缓存 Key 会影响原 GMarkdown 入口，升级上游时必须回归。
- 第 9 步必须先确定完整包还是轻量 `GMarkdownTable` Product，并用 Release Archive/IPA 差值作结论；未完成前不更新 AIEndorser 的 GMarkdown revision。

## 补丁规模

相对基线共 43 个文件，文本改动为 `+2642/-180`，另含 11 张验收截图。

| 类型 | 文件数 | 文本改动 | 说明 |
| --- | ---: | ---: | --- |
| 生产代码 | 12 | `+1166/-165` | 需要长期维护和回归的实际补丁 |
| 自动化测试 | 7 | `+732/-12` | Fixture、解析、布局、API、缓存与复用测试 |
| Example | 8 | `+521/-2` | 基线页和独立 API 验证页，不进入库运行路径 |
| 文档与截图 | 15 | `+216/-0` | 步骤 3、5、6、7 的验收证据 |
| Package 清单 | 1 | `+7/-1` | 只为测试 Target 增加 Markdown 依赖和 Fixture 资源 |

生产代码可进一步分成四组：

| 分组 | 文件数 | 文本改动 | 风险 | 审查判断 |
| --- | ---: | ---: | --- | --- |
| 新增独立 API 与缓存 | 2 | `+675/-0` | 低～中 | 对上游入口为新增能力；缓存真实内存和主线程耗时仍需业务数据 |
| TABLE 公式预处理修复 | 1 | `+116/-2` | 中 | 行为限定在已确认的 GFM 表格行，已有表内/表外回归测试 |
| 共享布局、样式与旧入口适配 | 6 | `+259/-143` | 中～高 | 改善三条表格入口的一致性，但也是最大既有行为回归面 |
| 公式缓存与诊断 | 3 | `+116/-20` | 中 | 修复全局公式图片错用风险；会使不同样式分别占用缓存 |

## 生产文件逐项审查

| 文件 | 修改原因 | 影响范围 | 保留结论 |
| --- | --- | --- | --- |
| `Sources/Render/Table/NativeMarkdownTableView.swift` | 暴露单 TABLE 输入、明确成功/失败、同步/可取消入口和指标 | 新增公共 API | 必需；AIEndorser 的最小接入边界 |
| `Sources/Render/Table/NativeMarkdownTableRenderCache.swift` | 按内容、宽度、样式、主题、Scale 和版本缓存已准备布局 | 仅新 API | 必需；第 10～12 步采集真实命中率和内存后再调上限 |
| `Sources/Parser/Preprocessor/GMarkPreprocessor.swift` | 防止长 LaTeX 包装器在 TABLE 行内插入换行并破坏行数 | 所有 Markdown 的 LaTeX 预处理，但分支只命中 GFM 表格 | 必需；逻辑相对独立，可单提交迁移 |
| `Sources/Generator/Table/GMarkTableLayout.swift` | 统一列宽、完整行高、缺列归一、对齐和内容尺寸 | 所有使用该布局器的表格入口 | 必需且为主要维护点；上游升级时优先做三入口视觉回归 |
| `Sources/Render/GMarkStyle.swift` | 默认表格由最多两行改为不限行 | 所有使用默认表格样式的入口 | 功能必需但属于全局行为变化；正式轻量 Product 可把该默认值收敛到 TABLE 产品内部 |
| `Sources/Render/Table/GMarkTableStyle.swift` | 把 Markdown `TableStyle` 映射到原生表格边框和间隔 | 三条原生表格入口 | 必需；映射函数为内部 API，兼容风险低 |
| `Sources/Render/RenderCells/GMarkTableCell.swift` | 让原集合视图入口复用统一列宽、行高和样式 | 原 `GMarkdownMultiView` TABLE | 为兼容共享布局而必需；AIEndorser 不直接调用，但不能不回归 |
| `Sources/MarkdownTextView/Providers/MDTableAttachedProvider.swift` | 让 TextView 附件入口复用统一列宽、行高和样式 | 原 `MarkdownTextView` TABLE | 为兼容共享布局而必需；AIEndorser 不直接调用，但不能不回归 |
| `Sources/Render/Table/GMarkTableView.swift` | 修正无锁定行列时的偏移、内容尺寸、空表负间隔、滚动开关和 gap 背景 | 所有原生表格视图 | 必需但回归面较大；重点验证横向滚动、锁定行列和空表 |
| `Sources/Generator/LaTex/GMarkLaTexRender.swift` | 公式图片缓存 Key 增加字体、字号、颜色、Scale 和渲染方式 | 所有公式渲染入口 | 正确性修复，建议保留；缓存条目可能增加，需看真实内存 |
| `Sources/Visitor/GMarkupVisitor.swift` | 记录公式耗时和纯文本降级次数 | 所有使用 Visitor 的路径，新增只读指标 | 建议保留；没有改变既有成功/失败展示规则 |
| `Sources/Visitor/GMarkupTableVisitor.swift` | 汇总各单元格公式耗时和降级次数 | TABLE Visitor 内部结果 | 必需；字段未暴露到业务 API |

## 公共 API 与兼容性

- 没有删除上游公共类型、方法或属性，也没有改变既有公共函数签名。
- `GMarkTableLayout` 只新增三个只读结果：`columnWidths`、`rowHeights`、`tableContentSize`。
- `GMarkupVisitor` 只新增两个只读诊断值：`latexFailureCount`、`latexRenderDuration`。
- `NativeMarkdownTableView`、结果模型和任务 Token 全部是新增公共 API，不要求原调用方迁移。
- `DefaultTableStyle.maximumNumberOfLines` 从 `2` 改为 `0` 是行为兼容风险，不是编译兼容风险；旧入口会从两行截断变为展示完整内容。
- `GMarkTableLayout` 和 `GMarkTableView` 的计算方式变化会改变旧入口尺寸和滚动表现；虽已由统一测试覆盖，仍需在每次上游同步后执行 Example 三入口回归。
- 新增公开结果枚举由本分支首次引入。未来若继续增加 case，业务侧 `switch` 应保留 `@unknown default` 或统一 fallback，避免后续升级受阻。

## 已有验证证据

- 解析基线与修复：`Docs/TableBaseline/README.md`。
- 独立公共 API：`Docs/NativeTableAPI/README.md`。
- 统一布局与视觉：`Docs/TableLayout/README.md`。
- 缓存、取消和复用：`Docs/TablePerformance/README.md`。
- 当前共 25 个 iOS 模拟器测试，25 个通过、0 失败、0 跳过；覆盖 7 个解析测试、11 个公共 API 测试和 7 个布局/缓存测试。
- Example 已完成编译与 A/B/C 运行截图验证。
- `git diff --check c235d3a..69c3343` 无空白错误。

第 8 步只审查和记录，没有修改生产代码，因此沿用第 7 步的 25 个测试结果；文档提交不需要重复执行 UIKit 测试。

## 仍未解决的问题

1. `renderAsync` 是主队列排队加协作式取消，不会把解析、公式和布局移到后台，也不能中断已经进入的同步 UIKit 工作；必须在 AIEndorser 真实列表测主线程耗时。
2. 表格 LRU 的 cost 使用单元格数量，无法准确代表公式图片和 `MPITextRenderer` 的真实内存；32 项上限只是实验值。
3. 默认不限行、共享布局和 `GMarkTableView` 滚动修正尚未覆盖所有上游使用方式，特别是锁定行列、旋转、iPad 分屏和动态字号。
4. 模拟器自动截图中曾出现表格外围文字图层偶发捕获不全；任务切换测试没有发现旧内容回写，但仍需在真实业务滚动、翻页和截图中复核。
5. 文本选择、复制、横向滚动与页面翻页手势、正反面翻转及多个业务复用页面尚未验证。
6. 当前完整 Package 仍携带 Mermaid、代码高亮、CSS、MathJaxSwift 资源和 SwiftMath 字体；未完成 Release Archive/IPA 前后差值。
7. 尚未与上游后续版本做一次真实合并演练；当前判断只针对固定基线 `c235d3a`。

## 最小补丁与维护规则

当前 12 个生产文件构成“基于共享布局的最小可运行补丁”。不建议直接删掉旧入口适配文件，因为它们与重写后的 `GMarkTableLayout` 必须保持同一尺寸口径。若第 9 步选择轻量化，应以新 Product 隔离依赖和默认样式，而不是复制第二套解析/布局逻辑。

后续维护按以下边界执行：

1. 保持现有 6 个功能提交可独立识别，不把 AIEndorser 业务代码混进 GMarkdown。
2. 同步上游时优先检查 10 个既有文件的冲突，再运行 25 个测试和 Example A/B/C；新增的 2 个文件通常只需做 API 编译检查。
3. 第 9 步只处理 Product、依赖、资源和包体积，不顺带改变渲染行为。
4. 第 10 步以后 AIEndorser 只通过 `NativeMarkdownTableView` 及公开结果接入，不引用 Parser、Visitor、Layout 或内部 Cell。
5. 任一共享入口出现不可接受回归，或轻量 Product 无法把包体积降到约定阈值，应停在实验分支，不扩大接入。

## 第 8 步结论

第 8 步通过。补丁来源、生产文件、影响范围、测试证据和遗留问题均可追踪；维护成本在固定基线和当前实验范围内可控，但带有共享布局回归面和完整依赖包体积两个前置条件。下一步只进行第 9 步“包体积评估与轻量化决策”。
