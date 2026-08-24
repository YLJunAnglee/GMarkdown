# Table edge cases

## Supported edge cases

| 类型 | 内容 | 备注 |
| --- | --- | --- |
| 混排 | 速度 $v=s/t$ 中文 | **粗体**、*斜体*、~~删除线~~ |
| 空单元格 |  | 应保留中间列 |
| 长中文 | 这是一段用于验证单元格换行与宽度计算的超长中文内容 | 不应破坏列数 |
| Long English | supercalifragilisticexpialidocious0123456789 | unbroken word |
| 多行 | 第一行<br>第二行 | HTML break |
| 转义竖线 | 左\|右 | 不应拆成两列 |

## Known long LaTeX issue

| 类型 | 公式 | 备注 |
| --- | --- | --- |
| 短公式 | $a+b=c$ | 应保持三列 |
| 长公式 | $\frac{x_1+x_2+x_3+x_4+x_5}{y_1+y_2+y_3+y_4+y_5}$ | 当前预处理会插入换行 |

## Uneven rows

| 类型 | 内容 | 备注 |
| --- | --- | --- |
| 少一列 | only two cells |
| 多一列 | second | third | extra |
