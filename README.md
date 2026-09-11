# AddiGuard for iOS

AddiGuard（添加剂卫士）是一款原生 SwiftUI 应用：拍摄或导入食品配料表，始终通过设备上的 Apple Vision 提取文字，再选择本地知识库或 OpenRouter 上的 GLM-5.3 Flash 对配料进行分析。

## MVP 功能

- 相机取景、拍照识别与相册导入
- 锁定屏幕小组件，可一键打开食品配料识别页
- 两种明确可选的分析方式：本地知识库分析，以及 OpenRouter GLM-5.3 Flash 在线逐项辅助说明
- 始终在设备端执行的中英文双路 OCR（Vision）：原图与增强图并行识别，并使用本地添加剂名称、别名和 E/INS 编码词表辅助小字识别；图片不会上传
- 完整配料拆分：分别标出已匹配添加剂、常见普通配料、可能匹配和未匹配文字，不再静默丢弃未知项
- GB 2760-2024 附录 F（附录 A 索引）的 287 个名称组、本地中英文常用名与经校验的 E/INS 编码匹配
- 高关注、需核对、较低关注，以及“无法判断”的未评级状态
- 儿童、孕期、慢病和过敏设置对应的资料核对提示
- 添加剂详情、参考标准框架和信息核对建议
- 受文件保护的本地历史记录与搜索；图片与完整 OCR 原文不写入历史文件
- 模拟器无相机时的一键完整演示流程

## 在线 API 接入状态

- 图片始终只在设备上由 Apple Vision 提取文字。应用先在本地拆分配料，再按所选方式分析；OpenRouter 不参与 OCR，也不会收到图片。
- 本地解析器生成有界、按原顺序排列的配料数组。在线模式只发送每项的不透明序号和配料名称，不发送完整 OCR、产品名、地址、电话、用户画像、扫描历史或本地知识库；若没有拆出配料，会直接停止在线请求，不会改为上传全文。
- 本地分析是默认模式。启用在线辅助分析必须基于当前数据边界重新确认，不会隐藏上传或静默切换；确认后该偏好持续到用户切回本地模式。
- 本地 Debug 构建通过 OpenRouter Chat Completions 调用 `z-ai/glm-5.3-flash`（Z.ai GLM-5.3 Flash）。请求采用 HTTPS、Bearer 认证、低强度推理和 `data_collection=deny`；模型只为本地清单中的每一种配料生成辅助说明，不能新增、删除、改名、排序或改写本地风险结论。
- 模型 slug 会随上游下线而失效：本项目最初使用的 `stealth/ox-alpha` 隐身测试期结束后已被 OpenRouter 移除，改名为 `z-ai/glm-5.3-flash`。此时接口返回 HTTP 404，应用按 `modelUnavailable` 提示改用本地分析，不会崩溃也不会静默上传。升级模型前可先用 `curl` 调用 `https://openrouter.ai/api/v1/models` 或直接发一次最小请求确认 slug 仍然有效。
- 本地凭证只放在被 Git 忽略的 `Config/Secrets.xcconfig`，不会写入源码、测试、README、Info.plist 或 App 包。`Config/Debug.xcconfig` 会可选加载它，Debug scheme 在启动时传入并保存至版本化的本机 Keychain 槽位；若启动变量存在但为空或未展开，应用会直接判定 API 未配置，不会静默回退到旧凭证。`Config/Release.xcconfig` 始终为空，Release 代码也不会读取开发凭证，因此 Archive/TestFlight/App Store 构建不会携带它。
- 新环境可复制 `Config/Secrets.xcconfig.example` 为 `Config/Secrets.xcconfig` 并填写仅用于开发、带额度限制的密钥，然后运行 `xcodegen generate` 并从 Xcode 执行一次 Run。没有本地凭证或 Keychain 记录时，在线选项显示“待配置”且不会发起网络请求。
- Debug 日志只记录凭证来源、不可逆短指纹、请求返回的 generation ID、模型、结束原因、token 数与成本，不记录 API key、Authorization、图片、完整 OCR 或配料名称。排查免费模型时应以 HTTP 200、`finish_reason=stop`、token 数和 generation 记录为准；费用为 0 本身不代表请求失败。
- 客户端在运行时使用的任何密钥仍可能从受控设备或进程中提取。正式发布应改为调用自有后端代理；若改为用户自带密钥，应提供应用内录入、Keychain 保存与删除能力。
- `data_collection=deny` 只用于排除明确声明收集数据的上游，不构成零留存保证。OpenRouter、模型提供方 Z.ai，以及 OpenRouter 实际路由到的第三方推理服务商，仍可能依服务条款长期处理、保留并使用提示、回复及请求元数据，包括服务或模型改进许可；提供方、处理地区和政策也可能变化。发布前需重新核对服务政策、重新取得适当同意，并更新 App Store 隐私披露。

## 运行

1. 安装 Xcode 16 或更高版本（项目最低支持 iOS 17）。
2. 如需重新生成工程，运行 `xcodegen generate`。
3. 打开 `AddiGuard.xcodeproj`，选择 `AddiGuard` scheme 和任意 iPhone 模拟器。
4. 点击 Run。模拟器中可点击“示例匹配”体验完整流程；真机可直接拍照。

## 测试

- 常规测试：`xcodebuild -project AddiGuard.xcodeproj -scheme AddiGuard -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`。全部用例都不联网。
- 联网冒烟测试：`Tests/OpenRouterLiveSmokeTests.swift` 会用生产请求体真实调用一次 OpenRouter，用来发现模型 slug 被上游下线这类离线测试查不出的问题。默认跳过，CI 不会执行，也不会消耗额度。
- 该用例在模拟器进程内运行，不继承终端环境变量，因此必须使用 xcodebuild 的 `TEST_RUNNER_` 前缀（转发时会自动去掉前缀）；不加前缀只会静默跳过：

```
TEST_RUNNER_ADDIGUARD_LIVE_API_TESTS=1 \
TEST_RUNNER_OPENROUTER_API_KEY="$(awk -F= '/OPENROUTER_API_KEY/{print $2}' Config/Secrets.xcconfig | tr -d ' ')" \
xcodebuild -project AddiGuard.xcodeproj -scheme AddiGuard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AddiGuardTests/OpenRouterLiveSmokeTests test
```

## 添加锁定屏幕小组件

1. 在设备上安装并打开 AddiGuard 一次。
2. 长按锁定屏幕，依次选择“自定”“锁定屏幕”和“添加小组件”。
3. 在小组件列表中选择 AddiGuard，并添加行内、圆形或矩形样式。
4. 点击小组件即可打开 AddiGuard 的食品配料识别页。

## 架构

- `Sources/App`：应用入口与 Tab/NavigationStack 外壳
- `Sources/Features`：扫描、结果、历史和用户档案
- `Sources/Services`：相机、本地 OCR、本地/API 分析路由、知识库与持久化
- `Sources/Models`：添加剂、扫描结果和用户画像模型
- `WidgetExtension`：锁定屏幕小组件与扫描页深链入口
- `SupportingFiles`：主 App 与 Widget Extension 的 Info.plist
- `Tests`：名称匹配、目录一致性和不确定状态测试

## 识别范围

- 扩展目录覆盖 GB 2760-2024 附录 F 中的 287 个食品添加剂名称组；对可唯一映射的单一 INS 编码生成 `E`、`E 号`、`INS` 和 `INS 号`写法。多成分、多编号组不会猜测编号归属。
- 匹配器会处理大小写、全角字符、空格、换行、连字符和常见标点差异，并优先匹配较长的具体名称，避免把“柠檬酸钠”重复识别为“柠檬酸”。
- 配料解析器支持中英文标题、中文标点、括号内添加剂组和多行标签；少量经审查的整词 OCR 错误可自动纠正，其余单字模糊结果只显示为“可能匹配”，不会进入风险结果。
- 食品用香精、食品用香料、加工助剂、酶制剂、营养强化剂和复配食品添加剂可按类别识别；其未展开的具体组成需要结合产品资料核对。

> 扩展目录只用于提高名称识别率。只有少量条目经过单独整理，其余条目标为“无法判断”，不会被默认标成低关注。应用没有食品类别、实际添加量、摄入量、体重或 ADI 数据，因此不能判断产品是否合规或安全，也不能替代完整监管数据库、医生或食品安全专业人员的意见。
