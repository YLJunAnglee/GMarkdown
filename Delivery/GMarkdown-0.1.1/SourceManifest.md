# 源码与资源交付清单

这是 0.1.1 候选版本的冻结前清单。`Checksums.sha256` 必须在候选提交冻结后由实际交付目录生成，不能使用仓库路径或旧提交代替。

## 组件源码

- `Sources/Generator/`
- `Sources/Helper/`
- `Sources/MarkdownTextView/`（诊断路径，仍随源码交付但不进入首发承诺）
- `Sources/Parser/`
- `Sources/Render/`
- `Sources/Visitor/`

## 组件资源

- `Sources/Assets/Highlighter/highlight.min.js`
- `Sources/Assets/styles/` 中实际启用的默认浅色/深色代码主题

Mermaid 执行资源、HTML/WebView 预览资源不应出现在首发交付目录。

## 依赖与许可证

- swift-markdown 0.4.0（revision `4aae40bf6fff5286e0e1672329d17824ce16e081`）
- swift-cmark 0.4.0（revision `3bc2f3e25df0cecc5dc269f7ccae65d0f386f06a`，swift-markdown 传递依赖）
- MPITextKit 0.2.4（revision `6b2e616f2648bcb7e3bc1c739bac3fb4a2626eec`）
- SwiftMath 2.0.0（revision `1e49ab4e85eeb0986d0a63d1ca68f8a4b0b964d5`）
- MathJaxSwift 3.4.0（revision `e23d6eab941da699ac4a60fb0e60f3ba5c937459`）
- Highlightr 资源与对应许可证（仓库内资源，待交付目录复制时核对来源文件）
- `LICENSES/` 中逐项保存许可证和来源 URL

源码文件夹交付不能只携带 GMarkdown 的 Swift 文件；上述依赖源码、许可证和资源必须在候选冻结时实际复制到交付目录并纳入哈希清单。

## 交付前生成

```text
候选提交：
版本：GMarkdown-0.1.1
文件总数：
资源总大小：
哈希清单生成时间：
Release 构建产物：待补
最小宿主构建产物：待补
真机基线报告：待补
```
