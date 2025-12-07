# AWS知見がある場合のホスティングガイド

AWSの知見がある場合、Pythonベース（FastAPI）のAPIサーバーをホスティングする最適な方法を比較します。

## 🎯 要件

- **Pythonベース**: FastAPIアプリケーション
- **シンプル**: 設定が簡単
- **低コスト**: 無料または月額$5以下
- **AWS知見あり**: AWSの知識を活かせる

---

## 📊 AWS選択肢の比較

### 🥇 推奨1位: AWS Lambda + API Gateway（サーバーレス）

**評価**: ⭐⭐⭐⭐⭐

#### 特徴

- ✅ **サーバーレス**: サーバー管理不要
- ✅ **自動スケーリング**: トラフィックに応じて自動スケール
- ✅ **組み込み機能**: APIキー管理、レート制限が自動
- ✅ **無料利用枠**: 100万リクエスト/月（永続）
- ✅ **コスト効率**: 使用した分だけ課金
- ⚠️ **SQLite制限**: サーバーレス環境ではSQLiteが難しい（DynamoDB推奨）

#### コスト

- **無料利用枠**:
  - Lambda: 100万リクエスト/月、40万GB-秒/月
  - API Gateway: 100万リクエスト/月（12ヶ月間）
  - DynamoDB: 25GBストレージ、200万読み取り/月
- **小規模運用**: $0-2/月（無料枠内）
- **中規模運用**: $5-15/月

#### アーキテクチャ

```
iOSアプリ
   │
   ▼
Amazon API Gateway
   │
   ├── API Keys（組み込み）
   ├── Usage Plans（組み込み）
   ├── スロットリング（組み込み）
   └── Lambda統合
   ▼
AWS Lambda (Python)
   │
   ├── DynamoDB（ユーザー管理）
   ├── DynamoDB（利用履歴）
   └── Fish Audio API呼び出し
   ▼
Fish Audio API
```

#### 実装の複雑さ

- **難易度**: 中（AWS知識があれば容易）
- **実装時間**: 2-3日
- **デプロイ**: AWS SAM / CDK

#### メリット

- 組み込み機能が豊富（APIキー管理、レート制限）
- 自動スケーリング
- サーバー管理不要
- コスト効率が良い

#### デメリット

- SQLiteが使えない（DynamoDBに移行が必要）
- コールドスタート（初回リクエストが遅い場合あり）
- デバッグがやや複雑

---

### 🥈 推奨2位: AWS Lightsail

**評価**: ⭐⭐⭐⭐

#### 特徴

- ✅ **シンプル**: VPSのような使い方
- ✅ **FastAPI対応**: 通常のPythonアプリとして動作
- ✅ **SQLite対応**: ファイルシステムに保存可能
- ✅ **固定料金**: 予測可能なコスト
- ✅ **簡単デプロイ**: SSHで直接デプロイ可能

#### コスト

- **$3.50/月**: 512MB RAM、1 vCPU、20GB SSD
- **$5/月**: 1GB RAM、1 vCPU、40GB SSD（推奨）
- **$10/月**: 2GB RAM、1 vCPU、60GB SSD

#### アーキテクチャ

```
iOSアプリ
   │
   ▼
AWS Lightsail (Ubuntu)
   │
   ├── Nginx（リバースプロキシ）
   ├── FastAPI（Python）
   ├── SQLite（ファイル）
   └── Fish Audio API呼び出し
   ▼
Fish Audio API
```

#### 実装の複雑さ

- **難易度**: 低（通常のVPSと同じ）
- **実装時間**: 1-2日
- **デプロイ**: SSH + Git

#### メリット

- シンプルで理解しやすい
- SQLiteがそのまま使える
- 固定料金で予測可能
- 現在のコードをそのまま使える

#### デメリット

- サーバー管理が必要（ただし最小限）
- スケーリングは手動
- 組み込み機能が少ない（自前実装が必要）

---

### 🥉 推奨3位: EC2 + Elastic Beanstalk

**評価**: ⭐⭐⭐

#### 特徴

- ✅ **柔軟性**: 完全な制御が可能
- ✅ **FastAPI対応**: 通常のPythonアプリとして動作
- ✅ **SQLite対応**: ファイルシステムに保存可能
- ⚠️ **複雑さ**: 設定がやや複雑
- ⚠️ **コスト**: EC2インスタンスの料金

#### コスト

- **t3.micro**: $7-10/月（無料枠あり、12ヶ月間）
- **t3.small**: $15-20/月

#### メリット

- 完全な制御が可能
- スケーリング設定が柔軟
- 現在のコードをそのまま使える

#### デメリット

- 設定が複雑
- サーバー管理が必要
- コストがやや高い

---

### その他の選択肢

#### ECS Fargate

- **評価**: ⭐⭐⭐
- **特徴**: コンテナベース、サーバーレス
- **コスト**: $10-20/月
- **用途**: より大規模な運用

#### App Runner

- **評価**: ⭐⭐⭐
- **特徴**: コンテナベース、自動デプロイ
- **コスト**: $5-10/月
- **用途**: 中規模運用

---

## 📊 詳細比較表

| 項目 | Lambda + API Gateway | Lightsail | EC2 + Beanstalk | Railway |
|------|---------------------|-----------|-----------------|---------|
| **初期コスト** | $0 | $5/月 | $7-10/月 | $0 |
| **小規模運用** | $0-2/月 | $5/月 | $7-10/月 | $0 |
| **実装の複雑さ** | 中 | 低 | 中 | 低 |
| **SQLite対応** | ❌（DynamoDB必要） | ✅ | ✅ | ✅ |
| **組み込み機能** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐ |
| **スケーラビリティ** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **サーバー管理** | 不要 | 最小限 | 必要 | 不要 |
| **デプロイ** | SAM/CDK | SSH/Git | Beanstalk | Git push |
| **AWS知識** | 必要 | 基本 | 必要 | 不要 |

---

## 🎯 推奨順位（AWS知見がある場合）

### 1位: AWS Lambda + API Gateway（サーバーレス）

**推奨する場合**:
- ✅ 組み込み機能を活用したい
- ✅ 自動スケーリングが必要
- ✅ サーバー管理を避けたい
- ✅ DynamoDBへの移行が可能

**実装時間**: 2-3日

### 2位: AWS Lightsail

**推奨する場合**:
- ✅ シンプルな構成で十分
- ✅ SQLiteをそのまま使いたい
- ✅ 固定料金で予測したい
- ✅ 現在のコードをそのまま使いたい

**実装時間**: 1-2日

### 3位: Railway（非AWS）

**推奨する場合**:
- ✅ 最も簡単に始めたい
- ✅ AWS以外の選択肢も検討
- ✅ すぐにデプロイしたい

**実装時間**: 30分-1時間

---

## 🚀 AWS Lambda + API Gateway実装ガイド

### 前提条件

- AWSアカウント
- AWS CLI設定済み
- Python 3.9以上

### 1. プロジェクト構造

```
tts-api-server-aws/
├── lambda/
│   ├── lambda_function.py
│   ├── database.py
│   └── requirements.txt
├── template.yaml  # SAMテンプレート
└── README.md
```

### 2. Lambda関数の実装

#### `lambda/lambda_function.py`

```python
import json
import boto3
import requests
import os
from datetime import datetime, date
from decimal import Decimal

# DynamoDBクライアント
dynamodb = boto3.resource('dynamodb')
users_table = dynamodb.Table('tts-users')
usage_table = dynamodb.Table('tts-usage-history')
costs_table = dynamodb.Table('tts-monthly-costs')

FISH_AUDIO_API_KEY = os.environ['FISH_AUDIO_API_KEY']

def lambda_handler(event, context):
    """TTS生成エンドポイント"""
    try:
        # API Gatewayからリクエストを取得
        headers = event.get('headers', {})
        api_key = headers.get('X-API-Key') or headers.get('x-api-key')
        
        if not api_key:
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'detail': 'X-API-Keyヘッダーが必要です'})
            }
        
        # ユーザー情報を取得
        user = get_user_by_api_key(api_key)
        if not user:
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'detail': '無効なAPIキーです'})
            }
        
        # 利用制限チェック
        is_allowed, error_message = check_usage_limit(user)
        if not is_allowed:
            return {
                'statusCode': 429,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'detail': error_message})
            }
        
        # リクエストボディを取得
        body = json.loads(event.get('body', '{}'))
        text = body.get('text', '')
        
        if not text:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'detail': 'textパラメータが必要です'})
            }
        
        # Fish Audio APIを呼び出し
        audio_bytes = call_fish_audio_tts(
            text=text,
            model_id=body.get('model_id'),
            format=body.get('format', 'mp3'),
            speed=body.get('speed', 1.0),
            volume=body.get('volume', 0)
        )
        
        # 利用履歴を記録
        record_usage(user['user_id'], 'tts', 0.1)
        
        # 音声ファイルをBase64エンコードして返す
        import base64
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'audio/mp3',
                'Content-Disposition': 'attachment; filename="tts_output.mp3"'
            },
            'body': audio_base64,
            'isBase64Encoded': True
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'detail': f'内部サーバーエラー: {str(e)}'})
        }

def get_user_by_api_key(api_key):
    """DynamoDBからユーザー情報を取得"""
    try:
        response = users_table.scan(
            FilterExpression='api_key = :key',
            ExpressionAttributeValues={':key': api_key}
        )
        
        if response['Items']:
            user = response['Items'][0]
            # Decimalをfloatに変換
            return {
                'user_id': user['user_id'],
                'api_key': user['api_key'],
                'daily_tts_limit': int(user['daily_tts_limit']),
                'daily_clone_limit': int(user['daily_clone_limit'])
            }
        return None
    except Exception as e:
        print(f"Error getting user: {str(e)}")
        return None

def check_usage_limit(user):
    """利用制限をチェック"""
    try:
        # 日次制限チェック
        today = date.today().isoformat()
        response = usage_table.query(
            KeyConditionExpression='user_id = :uid AND begins_with(timestamp, :date)',
            ExpressionAttributeValues={
                ':uid': user['user_id'],
                ':date': today
            }
        )
        
        daily_tts_count = sum(
            1 for item in response['Items'] 
            if item.get('usage_type') == 'tts'
        )
        
        if daily_tts_count >= user['daily_tts_limit']:
            return False, f"日次利用制限に達しました（{user['daily_tts_limit']}回/日）"
        
        # 月次コスト制限チェック
        year_month = datetime.now().strftime('%Y-%m')
        response = costs_table.get_item(Key={'year_month': year_month})
        
        if 'Item' in response:
            monthly_cost = float(response['Item']['total_cost'])
            if monthly_cost >= 5000.0:  # 月次上限
                return False, "月次コスト上限に達しました"
        
        return True, ""
    except Exception as e:
        print(f"Error checking usage limit: {str(e)}")
        return False, "利用制限チェック中にエラーが発生しました"

def call_fish_audio_tts(text, model_id=None, format='mp3', speed=1.0, volume=0):
    """Fish Audio APIを呼び出し"""
    url = "https://api.fish.audio/v1/tts"
    headers = {
        "Authorization": f"Bearer {FISH_AUDIO_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "text": text,
        "format": format,
        "prosody": {
            "speed": speed,
            "volume": volume
        },
        "normalize": True,
        "latency": "balanced"
    }
    
    if model_id:
        payload["reference_id"] = model_id
    
    if format == "mp3":
        payload["mp3_bitrate"] = 192
    elif format == "wav":
        payload["sample_rate"] = 44100
    
    response = requests.post(url, json=payload, headers=headers, timeout=30)
    response.raise_for_status()
    return response.content

def record_usage(user_id, usage_type, cost):
    """利用履歴を記録"""
    try:
        timestamp = datetime.now().isoformat()
        
        # 利用履歴を記録
        usage_table.put_item(Item={
            'user_id': user_id,
            'timestamp': timestamp,
            'usage_type': usage_type,
            'cost': Decimal(str(cost))
        })
        
        # 月次コストを更新
        year_month = datetime.now().strftime('%Y-%m')
        costs_table.update_item(
            Key={'year_month': year_month},
            UpdateExpression='ADD total_cost :cost',
            ExpressionAttributeValues={':cost': Decimal(str(cost))}
        )
    except Exception as e:
        print(f"Error recording usage: {str(e)}")
```

#### `lambda/requirements.txt`

```txt
boto3>=1.28.0
requests>=2.31.0
```

### 3. SAMテンプレート

#### `template.yaml`

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: TTS API Server using Lambda and API Gateway

Globals:
  Function:
    Timeout: 30
    MemorySize: 512
    Runtime: python3.11
    Environment:
      Variables:
        FISH_AUDIO_API_KEY: !Ref FishAudioApiKey

Resources:
  # DynamoDB Tables
  UsersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: tts-users
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: user_id
          AttributeType: S
      KeySchema:
        - AttributeName: user_id
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: api-key-index
          KeySchema:
            - AttributeName: api_key
              KeyType: HASH
          Projection:
            ProjectionType: ALL

  UsageHistoryTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: tts-usage-history
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: user_id
          AttributeType: S
        - AttributeName: timestamp
          AttributeType: S
      KeySchema:
        - AttributeName: user_id
          KeyType: HASH
        - AttributeName: timestamp
          KeyType: RANGE

  MonthlyCostsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: tts-monthly-costs
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: year_month
          AttributeType: S
      KeySchema:
        - AttributeName: year_month
          KeyType: HASH

  # Lambda Function
  TTSApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: tts-api-function
      CodeUri: lambda/
      Handler: lambda_function.lambda_handler
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref UsersTable
        - DynamoDBCrudPolicy:
            TableName: !Ref UsageHistoryTable
        - DynamoDBCrudPolicy:
            TableName: !Ref MonthlyCostsTable

  # API Gateway
  TTSApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Cors:
        AllowMethods: "'*'"
        AllowHeaders: "'*'"
        AllowOrigin: "'*'"
      Auth:
        ApiKeyRequired: false  # カスタム認証を使用

  # API Gateway Integration
  TTSApiFunctionApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Cors:
        AllowMethods: "'*'"
        AllowHeaders: "'*'"
        AllowOrigin: "'*'"
      DefinitionBody:
        swagger: '2.0'
        info:
          title: TTS API
        paths:
          /api/v2/tts/generate:
            post:
              x-amazon-apigateway-integration:
                uri: !Sub arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${TTSApiFunction.Arn}/invocations
                httpMethod: POST
                type: aws_proxy
              responses:
                '200':
                  description: Success

Parameters:
  FishAudioApiKey:
    Type: String
    Description: Fish Audio API Key
    NoEcho: true
```

### 4. デプロイ手順

```bash
# 1. SAM CLIをインストール
# macOS
brew install aws-sam-cli

# 2. プロジェクトを初期化（既に作成済みの場合はスキップ）
sam init

# 3. ビルド
sam build

# 4. 環境変数を設定
export FISH_AUDIO_API_KEY=your_api_key_here

# 5. デプロイ
sam deploy --guided

# または、パラメータファイルを使用
sam deploy --parameter-overrides FishAudioApiKey=your_api_key_here
```

### 5. DynamoDBテーブルの作成（手動）

```bash
# Usersテーブル
aws dynamodb create-table \
    --table-name tts-users \
    --attribute-definitions AttributeName=user_id,AttributeType=S \
    --key-schema AttributeName=user_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

# Usage Historyテーブル
aws dynamodb create-table \
    --table-name tts-usage-history \
    --attribute-definitions \
        AttributeName=user_id,AttributeType=S \
        AttributeName=timestamp,AttributeType=S \
    --key-schema \
        AttributeName=user_id,KeyType=HASH \
        AttributeName=timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST

# Monthly Costsテーブル
aws dynamodb create-table \
    --table-name tts-monthly-costs \
    --attribute-definitions AttributeName=year_month,AttributeType=S \
    --key-schema AttributeName=year_month,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

---

## 🚀 AWS Lightsail実装ガイド

### 1. Lightsailインスタンスの作成

1. AWSコンソールでLightsailにアクセス
2. 「Create instance」をクリック
3. 設定:
   - **Platform**: Linux/Unix
   - **Blueprint**: Ubuntu 22.04 LTS
   - **Instance plan**: $5/月（1GB RAM、1 vCPU、40GB SSD）

### 2. SSH接続

```bash
# LightsailからSSHキーをダウンロード
# または、既存のSSHキーを使用

ssh -i ~/.ssh/lightsail-key.pem ubuntu@your-instance-ip
```

### 3. 環境セットアップ

```bash
# システム更新
sudo apt update && sudo apt upgrade -y

# Python 3.11をインストール
sudo apt install python3.11 python3.11-venv python3-pip -y

# Nginxをインストール
sudo apt install nginx -y

# Gitをインストール
sudo apt install git -y
```

### 4. アプリケーションのデプロイ

```bash
# アプリケーションディレクトリを作成
mkdir -p /var/www/tts-api
cd /var/www/tts-api

# リポジトリをクローン
git clone https://github.com/yourusername/tts-api-server.git .

# 仮想環境を作成
python3.11 -m venv venv
source venv/bin/activate

# 依存関係をインストール
pip install -r tts_api_server/requirements.txt

# 環境変数を設定
cd tts_api_server
echo "FISH_AUDIO_API_KEY=your_api_key_here" > .env
echo "PORT=8000" >> .env
```

### 5. systemdサービスを作成

```bash
sudo nano /etc/systemd/system/tts-api.service
```

```ini
[Unit]
Description=TTS API Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/tts-api/tts_api_server
Environment="PATH=/var/www/tts-api/venv/bin"
ExecStart=/var/www/tts-api/venv/bin/python api_server.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# サービスを有効化
sudo systemctl enable tts-api
sudo systemctl start tts-api
sudo systemctl status tts-api
```

### 6. Nginx設定

```bash
sudo nano /etc/nginx/sites-available/tts-api
```

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# シンボリックリンクを作成
sudo ln -s /etc/nginx/sites-available/tts-api /etc/nginx/sites-enabled/

# Nginxを再起動
sudo nginx -t
sudo systemctl restart nginx
```

### 7. SSL証明書（Let's Encrypt）

```bash
# Certbotをインストール
sudo apt install certbot python3-certbot-nginx -y

# SSL証明書を取得
sudo certbot --nginx -d your-domain.com
```

---

## 💰 コスト比較（AWS知見がある場合）

### 小規模運用（~50ユーザー、月間10,000リクエスト）

| サービス | 月額コスト | 評価 |
|---------|-----------|------|
| **Lambda + API Gateway** | **$0-2** | 最推奨（無料枠内） |
| **Lightsail** | **$5** | 次点（固定料金） |
| Railway | $0 | AWS以外の選択肢 |

### 中規模運用（~500ユーザー、月間100,000リクエスト）

| サービス | 月額コスト | 評価 |
|---------|-----------|------|
| **Lambda + API Gateway** | **$5-10** | 最推奨 |
| **Lightsail** | **$5** | 次点（固定料金） |
| Railway | $5-10 | AWS以外の選択肢 |

---

## 🎯 最終推奨（AWS知見がある場合）

### 組み込み機能を活用したい場合

**推奨: AWS Lambda + API Gateway**

理由:
1. ✅ APIキー管理が自動
2. ✅ レート制限が自動
3. ✅ 自動スケーリング
4. ✅ サーバー管理不要
5. ✅ 無料枠が充実

**実装時間**: 2-3日

### シンプルで固定料金を希望する場合

**推奨: AWS Lightsail**

理由:
1. ✅ 現在のコードをそのまま使える
2. ✅ SQLiteが使える
3. ✅ 固定料金（$5/月）
4. ✅ シンプルな構成

**実装時間**: 1-2日

### 最も簡単に始めたい場合

**推奨: Railway**

理由:
1. ✅ デプロイが最も簡単
2. ✅ 無料クレジット
3. ✅ AWS知識不要

**実装時間**: 30分-1時間

---

## 📚 参考リソース

### AWS Lambda + API Gateway

- [AWS SAM ドキュメント](https://docs.aws.amazon.com/serverless-application-model/)
- [Lambda Python ランタイム](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [API Gateway ドキュメント](https://docs.aws.amazon.com/apigateway/)

### AWS Lightsail

- [Lightsail ドキュメント](https://docs.aws.amazon.com/lightsail/)
- [Lightsail チュートリアル](https://lightsail.aws.amazon.com/ls/docs/)

---

## 🔗 関連ドキュメント

- [AWS_COMPARISON.md](./AWS_COMPARISON.md) - AWS実装との詳細比較
- [HOSTING_COMPARISON.md](./HOSTING_COMPARISON.md) - ホスティングサービス比較
- [README.md](../README.md) - プロジェクトの概要

