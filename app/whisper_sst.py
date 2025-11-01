import sounddevice as sd
import numpy as np
import queue
import threading
import time
import whisper
import torch
import wave
import io
import tempfile
import os

def main():
    # Whisperモデルの読み込み
    print("Whisperモデルを読み込んでいます...")
    model = whisper.load_model("base")  # モデルサイズ: tiny, base, small, medium, large
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"使用デバイス: {device}")
    
    # オーディオ設定
    samplerate = 16000  # Whisperの推奨サンプルレート
    channels = 1
    blocksize = 1600  # 0.1秒分
    q = queue.Queue()
    
    # 音声検出のパラメータ
    THRESHOLD = 0.005  # 閾値を下げる
    SILENCE_THRESHOLD = 0.003
    SILENCE_DURATION = 1.0
    MIN_SPEECH_DURATION = 0.3
    
    # 音声認識の状態管理
    is_speaking = False
    speech_start_time = 0
    last_speech_time = 0
    current_text = ""
    audio_buffer = []
    
    # 利用可能なデバイスを表示
    print("利用可能なマイクデバイス:")
    devices = sd.query_devices()
    print(devices)
    
    # デフォルトデバイスの情報を表示
    default_input = sd.query_devices(kind='input')
    print("\nデフォルトの入力デバイス:")
    print(default_input)
    
    def audio_callback(indata, frames, time, status):
        if status:
            print(f"ステータス: {status}")
        q.put(indata.copy())
    
    def save_audio_to_wav(audio_data, filename):
        """音声データをWAVファイルとして保存"""
        with wave.open(filename, 'wb') as wf:
            wf.setnchannels(channels)
            wf.setsampwidth(2)  # 16-bit
            wf.setframerate(samplerate)
            wf.writeframes((audio_data * 32767).astype(np.int16).tobytes())
    
    def process_audio(audio_data):
        nonlocal is_speaking, speech_start_time, last_speech_time, current_text, audio_buffer
        
        current_time = time.time()
        audio_level = np.abs(audio_data).mean()
        
        # 音声レベルの表示（デバッグ用）
        print(f"\r現在の音声レベル: {audio_level:.4f}", end="")
        
        if audio_level > THRESHOLD:
            if not is_speaking:
                is_speaking = True
                speech_start_time = current_time
                audio_buffer = []
                print("\n音声入力を検出しました...")
            
            last_speech_time = current_time
            audio_buffer.append(audio_data)
            
        elif is_speaking and (current_time - last_speech_time) > SILENCE_DURATION:
            if (current_time - speech_start_time) >= MIN_SPEECH_DURATION:
                # 音声認識の実行
                combined_audio = np.concatenate(audio_buffer)
                
                # デバッグ情報
                print(f"\n音声データの長さ: {len(combined_audio)} サンプル")
                print(f"音声データの形状: {combined_audio.shape}")
                print(f"音声データの最大値: {np.max(np.abs(combined_audio))}")
                
                try:
                    # 一時ファイルに音声を保存
                    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
                        temp_filename = temp_file.name
                    
                    save_audio_to_wav(combined_audio, temp_filename)
                    print(f"音声ファイルを保存しました: {temp_filename}")
                    
                    # Whisperで音声認識
                    print("音声認識を実行中...")
                    result = model.transcribe(
                        temp_filename,
                        language="ja",
                        task="transcribe",
                        fp16=False
                    )
                    
                    # 一時ファイルを削除
                    os.unlink(temp_filename)
                    
                    text = result["text"].strip()
                    print(f"認識結果（生）: {text}")
                    
                    # 文脈に基づく認識結果の更新
                    if current_text:
                        if text.startswith(current_text):
                            new_text = text[len(current_text):]
                            current_text = text
                            print(f"\n認識結果（追加）: {new_text}")
                        else:
                            current_text = text
                            print(f"\n認識結果（更新）: {text}")
                    else:
                        current_text = text
                        print(f"\n認識結果: {text}")
                    
                except Exception as e:
                    print(f"\n音声認識エラー: {e}")
                    import traceback
                    traceback.print_exc()
            
            is_speaking = False
            audio_buffer = []
    
    try:
        # マイクストリームを開始
        stream = sd.InputStream(
            samplerate=samplerate,
            channels=channels,
            callback=audio_callback,
            blocksize=blocksize,
            dtype=np.float32
        )
        
        with stream:
            print("\nマイクの環境ノイズを調整しています...")
            time.sleep(2)
            print("準備完了！話しかけてください。")
            print("音声レベルをモニタリング中...")
            
            while True:
                try:
                    audio_data = q.get()
                    process_audio(audio_data)
                    
                except KeyboardInterrupt:
                    print("\nプログラムを終了します。")
                    break
                except Exception as e:
                    print(f"\nエラーが発生しました: {e}")
                    import traceback
                    traceback.print_exc()
    
    except Exception as e:
        print(f"マイクの初期化エラー: {e}")
        print("マイクが正しく接続されているか確認してください。")

if __name__ == "__main__":
    main() 