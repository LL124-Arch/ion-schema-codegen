# ion-schema-codegen

`ion-schema-codegen` 根据受支持的 Ion Schema 2.0 文档生成 MoonBit 类型和双向 Ion 转换函数。它依赖 [amazon-ion-moonbit-core](https://github.com/LL124-Arch/amazon-ion-moonbit-core) 解析 Ion 文本并表示 Ion 值。

## 支持范围

- 标量：`bool`、`int`、`float`、`decimal`、`string`、`symbol`、`timestamp`、`blob` 和 `clob`。
- 封闭结构体字段，支持必选与可选字段。
- 元素为受支持标量或同一 Schema 命名类型的列表。
- Ion `sexp` 作为 `Array[@ion_model.IonValue]`，支持结构体字段及列表元素；表达式内部值与顺序保持为 Ion 值模型。
- Ion Schema `any` 作为 `@ion_model.IonValue`，可用于字段、列表元素和命名别名；任意非 null Ion 值（含注解及嵌套值）原样往返。
- 无循环的同 Schema 命名类型引用；生成声明按依赖顺序排列。
- 结构体与列表的 `from_ion` / `to_ion` 转换。转换会报告字段路径、列表下标和具体 Ion 类型。

项目不实现完整的 Ion Schema 校验器。跨 Schema 导入、递归类型、开放结构体、nullable 类型（包括 `$any`），以及 `valid_values`、范围、正则、注解和类型代数等约束会显式报错。`any` 接受注解值；该行为保留注解，不代表实现了 ISL 的注解约束。

## 安装与检查

安装 MoonBit 工具链后，在仓库根目录运行：

```sh
moon update
moon fmt --check
moon check --deny-warn --target all
moon build
moon test --deny-warn --target all
```

## 从 Schema 生成代码

CLI 读取 UTF-8 `.isl` 文件并写出 `.mbt` 文件。CLI 使用本机文件系统，运行目标为 `native`：

```sh
moon run --target native ./cli examples/person/person.isl examples/person/generated.mbt
```

命令会打印生成结果所需的包导入。把这些导入加入目标包的 `moon.pkg`，然后编译或运行该包。已有输出文件会被覆盖；读取、Schema 生成和写入失败会返回非零状态并显示原因。

## 端到端示例

仓库内的 [Person Schema](examples/person/person.isl) 声明必选 `id`、`name` 和可选 `nickname`。从仓库根目录依次运行：

```sh
moon run --target native ./cli examples/person/person.isl examples/person/generated.mbt
moon run --target native ./examples/person
```

示例程序解析 Ion 文本，将值转换为 `Person`，更新姓名，再把类型化值编码回 Ion 文本。输出类似：

```ion
{id: 42, name: "Ada Lovelace", nickname: "Ada"}
```

可查看 [示例入口](examples/person/main.mbt) 和 [CLI 生成的 MoonBit 代码](examples/person/generated.mbt)。

## 库 API

```moonbit
let generated = @ion-schema-codegen.generate_code(schema_text)
// generated.source 是 MoonBit 源码
// generated.package_imports 是目标包需要加入 moon.pkg 的导入项
```

`check_schema(schema_text)` 只检查当前受支持的 Schema 子集；`generate_code(schema_text)` 返回源码和所需导入。程序化调用示例见 `fixtures/generated` 与 `fixtures/references`。

结构体转换拒绝缺失的必选字段、重复字段、未知字段、错误 Ion 类型和 typed null。普通具名类型的字段仍拒绝注解；`any` 字段原样保留注解。列表转换要求 Ion `list`，逐项验证元素类型，并在错误路径中包含元素下标；`any` 元素接受并保留注解，但 plain null 和 typed null 都会报错。

`sexp` 转换检查外层容器必须是 Ion `sexp`，并保留内部的任意 Ion 值；内部子值不会按其他 Schema 类型递归校验。

## 变更记录

版本变更见 [CHANGELOG.md](CHANGELOG.md)。
