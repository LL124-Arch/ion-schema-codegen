# 开放内容、文件导入和重复约束

本例使用 `common.isl` 的正整数类型，以 Quantity 别名导入订单 Schema。
两个文件各自声明用户字段；描述、owner、revision 等元数据不参与源码生成。

- Limited 同时满足 int/number、区间 [0,100] 和集合 [1,2,3,4]。
- Order 的两组 fields 分别限制 Limited 和导入的 Quantity，第二组同时 closed；两组 field_names 同时执行。
- Values 同时满足 number/int 元素、distinct 和两种完整顺序模式。
- Stream 在顶层值流上执行相同的元素和顺序约束；StreamAlias 继承该校验链。

在仓库根目录运行（工具链基线见根文档）：

```sh
moon run --target native ./cli examples/schema_compat/order.isl examples/schema_compat/generated.mbt
moon fmt
moon check --deny-warn --target all
moon run --target native ./examples/schema_compat
```

本次实际运行输出：

```text
{quantity: 3}
[1, 2, 3]
stream values: 3
```

源码生成成功后，示例实际调用编译后的转换函数。完整支持范围与拒绝行为见
[兼容说明](../../docs/ISL_2_0_COMPATIBILITY.md)。此例未声明全量 ISL 2.0 支持。
