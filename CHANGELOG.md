# 变更记录

## 0.5.0 — 2026-10-06

- 支持 ISL `document` 顶层流类型，映射为有序的 `Array[@ion_model.IonValue]`。
- 为 document 命名类型及同 Schema 别名生成独立流转换函数；明确拒绝 document 嵌套进字段或列表。
- 增加多个顶层值及 Ion core 文本解析/编码往返用例。

## 0.4.0 — 2026-10-06

- 支持 nullable universal type `$any`，作为字段、列表元素及命名别名时映射为原始 `IonValue`。
- 保留 plain null、typed null、带注解 null 和其他注解值；非 nullable `any` 仍拒绝 null。
- 其他 nullable 类型及顶层 document 流仍不在当前值转换子集中。

## 0.3.0 — 2026-10-05

- 支持 Ion Schema `any`，映射为原始 `IonValue`，可用于结构体字段、列表元素及命名别名。
- 任意非 null 值及其注解、嵌套容器均经 `from_ion` / `to_ion` 原样保留；plain null 和 typed null 返回带路径错误。
- 显式保持 `$any`（nullable any）不支持，并为解析、生成及运行时往返补充回归用例。

## 0.2.0 — 2026-10-05

- 支持 Ion Schema `sexp` 类型，并可在结构体字段和列表元素中转换。
- 将表达式映射为 `Array[@ion_model.IonValue]`，保留任意嵌套 Ion 子值、注解与顺序。
- 为 S-expression 容器错误补充类型诊断及端到端往返 fixture。

## 0.1.0 — 2026-10-05

- 实现 ISL 2.0 受支持子集解析、MoonBit 类型生成及 Ion 双向转换。
- 支持标量、封闭结构体、列表、同 Schema 命名引用和稳定依赖顺序；循环引用会报告引用链。
- 增加 native CLI，能够读取 `.isl` 文件并写出生成的 `.mbt` 文件。
- 增加 Person 端到端示例、标量/结构体/列表转换 fixture 和四目标 CI 验收。
- 明确拒绝跨 Schema 导入、递归类型、开放结构体、nullable 类型及未实现约束。
