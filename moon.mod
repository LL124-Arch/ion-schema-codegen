// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "LL124-Arch/ion-schema-codegen"

version = "0.34.0"

readme = "README.md"

repository = "https://github.com/LL124-Arch/ion-schema-codegen"

license = "Apache-2.0"

keywords = [ ]

preferred_target = "wasm"

description = "Generate MoonBit types and Ion conversions from a supported Ion Schema 2.0 subset"

import {
  "LL124-Arch/amazon-ion-moonbit-core@0.1.2",
  "moonbitlang/async@0.19.4",
}
