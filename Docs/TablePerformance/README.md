# TABLE 缓存、取消与性能记录

## 本步结果

- `NativeMarkdownTableView` 保留原同步 `render`，并新增返回 `NativeMarkdownTableRenderTask` 的 `renderAsync`。新请求、任务 `cancel()` 或 `clear()` 都会使旧任务失效，过期结果不会写回复用后的 View，也不会回调旧 completion。
- 异步入口在下一次主队列执行渲染。底层 UIKit、MPITextKit 和公式渲染器不是 Sendable，因此本步不把它们冒险移到后台线程；取消是协作式防回写，而不是强行中断已经进入的同步 UIKit 调用。
- 新增共享 LRU 表格布局缓存，最多保留 32 项、按单元格数量计费并响应内存警告。Key 区分 Markdown 内容、容器宽度、字体、颜色、完整样式、亮暗主题、辅助功能对比度、界面层级、Display Scale 和渲染器版本。
- 公式图片缓存从“仅公式文本”改为同时区分字号、字体、颜色、Scale 和渲染方式，避免主题或字号变化后复用旧公式图。
- 成功指标新增解析、公式、布局和总耗时、缓存命中状态及相对上一次成功结果的高度差；重复渲染相同输入时解析/公式/布局耗时为 0，`heightDelta` 为 0。
- 公式渲染失败仍显示纯文本，同时通过 `.formulaFallback(count:)` 返回非致命警告；无效计算尺寸返回 `.invalidCalculatedSize`，供业务层按 Block 回退旧渲染器。

## API 示例

```swift
private var tableTask: NativeMarkdownTableRenderTask?

tableTask = tableView.renderAsync(
    markdown: tableMarkdown,
    style: style,
    containerWidth: availableWidth
) { result in
    switch result {
    case let .success(metrics):
        tableHeight = metrics.requiredSize.height
        print(metrics.performance.cacheHit)
        print(metrics.performance.totalDuration)
        print(metrics.heightDelta as Any)
    case .failure:
        showWKWebViewFallback()
    }
}

// Cell 复用时：
tableTask?.cancel()
tableView.clear()
```

`GMarkdownExample` 的 `Native TABLE API` 页面已改用该异步入口，并直接显示 cache hit/miss、解析/公式/布局/总耗时、警告数量和高度差。

## 自动验证

- 日期：2026-08-24。
- 设备：iPhone 16 Pro 模拟器，iOS 18.6。
- 共 25 个测试，25 个通过、0 失败、0 跳过。
- 本步新增 7 个测试，覆盖重复渲染命中缓存、内容/宽度/样式隔离、字体/颜色/主题/Scale 隔离、公式图片缓存样式隔离、A→B 快速复用只保留 B、`clear()` 阻止旧任务回写，以及异常计算尺寸失败。
- 测试结果：`/tmp/GMarkdownStep7Tests/Logs/Test/Test-GMarkdown-2026.08.24_20-06-19-+0800.xcresult`。
- Example 样例 A 在 370 pt 容器重复渲染后显示 cache hit，解析/公式/布局均为 0.00 ms，本次缓存读取与应用总耗时 0.10 ms，高度差为 +0.0 pt。该数值是 Debug 模拟器单次观测，只用于证明指标链路和缓存生效，不作为 Release 性能结论。

[样例 A：缓存命中与稳定高度](table_step7_cache_hit.png)

## 当前边界

- 本步只建立 GMarkdown 组件能力，没有修改 AIEndorser，也没有更新 AIEndorser 的 SPM revision。
- `renderAsync` 解决任务排队和 Cell 复用的过期回写，不代表解析/公式工作已经后台并行化；是否需要进一步分段或后台化，应以 AIEndorser 真实列表的主线程数据决定。
- 第 6 步记录的模拟器自动截图中表格外围文字图层偶发捕获不全，未在本步任务切换测试中出现旧表回写；仍需在业务接入后的真实滚动、翻页和截图场景复核。
