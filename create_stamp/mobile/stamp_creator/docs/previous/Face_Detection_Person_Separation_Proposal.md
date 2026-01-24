# 顔検出による人物分離の実装案

## 概要
`VNDetectFaceRectanglesRequest`を使用して、選択したい人物の顔を特定し、その顔に最も近い人物領域のみを選択する方法です。

## 実装手順

### 1. 顔検出を追加
```swift
// 顔検出リクエストを作成
let faceRequest = VNDetectFaceRectanglesRequest { request, error in
    guard let observations = request.results as? [VNFaceObservation] else {
        return
    }
    
    // 検出された顔の位置を保存
    let facePositions = observations.map { observation in
        // 正規化座標（0.0〜1.0）で返される
        return CGPoint(
            x: observation.boundingBox.midX,
            y: observation.boundingBox.midY
        )
    }
    
    // 各人物領域の中心と顔の位置を比較して、最も近い人物を特定
    // detectMultiplePersonsの結果と組み合わせる
}
```

### 2. 人物領域と顔の位置をマッチング
```swift
func matchPersonToFace(persons: [DetectedPerson], facePositions: [CGPoint]) -> [DetectedPerson] {
    var matchedPersons: [DetectedPerson] = []
    
    for person in persons {
        let personCenter = CGPoint(
            x: person.boundingBox.midX,
            y: person.boundingBox.midY
        )
        
        // 最も近い顔を探す
        var minDistance = CGFloat.greatestFiniteMagnitude
        var closestFace: CGPoint?
        
        for facePosition in facePositions {
            let distance = sqrt(
                pow(personCenter.x - facePosition.x, 2) +
                pow(personCenter.y - facePosition.y, 2)
            )
            
            if distance < minDistance {
                minDistance = distance
                closestFace = facePosition
            }
        }
        
        // 距離が近い場合（例: 0.1以内）のみ人物として扱う
        if minDistance < 0.1 {
            matchedPersons.append(person)
        }
    }
    
    return matchedPersons
}
```

### 3. ユーザーが顔をタップして選択
```swift
// タップ位置から最も近い顔を特定
func selectPersonByFace(at location: CGPoint, facePositions: [CGPoint]) -> Int? {
    // タップ位置を正規化座標に変換
    let normalizedLocation = CGPoint(
        x: location.x / imageSize.width,
        y: location.y / imageSize.height
    )
    
    // 最も近い顔を探す
    var minDistance = CGFloat.greatestFiniteMagnitude
    var selectedFaceIndex: Int?
    
    for (index, facePosition) in facePositions.enumerated() {
        let distance = sqrt(
            pow(normalizedLocation.x - facePosition.x, 2) +
            pow(normalizedLocation.y - facePosition.y, 2)
        )
        
        if distance < minDistance {
            minDistance = distance
            selectedFaceIndex = index
        }
    }
    
    return selectedFaceIndex
}
```

## メリット
- 顔の位置を正確に特定できる
- 複数の人物が近接していても、顔で区別できる
- Vision Frameworkの標準APIなので、追加のモデル不要

## デメリット
- 顔が写っていない人物は選択できない
- 横顔や後ろ向きの場合は精度が下がる可能性がある

