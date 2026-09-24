# 源码与资源交付清单

这是 0.1.1 候选版本的交付清单。组件源码、锁定 revision 的依赖源码、资源和许可证已复制到本目录；`Checksums.sha256` 于 2026-09-24 按当前目录重新生成，用于完整性核对，但候选版本尚未冻结，不能用仓库路径或旧提交代替。

## 组件源码

- `Sources/Generator/`
- `Sources/Helper/`
- `Sources/MarkdownTextView/`（诊断路径，仍随源码交付但不进入首发承诺）
- `Sources/Parser/`
- `Sources/Render/`
- `Sources/Visitor/`
- `Package.swift`（仅用于验证交付源码和本地依赖能独立构建；不改变源码文件夹接入契约）

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
- `highlight.js` 9.13.1 资源（`Sources/Assets/Highlighter/highlight.min.js`）与 BSD 3-Clause 许可证
- `Licenses/` 中逐项保存许可证和来源 URL

本候选目录已包含 `Sources/`、`Dependencies/`、`Licenses/` 和组件资源。依赖目录按锁定 revision 复制；源码文件夹接入不要求这些依赖仓库的 Package manifest，但本目录的验证清单会使用它们检查依赖图。许可证范围和资源包已核对；真机性能/内存基线仍不在本候选的声明范围内。

## 交付前生成

```text
候选提交：冻结前待写入
版本：GMarkdown-0.1.1
文件总数：以 Checksums.sha256 条目为准（不含清单自身）
资源总大小：已随当前候选目录收集，待版本冻结时确认
哈希清单生成时间：2026-09-24（当前规划基线，非冻结版本）
Release 构建产物：iOS 15 Simulator target 已通过
最小宿主构建产物：独立最小宿主 Debug/Release 已通过
真机基线报告：待补
```
