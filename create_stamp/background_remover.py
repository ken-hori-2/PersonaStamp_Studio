import cv2
from rembg import remove, new_session
from PIL import Image
import numpy as np
import os
import argparse

# HEIC形式のサポート
try:
    from pillow_heif import register_heif_opener
    register_heif_opener()
except ImportError:
    # pillow-heifがインストールされていない場合は警告のみ
    pass


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


def remove_background(input_image_path, output_image_path, 
                     model_name='u2net',
                     alpha_matting=False,
                     alpha_matting_foreground_threshold=240,
                     alpha_matting_background_threshold=10,
                     alpha_matting_erode_size=10,
                     post_process_mask=False):
    """
    画像から背景を除去する関数
    
    Args:
        input_image_path (str): 入力画像のパス
        output_image_path (str): 出力画像のパス（PNG形式推奨）
        model_name (str): 使用するモデル名（デフォルト: 'u2net'）
        alpha_matting (bool): アルファマッティングを使用して精度を向上（髪の毛など細かい部分に有効）
        alpha_matting_foreground_threshold (int): 前景の閾値（240が推奨）
        alpha_matting_background_threshold (int): 背景の閾値（10が推奨）
        alpha_matting_erode_size (int): エロージョンサイズ（10が推奨）
        post_process_mask (bool): マスクの後処理を有効化（精度向上）
    
    Returns:
        bool: 処理が成功した場合True、失敗した場合False
    """
    try:
        # 入力画像を開く
        input_image = Image.open(input_image_path)
    except IOError:
        print(f"Error: Cannot open {input_image_path}")
        return False

    try:
        # モデルセッションを作成
        session = new_session(model_name)
        print(f"Using model: {model_name} - {AVAILABLE_MODELS.get(model_name, 'Unknown model')}")
        
        # 背景を除去
        output_image = remove(
            input_image,
            session=session,
            alpha_matting=alpha_matting,
            alpha_matting_foreground_threshold=alpha_matting_foreground_threshold,
            alpha_matting_background_threshold=alpha_matting_background_threshold,
            alpha_matting_erode_size=alpha_matting_erode_size,
            post_process_mask=post_process_mask
        )
        
        # 出力ディレクトリが存在しない場合は作成
        output_dir = os.path.dirname(output_image_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        # 出力画像を保存
        output_image.save(output_image_path)
        print(f"Background removed successfully. Saved to: {output_image_path}")
        return True
    except Exception as e:
        print(f"Error during background removal: {e}")
        return False


def apply_mask_to_background(masked_image_path, background_color=(255, 255, 255)):
    """
    背景が除去された画像に新しい背景色を適用する関数
    
    Args:
        masked_image_path (str): 背景除去済み画像のパス（RGBA形式）
        background_color (tuple): 背景色 (B, G, R) - OpenCV形式
    
    Returns:
        numpy.ndarray: 背景が適用された画像、失敗した場合None
    """
    # RGBA画像を読み込み
    rgba_image = cv2.imread(masked_image_path, cv2.IMREAD_UNCHANGED)
    if rgba_image is None:
        print(f"Error: Cannot open {masked_image_path}")
        return None

    # アルファチャネルをマスクとして使用
    if rgba_image.shape[2] < 4:
        print("Error: Image does not have alpha channel")
        return None
    
    alpha_channel = rgba_image[:, :, 3]

    # 指定された背景色の背景画像を作成
    background = np.ones_like(rgba_image[:, :, :3], dtype=np.uint8)
    background[:, :, 0] = background_color[0]  # B
    background[:, :, 1] = background_color[1]  # G
    background[:, :, 2] = background_color[2]  # R

    # マスクを適用
    # 前景部分（アルファチャネルが255の部分）を保持
    foreground = rgba_image[:, :, :3]
    mask = alpha_channel / 255.0
    
    # マスクを3チャネルに拡張
    mask_3d = np.stack([mask, mask, mask], axis=2)
    
    # 背景と前景をブレンド
    result = (foreground * mask_3d + background * (1 - mask_3d)).astype(np.uint8)
    
    return result


def main():
    parser = argparse.ArgumentParser(
        description='Remove background from images using rembg (AI-powered)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
利用可能なモデル:
  u2net              : 一般的な前景/背景（人・物体の両方に対応、デフォルト）
  u2net_human_seg    : 人間専用（人物の精度が高い）
  u2netp             : 軽量版（処理速度が速い）
  silueta            : シルエット抽出
  isnet-general-use  : 高精度な一般用途
  birefnet-portrait  : ポートレート専用（人物写真に最適）
  sam                : Segment Anything Model（最高精度だが処理が遅い）

精度向上オプション:
  --alpha-matting    : アルファマッティングを使用（髪の毛など細かい部分の精度向上）
  --post-process      : マスクの後処理を有効化（エッジの滑らかさ向上）

例:
  # 人物専用モデルで高精度処理
  python background_remover.py photo.jpg --model u2net_human_seg --alpha-matting
  
  # 一般物体にも対応（複数人・複数物体も検出）
  python background_remover.py image.jpg --model u2net --post-process
        """
    )
    parser.add_argument('input', type=str, help='Input image path')
    parser.add_argument('-o', '--output', type=str, default=None, 
                       help='Output image path (default: input_name_remove.png)')
    parser.add_argument('--model', type=str, default='u2net',
                       choices=list(AVAILABLE_MODELS.keys()),
                       help='Model to use for background removal (default: u2net)')
    parser.add_argument('--alpha-matting', action='store_true',
                       help='Use alpha matting for better edge quality (especially for hair)')
    parser.add_argument('--alpha-matting-foreground-threshold', type=int, default=240,
                       help='Foreground threshold for alpha matting (default: 240)')
    parser.add_argument('--alpha-matting-background-threshold', type=int, default=10,
                       help='Background threshold for alpha matting (default: 10)')
    parser.add_argument('--alpha-matting-erode-size', type=int, default=10,
                       help='Erosion size for alpha matting (default: 10)')
    parser.add_argument('--post-process', action='store_true',
                       help='Enable post-processing mask refinement')
    parser.add_argument('--apply-background', action='store_true',
                       help='Apply white background to the result')
    parser.add_argument('--background-color', type=int, nargs=3, default=[255, 255, 255],
                       metavar=('B', 'G', 'R'),
                       help='Background color in BGR format (default: 255 255 255 for white)')
    
    args = parser.parse_args()
    
    # 入力ファイルの存在確認
    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' does not exist")
        return
    
    # 出力パスの設定
    if args.output is None:
        base_name = os.path.splitext(args.input)[0]
        args.output = f"{base_name}_remove.png"
    
    # 背景除去処理
    success = remove_background(
        args.input, 
        args.output,
        model_name=args.model,
        alpha_matting=args.alpha_matting,
        alpha_matting_foreground_threshold=args.alpha_matting_foreground_threshold,
        alpha_matting_background_threshold=args.alpha_matting_background_threshold,
        alpha_matting_erode_size=args.alpha_matting_erode_size,
        post_process_mask=args.post_process
    )
    
    if not success:
        return
    
    # 背景適用処理（オプション）
    if args.apply_background:
        masked_image = apply_mask_to_background(args.output, tuple(args.background_color))
        if masked_image is not None:
            output_with_bg = args.output.replace('.png', '_with_background.jpg')
            cv2.imwrite(output_with_bg, masked_image)
            print(f"Image with background saved to: {output_with_bg}")


if __name__ == "__main__":
    main()

