# light

一个极简 Android 应用：打开后只做一件事 —— **显示纯白，并把屏幕亮度拉到最高，不自动熄屏锁屏**。

`dark` 的反向版本（参考 [AlexIllinois2/dark](https://github.com/AlexIllinois2/dark)）：dark 让屏幕一个像素都不发光，light 让所有像素满亮度发光，可当手电筒、补光灯、拍图打光板用。

## 安装

```bash
adb install -r dist/light.apk
```

或者把 `dist/light.apk` 传到手机上点开安装。

- 包名 `app.light`，版本 1.0，minSdk 23（Android 6.0+），targetSdk 34
- 已用 v2 + v3 方案签名，可直接安装

## 打开后发生什么

| 行为 | 说明 |
| --- | --- |
| 全屏纯白 `#FFFFFFFF` | 所有像素以最大亮度发光 |
| 亮度锁最高 | 窗口亮度设为 1.0，无视系统当前亮度设置 |
| 沉浸式全屏 | 状态栏、导航栏全部隐藏，整块屏幕都是白光 |
| 保持常亮 | 一直亮屏显示纯白，不自动熄屏、不自动锁屏 |
| 启动画面纯白 | Android 12+ 的闪屏图标被替换为透明，点开瞬间就是白的 |

## 退出

从屏幕底部/侧边向内滑，临时唤出导航栏后返回；或者直接用手势返回 / 多任务键。

## 想改

- 不想锁最高亮度：删掉 `MainActivity.java` 里 `params.screenBrightness = 1f;` 那三行
- 不想常亮（允许自动熄屏）：删掉 `window.addFlags(FLAG_KEEP_SCREEN_ON);` 那一行

## 重新构建

工具链已放在 `.toolchain/`（Temurin JDK 17 + Android SDK：build-tools 34.0.0、platforms/android-34、platform-tools）；
也可以用系统环境里的 `JAVA_HOME` 与 `ANDROID_SDK_ROOT`：

```bash
bash tools/build_apk.sh      # 直接调 aapt2 / javac / d8 / zipalign / apksigner 构建，产出 light.apk
python tools/make_icons.py   # 重新生成白底黑字 "light" 启动图标
```

也可以直接用 Android Studio 打开根目录（`app/` 是标准 Gradle 模块，AGP 8.5.2）。

## 签名

`keystore/light.jks`（PKCS12），别名 `light`，密码 `lightlight`。
覆盖安装升级必须用同一个密钥，请自行备份。

## 图标

![图标](docs/icon.png)

白底黑字「light」，192px 传统图标 + 自适应图标（前景黑色文字卡在 66dp 安全圆内，
圆形、圆角方形等任何遮罩下都不会被裁切）。预览图见 `docs/icon.png`。

## 目录结构

```
app/src/main/
  AndroidManifest.xml
  java/app/light/MainActivity.java    # 全部逻辑：纯白 + 沉浸式 + 亮度 1.0 + 常亮
  res/values/themes.xml               # 纯白主题（含启动画面）
  res/mipmap-*/                       # 启动图标
tools/
  build_apk.sh                        # 构建脚本
  make_icons.py                       # 图标生成脚本
docs/icon.png                         # 图标预览图
dist/light.apk                        # 成品（构建输出）
.toolchain/                           # 本地 JDK + Android SDK（可删，删了就得重装才能重新构建）
keystore/light.jks                    # 签名密钥
```
