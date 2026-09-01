# GMarkdown TABLE 公式后端注入契约

## 状态

- 开发基线：`3ad09372d46c40e864bc47c2560ca78cb962205f`，包含原生 TABLE 候选
  `c7880ee7550bba24959b25004982ad67a5a7f3d5` 和第 9 步包体评估文档。
- 开发分支：`feature/formula-backend-injection`。
- 本改动已形成独立 revision 并发布到 `feature/formula-backend-injection`；AIEndorser 已获准锁定该分支的
  最终 revision，但 BookNext adapter 与生产 Renderer 接入仍属于后续独立步骤。
- 2026-09-01，用户在 iPhone 17 / iOS 26.3.1 模拟器完成发布前 review 后的完整 Package Tests：
  33 passed、0 failed；其中原有 25 项继续通过，当前公式注入契约 8 项全部通过。
- 最终契约包含 diagnostic payload 排除、无效图片尺寸 fallback、cache-hit diagnostic duration 归零，
  并将 fallback reason 收紧为库定义的封闭稳定代码、backend revision 改为无正文数值标识；同时补齐
  configured last-result、fallback 不缓存和 configured async 成功/拒绝/取消回归。Swift parse 与
  `git diff --check` 同时通过，当前不存在待重跑项。

## 目标与边界

本改动只让单 TABLE 公共入口接受调用方提供的同步公式 renderer，不依赖 AIEndorser、BookNext 或任一
业务类型。它关闭 TABLE cell 静默绕过调用方公式可信边界的问题，但不把同步 visitor 伪装成后台渲染，
也不改变现有无 configuration API 的 legacy 行为。

注入协议固定以下边界：

1. `GMarkFormulaRendering.cacheIdentity` 必须随 analyzer、dialect、capability 或 backend revision 改变；
2. request 只传公式 payload、容器、字体、颜色、最大宽度、scale 和 trait；
3. renderer 只返回成功图片及 intrinsic size，或库定义的稳定 `reasonCode` fallback；成功和失败均返回
   `GMarkFormulaBackendRevision` 数值标识；
4. GMarkdown 继续负责 attachment、最大宽度适配、TABLE attributed string 和布局；
5. 注入 renderer fallback 后不得再次调用 `GMarkLaTexRender`；
6. 注入 renderer 自己治理公式图片/SVG cache，GMarkdown TABLE cache 只保存最终 prepared layout。

## 公开入口

旧入口保持不变：

```swift
let result: NativeMarkdownTableRenderResult = tableView.render(
    markdown: markdown,
    containerWidth: width
)
```

注入入口使用独立 configuration 和独立结果类型，避免给旧公开失败枚举增加 case 而破坏调用方的穷举
`switch`：

```swift
let configuration = NativeMarkdownTableFormulaConfiguration(
    renderer: renderer,
    failurePolicy: .rejectWholeTable
)

let result: NativeMarkdownTableFormulaRenderResult = tableView.render(
    markdown: markdown,
    containerWidth: width,
    formulaConfiguration: configuration
)
```

同步和可取消的 `renderAsync` 均提供 configuration overload。现有取消语义不变：只阻止未开始任务、
过期 apply 和 completion，不宣称中断已经进入的同步 renderer。

配置入口的最近一次完整结果读取 `lastFormulaRenderResult`；原 `lastRenderResult` 保留为旧结果类型的兼容
投影，不能表达新增的逐公式失败。

## 失败策略与诊断

- `rawFormula`：精确保留带 delimiter 的公式原文，成功 TABLE metrics 同时返回 fallback warning 和逐公式
  diagnostics；不会调用 legacy renderer 补画。
- `rejectWholeTable`：任一注入公式 fallback 时，清空旧内容并返回
  `NativeMarkdownTableFormulaRenderFailure.formulaRenderingFailed`，不应用半成品。
- diagnostics 只包含零基 ordinal、row、column、header 标记、container、库定义 reason、数值 backend
  revision 和 duration；构造器不公开，类型无法接收任意 reason/revision 字符串，也没有 LaTeX、SVG、
  URL、图片或正文属性。
- 非法图片尺寸或 intrinsic size 会分别转换为 `invalid-image-size` / `invalid-intrinsic-size` fallback。

## 缓存身份

`NativeMarkdownTableRenderCacheKey` 已加入：

- `formulaRenderer.cacheIdentity`；
- `NativeMarkdownTableFormulaFailurePolicy`；
- renderer version `native-table-v3`。

相同 layout/style/trait/scale 下，identity 或 failure policy 改变均必须 cache miss；相同 identity 与 policy
可以复用全部公式成功的 prepared TABLE。含 configured formula fallback 的 TABLE 不写入 prepared cache，
避免同 identity 下的临时失败阻止后端恢复重试。注入路径不会调用 `GMarkLaTexRender`，因此不会把注入
结果再写入它的全局公式图片 cache。

## 自动化验收

当前 `GMarkFormulaInjectionTests` 共 8 项，覆盖：

1. header/body、多公式 cell 按统一 ordinal 只进入 fake renderer；
2. `rawFormula` 精确保留失败公式原文且不回穿 legacy；
3. `rejectWholeTable` 返回类型级无正文结构化失败、同步更新 `lastFormulaRenderResult` 并清除旧内容；
4. configured fallback 不进入 prepared cache，同 identity 后端恢复时会重新调用 renderer；
5. renderer identity 与 failure policy 分别参与 cache；
6. 旧无 configuration API 继续成功且没有注入 diagnostics；
7. configured async reject 返回结构化失败并同步最近结果；
8. configured async 继续保持 newest-wins/cancellation 语义。

当前证据只关闭依赖层注入契约及原有 Package 回归，不代表 AIEndorser 已完成 adapter、两份
`Package.resolved` 更新、真实 TABLE 页面、三设备视觉、性能或生产放行。
