# VoidLink 已上架App Store.
# VoidLink is available on App Store
### [https://apps.apple.com/app/voidlink/id6747717070](https://apps.apple.com/cn/app/voidlink/id6747717070)

<br>

# 代码 Coding
- 代码提交在`Integration`分支。
- For latest coding commits, go to branch `Integration`.

### Local iOS development

After cloning, initialize all dependencies, including nested submodules:

```sh
git submodule sync --recursive
git submodule update --init --recursive
```

Open `VoidLink.xcodeproj`, select the **VoidLink** scheme and your iPhone, and
choose your development team under **Signing & Capabilities**. Xcode resolves
the Swift package dependencies automatically.

If the build reports a missing Metal toolchain, install the component for the
selected Xcode version:

```sh
xcodebuild -downloadComponent MetalToolchain
```

To build from the command line (replace `<device-udid>` with your device ID):

```sh
xcodebuild -project VoidLink.xcodeproj -scheme VoidLink \
  -configuration Debug -destination 'id=<device-udid>' \
  -allowProvisioningUpdates build
```

With Xcode 27, append `IPHONEOS_DEPLOYMENT_TARGET=15.0` to this command while
the project retains deployment targets below iOS 15. This overrides the target
for the local build without changing the checked-in project settings.

iOS 27 external-display development requires Xcode 27. Apple now requires apps
to register a scene accessory before the system creates a noninteractive
external-display scene. See Apple's
[connected-display documentation](https://developer.apple.com/documentation/uikit/presenting-content-on-a-connected-display).

<br>

# 关于VoidLink. About VoidLink
- 本项目最初基于开源项目 [moonlight-iOS] fork 而来。在此基础上，True砖家（True Zhuanjia）@ Bilibili 及其他社区开发者对项目进行了大量重构、重新设计与功能扩展，包括全新的用户界面和显著增强的功能特性。<br>我们对 moonlight-iOS 开发者的开创性工作表示衷心感谢。 <br><br>
- VoidLink was originally forked from the open-source project [moonlight-iOS], but has since been extensively reworked, redesigned, and expanded by True砖家 (True Zhuanjia) @ Bilibili and other community developers. These contributions include a completely new user interface and significant enhancements to the application's functionality.<br>We gratefully acknowledge the foundational work of the moonlight-iOS developers.

<br>

# App Store 分发一次性收费声明. 
# Statement on One-Time App Store Distribution Fee. 
- VoidLink 的 App Store 安装费用用于覆盖通过 Apple 框架进行安全可靠应用分发的成本。同时也支持项目维护者进行持续的开发、维护，以及公众用户访问并下载官方签名版本。感谢您对项目的支持，帮助我们持续改进和优化。<br><br>
- The App Store fee for VoidLink covers the cost of secure and trusted distribution using Apple's infrastructure. It supports ongoing development, maintenance, and access to the official signed build. Thank you for supporting the project and helping sustain ongoing improvements.  

 <br>

# 开发者B站号. Developer on Bilibili

如果你在用Bilibili， 请关注`True砖家`，了解该fork的最新消息。 <br>
If you are on Bilibili, subscribe `True砖家` to get the latest news of this fork: <br>
https://b23.tv/A0F9v7n

<br>

# 贡献者 Contributors
[@TrueZhuangJia](https://github.com/TrueZhuangJia) <br>
[@All contributors from moonlight-iOS](https://github.com/moonlight-stream/moonlight-ios/graphs/contributors) <br>
[@stefanilijev97](https://github.com/stefanilijev97/stefanilijev97) <br>
[@Acaki](https://github.com/Acaki) <br>
[@seastwood](https://github.com/seastwood) <br>
[@Danos0100](https://github.com/Danos0100) <br>
[@xzzpig](https://github.com/xzzpig) <br>
[@King0fSpace](https://github.com/King0fSpace) <br>
