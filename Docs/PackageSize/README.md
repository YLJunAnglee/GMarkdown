# GMarkdown 原生表格包体积评估与轻量化决策

## 结论

第 9 步的 Release Archive/IPA 成对测量已完成。

- 完整候选 `c7880ee` 相对无 GMarkdown 基准，IPA 增加 **7.324 MiB**，安装态 `.app` 逻辑文件体积增加 **17.923 MiB**。该结果说明完整依赖当前超过文档中的 `2–4 MiB` 实验目标，但**包体增量只是最终门槛，不能作为提前裁剪业务能力的依据**。
- `c7880ee` 补丁本身相对原库 `c235d3a` 仅增加 **0.033 MiB IPA / 0.067 MiB 安装态**；主要问题不是原生表格补丁，而是完整 Product 携带的 Web 资源、MathJax 资源和 SwiftMath 全量字体。
- D 组资源精简原型的 IPA 增量为 **2.631 MiB**，25 项表格测试全部通过。它只证明资源精简在技术和体积上具有可达性，**不能证明 AIEndorser 所需业务功能已经完整，也不能作为正式交付候选**。
- 已确定的实施顺序是：第 10 步先在 AIEndorser 中使用完整 `c7880ee` 完成真实业务接入和功能验收；再根据实际调用链、业务样例和运行验证识别未使用能力；最后才实施收尾切割并重新验证功能与包体。

## 产品决策（2026-08-25）

本项目采用“**功能完整优先，真实使用验证后再切割，包体作为最终门槛**”的原则。

1. 不为了预先达到包体目标而交付阉割版，也不根据单元测试覆盖情况推断业务一定不需要某项能力。
2. 第 10 步先接入完整候选，保留原生表格、SwiftMath 快速公式渲染、MathJax 复杂公式/SVG 回退以及当前完整资源能力。
3. 在 AIEndorser 真实页面、真实 Markdown 数据和边界样例上完成验收，形成可追溯的“实际使用/未使用”证据。
4. 只有被证明不在目标业务链路中使用，并且移除后完整回归仍通过的代码或资源，才允许进入轻量化范围。
5. 如果某项能力是功能完整性所必需，即使它增加包体也必须保留；若因此无法满足最终包体门槛，应继续寻找无损优化方案或明确报告目标冲突，不能通过破坏功能来过门槛。
6. D 组数据作为后续优化线索保留，不预先固化为最终切割清单。正式 `GMarkdownTable` Product 是否需要、包含哪些能力，应在业务接入和真实依赖盘点后决定。

## 测量条件

- 日期：2026-08-25。
- Xcode：26.2（Build 17C52）。
- 宿主：AIEndorser SVN 工作副本 `r6024`，测量开始和结束时均无本地修改。
- App：`com.xiandao.dd.aiendorser`，版本 2.3.5（Build 1）。
- Scheme：`AIEndorser`。
- 配置：Release、generic iOS device、arm64、相同自动签名配置。
- 每组使用独立 DerivedData；均执行 `clean archive`。
- 四组 Archive 均成功，随后使用同一份 Development ExportOptions 导出 IPA，四次导出均成功。
- Development 导出用于同配置成对比较；最终正式结论仍应在发布方式确定后用同一发布 ExportOptions 复核一次。

## 对照组

| 组别 | 配置 | 用途 |
| --- | --- | --- |
| A | 相同 AIEndorser revision，移除 GMarkdown Package | 接入前基准 |
| B | GMarkdown `c235d3a8d884f8da308236f84a894421287ef3c9` | 原始完整依赖 |
| C | GMarkdown `c7880ee7550bba24959b25004982ad67a5a7f3d5` | 原生表格候选 |
| D | C 的临时资源精简原型；保留完整源码、MathJax 和 XITS 字体 | 验证轻量资源范围是否可达 |

D 组仅存在于临时测量副本，不是最终独立 `GMarkdownTable` Product，也没有修改 AIEndorser 或 GMarkdown 的正式生产源码。它不参与业务接入决策，只提供包体构成和潜在优化空间的数据。

## 结果

以下 `.app` 和主二进制数值为逻辑文件字节之和；IPA 为导出文件实际大小。

| 组别 | IPA | 相对 A | `.app` | 相对 A | 主二进制 | 相对 A |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A 无 GMarkdown | 63.209 MiB | — | 112.436 MiB | — | 58.104 MiB | — |
| B 原始完整库 | 70.500 MiB | +7.291 MiB | 130.292 MiB | +17.855 MiB | 60.555 MiB | +2.450 MiB |
| C `c7880ee` 完整库 | 70.533 MiB | +7.324 MiB | 130.359 MiB | +17.923 MiB | 60.622 MiB | +2.517 MiB |
| D 资源精简原型 | 65.840 MiB | **+2.631 MiB** | 121.082 MiB | **+8.645 MiB** | 60.637 MiB | +2.533 MiB |

关键差值：

- C - B：`+0.033 MiB IPA / +0.067 MiB .app`，全部逻辑文件增量来自主二进制。
- D - C：`-4.694 MiB IPA / -9.277 MiB .app`。

## 完整方案的资源占用

| 资源束 | 安装态逻辑体积 | IPA 内压缩体积 | 说明 |
| --- | ---: | ---: | --- |
| `GMarkdown_GMarkdown.bundle` | 3,050,420 B | 943,381 B | Mermaid、代码高亮和 CSS |
| `MathJaxSwift_MathJaxSwift.bundle` | 5,698,292 B | 1,332,830 B | MathJax SVG/CHTML/MML/语音等资源 |
| `SwiftMath_SwiftMath.bundle` | 7,363,950 B | 4,322,574 B | 11 套数学字体及 plist |
| 合计 | 16,112,662 B（15.366 MiB） | 6,598,785 B（6.293 MiB） | 完整方案的主要增量来源 |

GMarkdown 自有资源继续拆分：

- Mermaid：2,298,635 B，IPA 内约 677,299 B。
- `highlight.min.js`：682,543 B，IPA 内约 234,096 B。
- CSS：68,561 B，IPA 内约 30,260 B。

## D 组实验范围

- 保留 MathJaxSwift，以维持当前复杂/长公式的 SVG 回退链路。
- SwiftMath 仅保留当前 `GMarkLaTexRender` 明确使用的 XITS：
  - `xits-math.otf`
  - `xits-math.plist`
  - 相关许可证
- 移除其他 10 套数学字体及其 plist。
- 移除 Mermaid、`highlight.min.js` 和全部 CSS；临时原型只保留一个极小资源以维持完整版源码中 `Bundle.module` 的编译条件。

以上范围是为了测量体积可达性而设置的实验变量，不代表这些能力已被确认可以从 AIEndorser 正式版本中移除。特别是“当前代码明确使用 XITS”只能说明静态实现现状，不能替代真实公式样例和业务页面回归。

D 组相关资源束合计：

- 安装态逻辑体积：6,401,205 B。
- IPA 内压缩体积：1,714,638 B。

## 验证

- A/B/C/D 四组 AIEndorser Release Archive：全部成功。
- A/B/C/D 四组 Development IPA 导出：全部成功。
- D 组 Swift Package 测试环境：iPhone 16 Pro、iOS 18.6。
- 测试结果：25 个通过、0 失败、0 跳过，总测试时间约 0.64 秒。
- 测试日志确认 XITS 字体和 `xits-math.plist` 成功注册，公式缓存、表格解析、布局、复用、缓存与公共 API 测试均通过。
- AIEndorser Workspace 锁定的 MathJax 3.5、swift-markdown 0.8 环境已完成 D 组 Release Archive；该 Workspace 自动生成的 GMarkdown Scheme 没有 Test Action，因此测试集通过 Package Scheme 执行。
- 上述验证足以证明 D 组能够编译、归档且现有 Package 测试通过，但不覆盖 AIEndorser 的真实页面接入、完整业务 Markdown 数据、交互表现以及所有公式回退场景，因此不能把“25 项测试通过”等同于“业务功能完整”。

## 后续执行顺序与验收约束

### 阶段一：完整业务接入

1. AIEndorser 先接入完整 `c7880ee`，暂不以 D 组方式裁剪资源。
2. 接入范围必须覆盖项目实际使用的原生表格入口、渲染流程、页面生命周期和数据刷新链路。
3. 保留 SwiftMath 快速路径和 MathJax 复杂公式/SVG 回退，不提前删除字体、Web 资源或兼容路径。

阶段一验收标准：

- A/B/C 既有样例和 25 项 Package 测试继续通过。
- AIEndorser 真实 Markdown 数据中的普通表格、复杂表格、表格内行内/块级公式、长公式和回退场景显示正确。
- 布局、滚动、复用、缓存、异步刷新和页面退出后的任务安全符合业务预期。
- 与替换前链路进行可见结果对照，不出现功能缺失、内容丢失、崩溃或明显性能退化。

### 阶段二：真实依赖盘点

1. 结合静态引用、运行路径、业务数据和验收记录，列出每项资源/能力的使用证据。
2. 对 Mermaid、代码高亮、CSS、SwiftMath 其他字体、MathJax 各能力以及旧渲染链路分别判断：保留、可移除或仍需补充验证。
3. “没有在当前代码中直接引用”不能单独作为删除依据；动态资源加载、回退路径和未来仍在本次需求范围内的样例都要纳入判断。

阶段二产出：一份明确的依赖清单和切割清单，每个拟移除项都应包含“不影响哪些已验收功能”的证据。

### 阶段三：收尾切割与正式复核

1. 只移除阶段二已经证明未使用的内容；需要独立轻量 Product 时，必须复用现有表格解析、布局、缓存和公共 API，不复制第二套实现。
2. 切割后重新执行阶段一全部功能验收和自动化测试，任何功能回退都应恢复相应能力，而不是降低验收标准。
3. 使用与正式发布一致的配置重新生成 Release Archive/IPA，并与无 GMarkdown 基准做同口径比较。
4. 功能完整且包体满足正式门槛后才能最终放行；若功能完整与包体门槛冲突，应记录实际数据并单独决策，不交付阉割版。

当前放行结论：**允许进入第 10 步的完整业务接入；暂不执行正式资源切割，也不把 D 组作为 AIEndorser 的接入版本。**

## 临时产物

本次测量工作目录为 `/private/tmp/gmarkdown-size.bIFpMV`，包含四组临时工程、Archive、IPA、DerivedData 和测试 xcresult。该目录不属于正式源码或长期归档位置。
