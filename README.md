# LivePowerFlow

面向 Apple Silicon Mac 的 SwiftUI 菜单栏应用，用桑基图展示电源输入、电池充放电和各组件的功耗分布。项目目前处于实验阶段，部分分支按可用的传感器读数估算。

## 构建与运行

需要安装 Xcode Command Line Tools 和 Homebrew。安装独立的遥测工具 [macmon](https://github.com/vladkens/macmon)，然后在本目录运行：

```sh
brew install macmon
bash build.sh
open build/LivePowerFlow.app
```

运行后通过菜单栏图标打开功耗视图。

## 第三方依赖

[macmon](https://github.com/vladkens/macmon) 由 vladkens 维护，采用 MIT 许可证。应用通过本地命令调用它，安装由用户自行完成。
