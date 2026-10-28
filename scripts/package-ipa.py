"""Package a real iphoneos build; never substitute sources or simulator binaries."""
import hashlib
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

app = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
if sys.platform != 'darwin':
    raise SystemExit('Real iPhone packaging must run on the macOS build host.')
if not app.is_dir() or app.name != 'ForestAccounts.app':
    raise SystemExit('Compiled application was not found; no IPA produced.')
info = plistlib.loads((app / 'Info.plist').read_bytes())
if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS'] or info.get('DTPlatformName') != 'iphoneos':
    raise SystemExit('This is not an iPhone device build; no IPA produced.')
binary = app / info.get('CFBundleExecutable', '')
if not binary.is_file() or not os.access(binary, os.X_OK):
    raise SystemExit('Compiled executable is missing; no IPA produced.')
architectures = subprocess.check_output(['xcrun', 'lipo', '-archs', str(binary)], text=True).strip()
if 'arm64' not in architectures.split() or 'x86_64' in architectures.split():
    raise SystemExit('Invalid executable architecture for an iPhone.')

output.mkdir(parents=True, exist_ok=True)
ipa = output / 'ForestAccounts-UNSIGNED.ipa'
if ipa.exists():
    raise SystemExit('An IPA already exists; refusing to replace it.')
with tempfile.TemporaryDirectory(prefix='forest-ios-payload-') as temporary:
    payload = Path(temporary) / 'Payload'
    payload.mkdir()
    subprocess.run(['/usr/bin/ditto', str(app), str(payload / app.name)], check=True)
    subprocess.run(['/usr/bin/ditto', '-c', '-k', '--keepParent', str(payload), str(ipa)], check=True)
with zipfile.ZipFile(ipa) as archive:
    expected = 'Payload/ForestAccounts.app/' + info['CFBundleExecutable']
    if expected not in archive.namelist() or archive.testzip() is not None:
        raise SystemExit('IPA archive validation failed.')
with ipa.open('rb') as stream:
    checksum = hashlib.sha256()
    for chunk in iter(lambda: stream.read(1024 * 1024), b''):
        checksum.update(chunk)
    digest = checksum.hexdigest()
(output / 'SHA256SUMS.txt').write_text(digest + '  ' + ipa.name + '\n', encoding='utf-8')
report = {
    'compiled': True, 'sdk': 'iphoneos', 'architecture': architectures,
    'bundle_id': info['CFBundleIdentifier'], 'app_version': info['CFBundleShortVersionString'],
    'build_commit': os.environ.get('GITHUB_SHA', ''), 'signing': 'disabled; local signing required',
    'device_installation': 'not performed', 'real_login_validation': 'not performed',
    'whatsapp_3_accounts_verified': False, 'telegram_3_accounts_verified': False,
    'translation': 'not implemented in this login verification app', 'ipa_sha256': digest,
}
(output / 'build-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
readme = '''森林翻译 iPhone 登录验证版 — 未签名 IPA

此 IPA 来自 iPhone 真机目标编译，不是模拟器包，但没有苹果签名。
不能直接在 iPhone 上点击安装，也不是 TestFlight / App Store 安装包。
请先用自己 Windows 电脑上的安装工具和自己的 Apple 账号签名。
参考 Sideloadly 官方站：https://sideloadly.io/
免费 Apple 签名通常 7 天有效，之后需要续签。
日常打开此程序不需要电脑在线；安装及续签按安装工具要求进行。

此版只验证 WhatsApp / Telegram 各 3 个独立网页登录空间。
编译成功不代表账号已登录；两个平台的真实登录、切换、重启保持仍需在 iPhone 上确认。
尚未接入翻译，不保证后台收消息。没有自动发送功能。
Apple 密码、验证码及聊天登录信息请自行在相应界面填写，不要发送给开发者或上传到仓库。
续签时按工具说明保持相同 Apple 账号及 Bundle ID，并覆盖安装，避免先卸载而丢失数据。
'''
(output / '安装前先读.txt').write_text(readme, encoding='utf-8')
print(json.dumps(report, ensure_ascii=True, indent=2))
