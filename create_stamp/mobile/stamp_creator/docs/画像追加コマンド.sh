#!/bin/bash

# シミュレータに画像を追加するスクリプト
# 使い方: ./画像追加コマンド.sh /path/to/image.jpg

if [ $# -eq 0 ]; then
    echo "使用方法: $0 <画像ファイルのパス>"
    echo "例: $0 ~/mobile/IMG_sample.jpg"
    exit 1
fi

IMAGE_PATH="$1"

# 画像ファイルが存在するか確認
if [ ! -f "$IMAGE_PATH" ]; then
    echo "エラー: 画像ファイルが見つかりません: $IMAGE_PATH"
    exit 1
fi

# シミュレータが起動しているか確認
if ! xcrun simctl list devices | grep -q "Booted"; then
    echo "エラー: シミュレータが起動していません"
    echo "Xcodeでアプリを実行してシミュレータを起動してください"
    exit 1
fi

# 画像を追加
echo "画像を追加しています: $IMAGE_PATH"
xcrun simctl addphoto booted "$IMAGE_PATH"

if [ $? -eq 0 ]; then
    echo "✅ 画像が正常に追加されました！"
    echo "シミュレータの「写真」アプリで確認してください"
else
    echo "❌ 画像の追加に失敗しました"
    exit 1
fi

