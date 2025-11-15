#!/usr/bin/env python3
"""
iOSアプリ組み込み用の高精度背景除去ツール

特徴:
- 複数人物の自動検出
- 選択した人物のみを抽出
- 高精度な背景除去（u2net_human_seg + alpha matting）
- ONNX Runtime使用でiOSアプリに移植可能
"""

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from rembg import remove, new_session
import os
import argparse
import json

# HEIC形式のサポート
try:
    from pillow_heif import register_heif_opener
    register_heif_opener()
except ImportError:
    pass

try:
    from ultralytics import YOLO
    YOLO_AVAILABLE = True
except ImportError:
    YOLO_AVAILABLE = False
    print("警告: ultralyticsがインストールされていません。人物検出機能を使用するには 'pip install ultralytics' を実行してください。")


class MobileBackgroundRemover:
    """iOSアプリ組み込み用の高精度背景除去クラス"""
    
    def __init__(self, model_name='u2net_human_seg', use_alpha_matting=True):
        """
        初期化
        
        Args:
            model_name: 背景除去モデル名
            use_alpha_matting: アルファマッティングを使用するか
        """
        self.model_name = model_name
        self.use_alpha_matting = use_alpha_matting
        self.bg_session = None
        self.person_detector = None
        
        # 背景除去モデルのセッションを作成
        self._init_bg_model()
        
        # 人物検出モデルの初期化（オプション）
        if YOLO_AVAILABLE:
            self._init_person_detector()
    
    def _init_bg_model(self):
        """背景除去モデルを初期化"""
        print(f"背景除去モデルを初期化中: {self.model_name}")
        self.bg_session = new_session(self.model_name)
        print("✓ 背景除去モデルの準備完了")
    
    def _init_person_detector(self):
        """人物検出モデルを初期化"""
        try:
            print("人物検出モデルを初期化中...")
            # YOLOv8の人物検出モデル（軽量版）
            self.person_detector = YOLO('yolov8n.pt')  # nano版（軽量・高速）
            print("✓ 人物検出モデルの準備完了")
        except Exception as e:
            print(f"警告: 人物検出モデルの初期化に失敗: {e}")
            self.person_detector = None
    
    def detect_persons(self, image_path, confidence_threshold=0.25):
        """
        画像内の人物を検出
        
        Args:
            image_path: 画像パス
            confidence_threshold: 信頼度の閾値
        
        Returns:
            list: 検出された人物の情報リスト [{'bbox': [x1, y1, x2, y2], 'confidence': float, 'id': int}, ...]
        """
        if not self.person_detector:
            print("警告: 人物検出モデルが利用できません")
            return []
        
        try:
            # YOLOで人物を検出（クラス0がperson）
            results = self.person_detector(image_path, conf=confidence_threshold, classes=[0])
            
            persons = []
            for idx, result in enumerate(results):
                boxes = result.boxes
                for box in boxes:
                    # バウンディングボックス座標を取得
                    x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                    confidence = float(box.conf[0].cpu().numpy())
                    
                    persons.append({
                        'id': len(persons),
                        'bbox': [int(x1), int(y1), int(x2), int(y2)],
                        'confidence': confidence
                    })
            
            print(f"✓ {len(persons)}人の人物を検出しました")
            return persons
        except Exception as e:
            print(f"人物検出エラー: {e}")
            return []
    
    def visualize_detections(self, image_path, persons, output_path=None):
        """
        検出結果を可視化
        
        Args:
            image_path: 元画像のパス
            persons: 検出された人物のリスト
            output_path: 出力画像のパス（Noneの場合は表示のみ）
        
        Returns:
            PIL.Image: 可視化された画像
        """
        img = Image.open(image_path)
        draw = ImageDraw.Draw(img)
        
        # フォントの設定（利用可能な場合）
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
        except:
            font = ImageFont.load_default()
        
        colors = [
            (255, 0, 0),    # 赤
            (0, 255, 0),    # 緑
            (0, 0, 255),    # 青
            (255, 255, 0),  # 黄
            (255, 0, 255),  # マゼンタ
            (0, 255, 255),  # シアン
        ]
        
        for person in persons:
            x1, y1, x2, y2 = person['bbox']
            person_id = person['id']
            confidence = person['confidence']
            color = colors[person_id % len(colors)]
            
            # バウンディングボックスを描画
            draw.rectangle([x1, y1, x2, y2], outline=color, width=3)
            
            # ラベルを描画
            label = f"Person {person_id + 1} ({confidence:.2f})"
            draw.text((x1, y1 - 25), label, fill=color, font=font)
        
        if output_path:
            img.save(output_path)
            print(f"検出結果を保存: {output_path}")
        
        return img
    
    def remove_background_for_person(self, image_path, person_bbox, output_path):
        """
        指定された人物の背景を除去
        
        Args:
            image_path: 元画像のパス
            person_bbox: 人物のバウンディングボックス [x1, y1, x2, y2]
            output_path: 出力画像のパス
        
        Returns:
            bool: 成功した場合True
        """
        try:
            # 画像を読み込み
            img = Image.open(image_path)
            
            # 人物領域を切り抜き（余白を追加）
            x1, y1, x2, y2 = person_bbox
            margin = 20  # 余白
            x1 = max(0, x1 - margin)
            y1 = max(0, y1 - margin)
            x2 = min(img.width, x2 + margin)
            y2 = min(img.height, y2 + margin)
            
            # 人物領域を切り抜き
            person_crop = img.crop((x1, y1, x2, y2))
            
            # 背景除去
            print(f"背景除去中... (Person at [{x1}, {y1}, {x2}, {y2}])")
            result = remove(
                person_crop,
                session=self.bg_session,
                alpha_matting=self.use_alpha_matting,
                alpha_matting_foreground_threshold=240,
                alpha_matting_background_threshold=10,
                alpha_matting_erode_size=10,
                post_process_mask=True
            )
            
            # 元の画像サイズに戻す
            final_img = Image.new('RGBA', img.size, (0, 0, 0, 0))
            final_img.paste(result, (x1, y1), result)
            
            # 保存
            final_img.save(output_path)
            print(f"✓ 背景除去完了: {output_path}")
            return True
            
        except Exception as e:
            print(f"背景除去エラー: {e}")
            return False
    
    def remove_background_for_selected_persons(self, image_path, person_ids, output_path):
        """
        選択された複数の人物の背景を除去
        
        Args:
            image_path: 元画像のパス
            person_ids: 選択された人物のIDリスト [0, 2, ...]
            output_path: 出力画像のパス
        
        Returns:
            bool: 成功した場合True
        """
        # まず人物を検出
        persons = self.detect_persons(image_path)
        
        if not persons:
            print("人物が検出されませんでした")
            return False
        
        # 選択された人物のみをフィルタリング
        selected_persons = [p for p in persons if p['id'] in person_ids]
        
        if not selected_persons:
            print(f"選択された人物ID {person_ids} が見つかりませんでした")
            return False
        
        try:
            # 画像を読み込み
            img = Image.open(image_path)
            final_img = Image.new('RGBA', img.size, (0, 0, 0, 0))
            
            # 各人物の背景を除去して合成
            for person in selected_persons:
                x1, y1, x2, y2 = person['bbox']
                margin = 20
                x1 = max(0, x1 - margin)
                y1 = max(0, y1 - margin)
                x2 = min(img.width, x2 + margin)
                y2 = min(img.height, y2 + margin)
                
                person_crop = img.crop((x1, y1, x2, y2))
                
                # 背景除去
                result = remove(
                    person_crop,
                    session=self.bg_session,
                    alpha_matting=self.use_alpha_matting,
                    alpha_matting_foreground_threshold=240,
                    alpha_matting_background_threshold=10,
                    alpha_matting_erode_size=10,
                    post_process_mask=True
                )
                
                # 合成
                final_img.paste(result, (x1, y1), result)
            
            # 保存
            final_img.save(output_path)
            print(f"✓ {len(selected_persons)}人の背景除去完了: {output_path}")
            return True
            
        except Exception as e:
            print(f"背景除去エラー: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(
        description='iOSアプリ組み込み用の高精度背景除去ツール（人物検出・選択機能付き）',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用例:
  # 1. 人物を検出して可視化
  python mobile_background_remover.py image.jpg --detect
  
  # 2. 検出された人物のうち、1人目（ID: 0）のみを抽出
  python mobile_background_remover.py image.jpg --select 0
  
  # 3. 複数の人物を選択して抽出（1人目と3人目）
  python mobile_background_remover.py image.jpg --select 0 2
  
  # 4. すべての人物を抽出
  python mobile_background_remover.py image.jpg --select-all
        """
    )
    
    parser.add_argument('input', type=str, help='入力画像のパス')
    parser.add_argument('-o', '--output', type=str, default=None,
                       help='出力画像のパス')
    parser.add_argument('--detect', action='store_true',
                       help='人物を検出して可視化（選択用）')
    parser.add_argument('--select', type=int, nargs='+', default=None,
                       help='抽出する人物のID（例: --select 0 または --select 0 2）')
    parser.add_argument('--select-all', action='store_true',
                       help='検出されたすべての人物を抽出')
    parser.add_argument('--model', type=str, default='u2net_human_seg',
                       choices=['u2net', 'u2net_human_seg', 'u2netp', 'birefnet-portrait'],
                       help='背景除去モデル（デフォルト: u2net_human_seg）')
    parser.add_argument('--no-alpha-matting', action='store_true',
                       help='アルファマッティングを無効化（処理速度向上）')
    parser.add_argument('--confidence', type=float, default=0.25,
                       help='人物検出の信頼度閾値（デフォルト: 0.25）')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.input):
        print(f"エラー: 入力ファイル '{args.input}' が見つかりません")
        return
    
    # 背景除去ツールを初期化
    remover = MobileBackgroundRemover(
        model_name=args.model,
        use_alpha_matting=not args.no_alpha_matting
    )
    
    # 出力パスの設定
    if args.output is None:
        base_name = os.path.splitext(args.input)[0]
        args.output = f"{base_name}_mobile_remove.png"
    
    # 人物検出モード
    if args.detect:
        print("\n=== 人物検出モード ===")
        persons = remover.detect_persons(args.input, confidence_threshold=args.confidence)
        
        if persons:
            print(f"\n検出された人物: {len(persons)}人")
            for person in persons:
                print(f"  Person {person['id'] + 1}: 信頼度 {person['confidence']:.2f}, "
                      f"位置 [{person['bbox'][0]}, {person['bbox'][1]}, "
                      f"{person['bbox'][2]}, {person['bbox'][3]}]")
            
            # 可視化
            vis_output = args.output.replace('.png', '_detections.png')
            remover.visualize_detections(args.input, persons, vis_output)
            print(f"\n検出結果を可視化: {vis_output}")
            print(f"\n次のコマンドで人物を抽出できます:")
            print(f"  python mobile_background_remover.py {args.input} --select 0")
        else:
            print("人物が検出されませんでした")
        return
    
    # 背景除去モード
    if args.select_all:
        # すべての人物を抽出
        persons = remover.detect_persons(args.input, confidence_threshold=args.confidence)
        if persons:
            person_ids = [p['id'] for p in persons]
            remover.remove_background_for_selected_persons(
                args.input, person_ids, args.output
            )
        else:
            print("人物が検出されませんでした")
    
    elif args.select is not None:
        # 選択された人物を抽出
        remover.remove_background_for_selected_persons(
            args.input, args.select, args.output
        )
    
    else:
        # デフォルト: すべての人物を抽出
        print("人物を検出中...")
        persons = remover.detect_persons(args.input, confidence_threshold=args.confidence)
        if persons:
            person_ids = [p['id'] for p in persons]
            print(f"検出された {len(persons)} 人すべてを抽出します")
            remover.remove_background_for_selected_persons(
                args.input, person_ids, args.output
            )
        else:
            print("人物が検出されませんでした。通常の背景除去を実行します...")
            # 人物が検出されない場合は通常の背景除去
            img = Image.open(args.input)
            result = remove(
                img,
                session=remover.bg_session,
                alpha_matting=remover.use_alpha_matting,
                alpha_matting_foreground_threshold=240,
                alpha_matting_background_threshold=10,
                alpha_matting_erode_size=10,
                post_process_mask=True
            )
            result.save(args.output)
            print(f"✓ 背景除去完了: {args.output}")


if __name__ == "__main__":
    main()


