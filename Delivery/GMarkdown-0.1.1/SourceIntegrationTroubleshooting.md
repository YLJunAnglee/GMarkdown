# 源码文件夹接入排错手册

本文记录将 GMarkdown 及其依赖以源码文件夹方式加入 Xcode 工程时，最容易出现的构建问题、根因和处理方式。适用于 iOS 14+、Swift 5、独立 framework target 的接入方式。

## 推荐的 target 结构

不要把所有源码直接加入业务 App target。建议建立独立 target，并让依赖关系保持单向：

```text
App
└── GMarkdown
    ├── Markdown
    ├── MPITextKit
    ├── SwiftMath
    ├── MathJaxSwift
    ├── cmark-gfm
    ├── cmark-gfm-extensions
    └── CAtomic
```

每个依赖只加入一个 target。业务 App 只链接最终需要的 framework，不要同时保留同一依赖的 Swift Package、源码 target 和手工 framework 三种来源。

## 接入前的基本检查

1. 删除或暂时移除旧的 GMarkdown Swift Package 依赖；源码接入和 Package 接入不能同时存在。
2. 确认每个源码 target 的 `Target Membership` 正确，文件没有同时加入 App target 和 framework target。
3. 确认 GMarkdown target 的 `Target Dependencies` 与 `Link Binary With Libraries` 指向源码 target 生成的 framework。
4. 将各依赖的资源包加入对应 framework 的 `Copy Bundle Resources`，特别是 SwiftMath、MathJaxSwift 和 GMarkdown 的资源。
5. 全部依赖统一最低 iOS 版本和 Swift 语言版本；源码接入阶段先关闭 `BUILD_LIBRARY_FOR_DISTRIBUTION`，避免旧源码被模块稳定性检查放大成大量无关错误。
6. 修改工程文件后，如果 Xcode 提示工程文件在外部被修改，选择 **Use Version on Disk**，然后重新打开工程并执行 Clean Build Folder。

## 常见错误与解决方案

### 1. `Bundle has no member 'module'`

典型错误：

```text
Type 'Bundle' has no member 'module'
```

原因：`Bundle.module` 是 Swift Package Manager 为目标生成的资源访问入口。将源码直接加入 Xcode framework target 时，Xcode 不会生成这个接口。

处理方式：

```swift
private final class GMarkdownBundleToken {}

private static let resourceBundle = Bundle(for: GMarkdownBundleToken.self)
```

对 MathJaxSwift、SwiftMath、GMarkdown 等各自的资源访问点使用对应 target 内的 bundle token。若文件同时需要继续支持 SPM，保留条件编译：

```swift
#if SWIFT_PACKAGE
let bundle = Bundle.module
#else
let bundle = Bundle(for: GMarkdownBundleToken.self)
#endif
```

不要把 `Bundle.main` 作为 framework 资源的通用替代方案；它在宿主 App 中容易找不到 framework 自带资源。

### 2. `private module exists but no private headers`

典型错误：

```text
private module exists but no private headers
```

原因：手工指定的 module map 被 Xcode 的模块验证器当作包含 private module，但工程没有完整的 private headers 配置。

处理方式：

- 为需要导入的源码 framework 提供明确的 module map 和公共 umbrella header。
- 公共头文件加入 target 的 `Headers` Build Phase，并设为 `Public`。
- 源码接入阶段设置：

```text
BUILD_LIBRARY_FOR_DISTRIBUTION = NO
ENABLE_MODULE_VERIFIER = NO
```

这两个设置只解决旧源码的手工模块化问题，不代表可以忽略头文件可见性；正式交付仍要检查 public header 是否完整。

### 3. cmark 大量 `Redefinition` 或 `Typedef redefinition`

典型错误：

```text
Redefinition of 'delimiter'
Typedef redefinition with different types
Redefinition of 'cmark_chunk'
```

原因通常不是 cmark 源码本身损坏，而是同一套 C 头文件被两个模块映射同时扫描：例如原有 `src/include/module.modulemap`、Xcode 自动模块发现、手工 module map 或 Swift Package 产物同时存在。

处理方式：

1. 只保留一种 cmark 来源：源码 target；移除旧 Package 依赖。
2. 对 cmark-gfm 和 cmark-gfm-extensions 分别提供唯一的 module map。
3. 将源码自带、会被自动发现的 `src/include/module.modulemap` 改名为非 `.modulemap` 文件，避免 Xcode 重复加载。
4. 通过 umbrella header 明确导出公共头文件，不要让多个 module map 互相覆盖。
5. cmark target 设置 `CLANG_ENABLE_MODULES = NO`，并设置 `DEFINES_MODULE = YES`、`MODULEMAP_FILE` 指向唯一的自定义 module map。

示意：

```text
framework module cmark_gfm {
    umbrella header "<工程内>/cmark-gfm/cmark_gfm_umbrella.h"
    export *
}
```

修复后应使用全新 DerivedData 再编译；旧 DerivedData 可能仍携带已经删除的 module map 路径。

### 4. SwiftMath / MPITextKit 出现 UIKit 或 Foundation 类型不可用

典型错误：

```text
missing import of defining module 'UIKit'
FOUNDATION_EXPORT: unknown type name
```

原因：原项目可能依赖隐式导入，拆成独立 framework 后，每个公共头或 Swift 文件必须显式导入所使用的系统模块。

处理方式：

- 使用 UIKit 类型的 Swift 文件显式加入：

```swift
#if canImport(UIKit)
import UIKit
#endif
```

- 使用 `FOUNDATION_EXPORT`、`NSString`、`NSDictionary` 等 Foundation 类型的公共头在宏定义后加入：

```objc
#import <Foundation/Foundation.h>
```

- 检查 target 的 `Frameworks and Libraries` 中是否链接 UIKit、Foundation（Foundation 通常由系统框架隐式提供，但公共头仍应显式导入）。

### 5. `MTColor`、`MTLabel` 等 UIKit 类型被识别成错误 alias

典型错误：

```text
'MTColor' aliases 'UIKit.UIColor' and cannot be used...
```

这通常是前一个“缺少 UIKit 导入”错误的级联结果。先补齐 `import UIKit` 并重新编译，不要立即修改类型别名、类名或 API。

### 6. Xcode 错误列表仍显示旧错误

处理顺序：

1. 先停止当前运行。
2. `Product → Clean Build Folder`。
3. 必要时退出并重新打开 Xcode。
4. 删除该测试工程对应的 DerivedData 后重新编译。
5. 以最新一次干净编译的第一条真实 error 为准；后续几十条通常是级联错误。

不要根据旧 Issue Navigator 中的错误数量判断修复是否失败。

## 验证顺序

按依赖由底到顶验证，能更快区分根因：

1. `CAtomic`
2. `cmark-gfm`
3. `cmark-gfm-extensions`
4. `MPITextKit`
5. `SwiftMath`
6. `MathJaxSwift`
7. `Markdown`
8. `GMarkdown`
9. App target

每次修改 module map、公共头或 Build Settings 后，使用全新的 DerivedData 执行一次 Debug Simulator clean build。最终还要分别检查 Release 和真机；模拟器 Debug 通过不等于正式发布验证完成。

## 本次问题的最终修复清单

本次独立测试工程曾出现以下问题，最终处理如下：

| 问题 | 修复 |
| --- | --- |
| Package 与源码 target 同时存在 | 移除 GMarkdown 及其依赖的 Package Dependencies |
| 多个 `Bundle.module` 无法编译 | 对非 SPM 分支改用 `Bundle(for:)` bundle token |
| cmark typedef 重复定义 | 禁用自动发现的旧 module map，使用唯一 umbrella module map |
| CAtomic 无公共头/module map | 添加 public header、umbrella module map 和 target 配置 |
| MPITextKit 未导出所需类型 | 添加公共 umbrella header、public header 和 module map |
| UIKit 类型不可用 | 在 SwiftMath 相关 Swift 文件显式导入 UIKit |
| `FOUNDATION_EXPORT` 不可用 | MPITextKit 公共头显式导入 Foundation |
| 模块验证器阻断旧源码 | 源码接入 target 关闭 library evolution/module verifier |
| Xcode 缓存旧模块配置 | 使用全新 DerivedData clean build |

## 交付前检查表

- [ ] 正式工程中没有同时存在 Package 依赖和源码依赖。
- [ ] 每个依赖只属于一个 framework target。
- [ ] GMarkdown 不直接编译进 App target。
- [ ] 所有公共头已加入 Headers Build Phase 并设为 Public。
- [ ] 每个模块只有一个有效 module map。
- [ ] 所有非 SPM 资源使用 `Bundle(for:)` 或等价的 framework bundle 定位。
- [ ] Debug Simulator clean build 通过。
- [ ] Release build 通过。
- [ ] 真机 build/运行通过。
- [ ] 运行时验证公式、表格横向滚动、Dynamic Type、深色模式和资源加载。
- [ ] 记录 Xcode、最低 iOS、设备和验证提交号。
