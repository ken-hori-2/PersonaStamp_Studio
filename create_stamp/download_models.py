#!/usr/bin/env python3
"""
rembgのモデルを事前にダウンロードするスクリプト

このスクリプトを実行することで、背景除去処理の実行時に
モデルのダウンロード時間を短縮できます。
"""

from rembg import new_session
import sys
import argparse

# 利用可能なモデルタイプ
AVAILABLE_MODELS = {
    'u2net': '一般的な前景/背景セグメンテーション（人・物体の両方に対応）',
    'u2net_human_seg': '人間専用セグメンテーション（人物の精度が高い）',
    'u2netp': '軽量版モデル（処理速度が速い）',
    'silueta': 'シルエット抽出',
    'isnet-general-use': '高精度な一般用途モデル',
    'birefnet-portrait': 'ポートレート専用（人物写真に最適）',
    'sam': 'Segment Anything Model（高精度だが処理が遅い）',
}


def download_model(model_name):
    """
    指定されたモデルをダウンロードする
    
    Args:
        model_name (str): ダウンロードするモデル名
    
    Returns:
        bool: 成功した場合True、失敗した場合False
    """
    try:
        print(f"\n{'='*60}")
        print(f"ダウンロード中: {model_name}")
        print(f"説明: {AVAILABLE_MODELS.get(model_name, 'Unknown model')}")
        print(f"{'='*60}")
        
        # モデルセッションを作成（これによりモデルがダウンロードされる）
        session = new_session(model_name)
        
        print(f"✓ {model_name} のダウンロードが完了しました")
        return True
    except Exception as e:
        print(f"✗ {model_name} のダウンロードに失敗しました: {e}")
        return False


def download_all_models():
    """
    すべての利用可能なモデルをダウンロードする
    """
    print("すべてのモデルをダウンロードします...")
    print(f"合計 {len(AVAILABLE_MODELS)} 個のモデルがあります\n")
    
    success_count = 0
    failed_models = []
    
    for model_name in AVAILABLE_MODELS.keys():
        if download_model(model_name):
            success_count += 1
        else:
            failed_models.append(model_name)
    
    print(f"\n{'='*60}")
    print("ダウンロード結果")
    print(f"{'='*60}")
    print(f"成功: {success_count}/{len(AVAILABLE_MODELS)}")
    if failed_models:
        print(f"失敗: {', '.join(failed_models)}")
    print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(
        description='rembgのモデルを事前にダウンロードするスクリプト',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
例:
  # すべてのモデルをダウンロード
  python download_models.py --all
  
  # 特定のモデルのみダウンロード
  python download_models.py --model u2net
  
  # 複数のモデルをダウンロード
  python download_models.py --model u2net --model u2net_human_seg
        """
    )
    
    parser.add_argument(
        '--all', 
        action='store_true',
        help='すべての利用可能なモデルをダウンロード'
    )
    parser.add_argument(
        '--model',
        type=str,
        action='append',
        choices=list(AVAILABLE_MODELS.keys()),
        help='ダウンロードするモデル名（複数指定可能）'
    )
    
    args = parser.parse_args()
    
    if args.all:
        # すべてのモデルをダウンロード
        download_all_models()
    elif args.model:
        # 指定されたモデルのみダウンロード
        print(f"{len(args.model)} 個のモデルをダウンロードします...\n")
        success_count = 0
        for model_name in args.model:
            if download_model(model_name):
                success_count += 1
        
        print(f"\n{'='*60}")
        print(f"ダウンロード完了: {success_count}/{len(args.model)} 成功")
        print(f"{'='*60}\n")
    else:
        # 引数が指定されていない場合はヘルプを表示
        parser.print_help()
        print("\nヒント: --all ですべてのモデルをダウンロード、または --model で特定のモデルをダウンロードできます")


if __name__ == "__main__":
    main()


