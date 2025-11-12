#!/bin/bash
# 比赛打包脚本

set -e

PROJECT_NAME="Mochi"
VERSION="0.1.0"
PACKAGE_NAME="${PROJECT_NAME}-${VERSION}"

echo "开始打包 ${PACKAGE_NAME}..."

# 创建临时打包目录
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="${TEMP_DIR}/${PACKAGE_NAME}"
mkdir -p "${PACKAGE_DIR}"

# 复制源代码
echo "复制源代码..."
mkdir -p "${PACKAGE_DIR}/src"
cp -r src/* "${PACKAGE_DIR}/src/"

# 复制配置文件
echo "复制配置文件..."
cp moon.mod.json "${PACKAGE_DIR}/"
cp minimoonbit.json "${PACKAGE_DIR}/" 2>/dev/null || true

# 复制文档
echo "复制文档..."
cp README.md "${PACKAGE_DIR}/" 2>/dev/null || true
cp README.mbt.md "${PACKAGE_DIR}/" 2>/dev/null || true
cp LICENSE "${PACKAGE_DIR}/" 2>/dev/null || true
cp AGENTS.md "${PACKAGE_DIR}/" 2>/dev/null || true
cp SUBMISSION.md "${PACKAGE_DIR}/" 2>/dev/null || true

# 复制语法文件（如果有）
cp MiniMoonBit.g4 "${PACKAGE_DIR}/" 2>/dev/null || true
cp MiniMoonBitBasic.g4 "${PACKAGE_DIR}/" 2>/dev/null || true

# 清理不需要的文件
echo "清理临时文件..."
find "${PACKAGE_DIR}" -name "target" -type d -exec rm -rf {} + 2>/dev/null || true
find "${PACKAGE_DIR}" -name "*.mi" -delete 2>/dev/null || true
find "${PACKAGE_DIR}" -name "*.mbti" -delete 2>/dev/null || true
find "${PACKAGE_DIR}" -name "*.wasm" -delete 2>/dev/null || true
find "${PACKAGE_DIR}" -name "*.core" -delete 2>/dev/null || true
find "${PACKAGE_DIR}" -name "*.map" -delete 2>/dev/null || true
find "${PACKAGE_DIR}" -name "__*" -delete 2>/dev/null || true
find "${PACKAGE_DIR}" -name "*.db" -delete 2>/dev/null || true
find "${PACKAGE_DIR}" -name "*.output" -delete 2>/dev/null || true

# 创建打包文件
cd "${TEMP_DIR}"
ZIP_FILE="${PACKAGE_NAME}.zip"
zip -r "${ZIP_FILE}" "${PACKAGE_NAME}" > /dev/null

# 移动到当前目录
mv "${ZIP_FILE}" "${OLDPWD}/"
cd "${OLDPWD}"

# 清理临时目录
rm -rf "${TEMP_DIR}"

echo "打包完成: ${ZIP_FILE}"
echo "文件大小: $(du -h ${ZIP_FILE} | cut -f1)"

