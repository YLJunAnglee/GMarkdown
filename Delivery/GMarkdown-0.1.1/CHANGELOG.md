# 0.1.1 候选变更

- 分块渲染冻结为首发主路径。
- HTML 改为白名单、非执行式展示；Mermaid 和 HTML 预览关闭。
- 表格异常输入安全降级，避免越界和 `fatalError`。
- 容器尺寸驱动布局；统一最低 iOS 15。
- 修复分块文本选择复制、普通链接回调、缓存成本与生命周期清理。
- 同步已提交的受控编辑器 HTML 展示：显式 `GMarkHTMLProcessor.process(html:)` 解析常见段落、行内样式、数字实体、方向与有限 CSS，再由 `GMarkdownMultiView` 展示。
- 同步 `CustomClickableSpan` 的文字和 UTF-16 标记范围；MultiView 文本块绘制 `#4F5CE7` 点状虚线。点击、挖空及恢复仍待业务规则确认。
- 同步 Markdown 路径的 `GMarkRenderIssue` 通知与可报告异步结果的 `GMarkReportingImageLoader` 接口；原有图片 loader 保持兼容。
- 修正交付包验证清单的 CSS 资源处理，使默认代码高亮主题位于高亮器读取的 bundle 根目录。
- 保留公式、表格、图片、代码块和受控降级的既有模拟器验收证据。
- 候选交付目录已同步本轮提交的组件源码，并保留锁定 revision 的依赖源码、资源和许可证；当前清单与构建结果见 `SourceManifest.md`。候选尚未冻结或发布。

## 已知限制

- 尚无真机 Release 性能、滚动和内存基线。
- 历史最小宿主已由用户确认在模拟器中构建并启动；本轮交付源码的独立编译结果见 `SourceManifest.md`，原生 Xcode framework target 接入及业务页面尚未验证。
- TextView 行内公式对齐、超宽行内公式和链接内公式不属于首发承诺。
- iPhone 横屏不属于首发范围。
