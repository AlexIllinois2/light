#!/usr/bin/env bash
# 用 Android SDK 自带工具直接构建 light.apk（不依赖 Gradle）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# JDK：优先用环境里的，其次用本地 .toolchain
if [ -z "${JAVA_HOME:-}" ] && [ -d "$ROOT/.toolchain" ]; then
  JAVA_HOME="$(find "$ROOT/.toolchain" -maxdepth 1 -type d -name 'jdk-*' | head -1)"
  export JAVA_HOME
fi
if [ -z "${JAVA_HOME:-}" ]; then
  echo "错误：未找到 JDK，请设置 JAVA_HOME 或把 JDK 放到 $ROOT/.toolchain/" >&2
  exit 1
fi

# Android SDK：优先 ANDROID_SDK_ROOT / ANDROID_HOME，其次本地 .toolchain
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$ROOT/.toolchain/sdk}}"
BT="$SDK/build-tools/34.0.0"
PLATFORM="$SDK/platforms/android-34/android.jar"
if [ ! -x "$BT/aapt2" ] || [ ! -f "$PLATFORM" ]; then
  echo "错误：未找到 Android SDK（需要 build-tools 34.0.0 与 platforms/android-34）" >&2
  exit 1
fi

OUT="$ROOT/build"
SRC="$ROOT/app/src/main"
KEYSTORE="$ROOT/keystore/light.jks"
KS_PASS="lightlight"
KS_ALIAS="light"
FINAL="$ROOT/dist/light.apk"

rm -rf "$OUT"
mkdir -p "$OUT/compiled" "$OUT/gen" "$OUT/classes" "$OUT/dex"

echo "[1/7] aapt2 compile"
"$BT/aapt2" compile --dir "$SRC/res" -o "$OUT/compiled/res.zip"

echo "[2/7] aapt2 link"
"$BT/aapt2" link \
  -o "$OUT/base.apk" \
  -I "$PLATFORM" \
  --manifest "$SRC/AndroidManifest.xml" \
  --java "$OUT/gen" \
  --min-sdk-version 23 \
  --target-sdk-version 34 \
  --version-code 1 \
  --version-name 1.0 \
  -0 arsc \
  "$OUT/compiled/res.zip"

echo "[3/7] javac"
"$JAVA_HOME/bin/javac" --release 17 -encoding UTF-8 -cp "$PLATFORM" -d "$OUT/classes" \
  $(find "$OUT/gen" -name '*.java') \
  $(find "$SRC/java" -name '*.java')

echo "[4/7] d8 (dex)"
"$BT/d8" --release --lib "$PLATFORM" --min-api 23 --output "$OUT/dex" \
  $(find "$OUT/classes" -name '*.class')

echo "[5/7] package dex into apk"
python3 - "$OUT/base.apk" "$OUT/dex/classes.dex" <<'PY'
import shutil, sys, zipfile
base, dex = sys.argv[1], sys.argv[2]
shutil.copy(base, base + ".tmp")
with zipfile.ZipFile(base + ".tmp", "a", zipfile.ZIP_DEFLATED) as z:
    z.write(dex, "classes.dex")
shutil.move(base + ".tmp", base)
print("packed classes.dex")
PY
cp "$OUT/base.apk" "$OUT/unsigned.apk"

echo "[6/7] zipalign"
"$BT/zipalign" -f -p 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

echo "[7/7] apksigner"
mkdir -p "$(dirname "$FINAL")"
if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  "$JAVA_HOME/bin/keytool" -genkeypair -v \
    -keystore "$KEYSTORE" -alias "$KS_ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10950 \
    -storetype PKCS12 -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -dname "CN=light, OU=light, O=light, L=Beijing, ST=Beijing, C=CN" > /dev/null 2>&1
  echo "  生成签名密钥 $KEYSTORE"
fi
"$BT/apksigner" sign \
  --ks "$KEYSTORE" --ks-key-alias "$KS_ALIAS" \
  --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" \
  --v1-signing-enabled true --v2-signing-enabled true \
  --out "$FINAL" "$OUT/aligned.apk"

"$BT/apksigner" verify --print-certs "$FINAL" | head -5
echo "OK -> $FINAL"
