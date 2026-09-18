# 源码与资源交付清单

这是 0.1.1 候选版本的交付清单草案。当前已将组件源码、锁定 revision 的依赖源码、资源和已发现的许可证复制到本目录；`Checksums.sha256` 仍需在候选内容和许可证核验完成后重新生成，不能使用仓库路径或旧提交代替。

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
- `highlight.js` 9.13.1 资源（`Sources/Assets/Highlighter/highlight.min.js`）与 BSD 3-Clause 许可证
- `Licenses/` 中逐项保存许可证和来源 URL

本候选目录当前已包含 `Sources/`、`Dependencies/`、`Licenses/` 和组件资源。依赖目录按锁定 revision 复制，并排除 `.git`、示例、测试和构建产物；源码文件夹接入不使用这些依赖仓库的 Package manifest。许可证文件已按当前依赖和高亮资源补齐，仍需在最终冻结前复核许可证范围与资源包大小，不能将当前目录称为最终发布包。

## 交付前生成

```text
候选提交：待冻结
版本：GMarkdown-0.1.1
文件总数：706（当前候选目录，不含哈希文件）
资源总大小：待核验
哈希清单生成时间：待冻结后生成
Release 构建产物：待补
最小宿主构建产物：模拟器本地 Package 已验证；源码文件夹构建产物待补
真机基线报告：待补
```
