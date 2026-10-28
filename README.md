# 森林翻译 · 无本地 Mac 的 iPhone 登录验证工程 0.1.1

**这个 ZIP 是源码与云端构建配置，不是 IPA。尚未运行云端编译、签名安装或真实账号验证。**

适配目标：iPhone 12、iOS 17+，WhatsApp 与 Telegram 各 3 个独立账号入口。已编写的界面与账号隔离模块来自独立登录验证工程；功能范围详见“登录验证范围.md”。当前不含翻译，也未确认 WhatsApp 三账号能成功登录。

## 没有 Mac 怎么继续

流程：**GitHub 的云端 Mac 编译 → 下载未签名 IPA → Windows 本地签名安装到 iPhone → 真机验证 3＋3 账号。**

- 云端只需要源码，不需要你的苹果密码、证书、手机验证码、WhatsApp / Telegram 登录数据或翻译 API Key。
- 日常打开程序不需要电脑保持在线；电脑用于安装和按签名有效期续签。免费签名通常 7 天有效，这与“日常独立运行”是两个条件。
- 公开仓库的标准 GitHub 托管运行器按官方规则免费；私有仓库使用账号自带配额，超额可能收费。手动运行前检查自己账号的 Actions 配额 / 预算，不要把云端构建理解成无条件永久免费。
- 这个包没有替你创建 GitHub 仓库或上传任何内容，也没有触发云端构建。

## 在 Windows 上传工程

1. 注册 / 登录 https://github.com/ 。
2. 新建你自己的仓库，例如 `forest-iphone-login`。可以选 Private；先确认 Actions 配额可用。
3. 解压本包，将**里面的文件和文件夹**上传到仓库根目录，不要只上传 ZIP，也不要多套一层文件夹。
4. 根目录应直接有 `ForestAccounts/`、`ForestAccounts.xcodeproj/`、`scripts/`、`.github/` 和 `README.md`。
5. 必须包含 `.github/workflows/ios-unsigned.yml`。若网页没有上传这个文件夹，可通过 Add file → Create new file，新建完整路径 `.github/workflows/ios-unsigned.yml`，将本包该文件的内容原样粘贴并保存。
6. 只上传本包源码，勿上传 Windows 原程序、个人运行数据、Apple 凭证或聊天文件。

## 手动运行云端构建

1. 在自己的仓库打开 **Actions**。
2. 选择 **Build iPhone Login Validation** → **Run workflow**。
3. 只有当本次运行成功后，下载下方 **Artifacts → ForestAccounts-UNSIGNED-iPhone**。
4. 解压下载的 Artifact，里面应有 `ForestAccounts-UNSIGNED.ipa`、构建报告和安装说明。
5. 红色失败或只有 `ForestAccounts-build-failure` 时，没有得到成功的 IPA。下载失败日志继续排查，不要将源码改后缀当成安装包。

工作流仅手动触发，使用标准 `macos-15` 运行器，最长 25 分钟；没有上传签名 Secrets 的步骤，也没有自动发布、推送提交或运行功能测试。

## 用 Windows 安装

1. 先拿到上一步真正编译成功的 IPA。
2. 从 https://sideloadly.io/ 下载 Windows 版 Sideloadly，按其官方说明准备苹果设备驱动及所需 iTunes / iCloud 组件。不要为了本说明自动卸载现有苹果软件，先核对官方当前要求。
3. 用数据线连接并解锁 iPhone，在手机上信任电脑。
4. 在安装工具中选择你的设备，加入这个 IPA，使用你自己的 Apple 账号完成签名。苹果密码和验证码只在你确认的本地安装流程中填写，勿发在聊天或填入 GitHub。
5. 如设备要求，按官方步骤信任开发者并开启开发者模式；安装后打开应用。
6. 免费签名通常 7 天有效，到期需续签。续签时使用相同 Apple 账号和 Bundle ID 并覆盖安装，避免主动卸载导致会话丢失；具体保留效果仍需实机确认。

Sideloadly 是第三方工具，其可用性和苹果登录认证可能变化。安装失败时保留错误信息排查，不能保证任意日期、网络和账号都能一次成功。

## 先验证什么

先确认两个平台各 3 个账号真实登录、账号隔离、切换和重开后的会话保持。若 WhatsApp 不能完成此步骤，应停止宣称核心需求完成，重新评估登录路线。只有这些确认可靠后，再继续迁移翻译与中文发送拦截功能。

## 当前交付状态

- 已准备原生登录验证源码、Xcode 工程、云端构建工作流、未签名 IPA 打包脚本及 Windows 安装说明。
- 本次 Windows 环境仅能检查源码文件、配置和 ZIP；**没有成功编译记录、IPA、苹果签名或 iPhone 实机结果**。
- 原 Windows 程序、原始 ZIP 和上版登录验证 ZIP 均保持原样。

## 官方参考

- GitHub 运行器：https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- GitHub Actions 用量：https://docs.github.com/en/actions/concepts/billing-and-usage
- 下载构建产物：https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts
- Sideloadly：https://sideloadly.io/ 与 https://sideloadly.io/faq
- Apple 免费个人签名限制：https://developer.apple.com/help/account/basics/about-your-developer-account
- WebKit 多账号数据空间：https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/
