# MMD AI Preview Named Pipe

## 接続

- Pipe短縮名: `MMD.AI.Preview.v1`
- 完全名: `\\.\pipe\MMD.AI.Preview.v1`
- 文字コード: UTF-8（BOMなし）
- フレーミング: 1行1JSONのNDJSON
- 最大要求サイズ: 4 MiB
- 接続中は複数要求を連続送信でき、切断後は新しいクライアントを待ち受ける。

GUIを通常起動するとサーバーも自動起動する。画面を使わずサーバーだけを起動する場合は次のコマンドを使う。

```powershell
D:\DelphiProg\test\MMDAIPreview\MMDAIPreview.exe --pipe
```

## 要求と応答

Pipeは既存のMMDAIPreview JSON操作をそのまま受ける。`request_id`は任意だが、指定した場合は対応する応答へ同じJSON値を返す。

```json
{"request_id":"cap-1","operation":"get_capabilities"}
```

中心となるボーン操作は`get_model_schema`と`preview_pose`である。姿勢形式はMMD共通の`mmd.pose`バージョン1を使用し、Pipe独自形式は作らない。`preview_pose`成功時は正規化済み`pose_data`と解決済みボーン情報を返す。

## 3D確認画面への提示

Codex側で画像評価と調整を終えた候補は`present_pose`でGUIへ提示する。GUI版の`MMDAIPreview.exe`が起動している必要がある。

```json
{
  "request_id": "present-1",
  "operation": "present_pose",
  "candidate_id": "optional-candidate-id",
  "pose_name": "万歳",
  "model_file": "D:\\Models\\character.pmx",
  "current_pose": "",
  "payload": {
    "mode": "replace",
    "bones": [
      {"name": "左腕", "rotation_euler_degrees": [0, 8, 75]},
      {"name": "右腕", "rotation_euler_degrees": [0, -8, -75]}
    ]
  }
}
```

`present_pose`は先にMMD共通プロバイダーで正規化とボーン解決を行い、成功した`pose_data`をプロジェクト直下の`Poses`へJSON保存してから画面へ渡す。成功応答の`pose_file`には作成したファイルの絶対パスを返す。同名時は`-2`、`-3`の連番を付け、既存ファイルを上書きしない。`model_file`は任意で、省略時は標準MMDボーン名を持つ仮骨格で検証・表示する。

画面左側には`Poses`内のJSONファイル名を更新日時の新しい順で表示する。選択したファイルを直ちにプレビューへ反映し、起動時は最新ファイルを自動選択する。この最新項目がCodexからの指示結果の初期プレビューとなる。「ポーズを開く」と「保存」の各ボタンは設けない。画面では通常、ボーンのみ、通常＋ボーンを切り替えられる。

正規化済みの`mmd.pose`バージョン1を再提示する場合は、`payload`の代わりに`pose_data`文字列を直接指定できる。この経路はJSON形式の検証とQuaternion再正規化を行うが、`model_file`があってもモデル固有ボーンの存在確認は行わず、応答の`preview.model_validation`は`false`となる。

```json
{
  "operation": "present_pose",
  "pose_name": "保存済みポーズ",
  "pose_data": "{\"version\":1,\"bones\":[...]}"
}
```

GUIが開いていない場合は`preview_ui_unavailable`、別候補の提示処理中は同じコードと説明文を返す。

## PowerShell接続例

```powershell
$pipe = [System.IO.Pipes.NamedPipeClientStream]::new(
  '.',
  'MMD.AI.Preview.v1',
  [System.IO.Pipes.PipeDirection]::InOut)
$pipe.Connect(5000)
$utf8 = [System.Text.UTF8Encoding]::new($false)
$reader = [System.IO.StreamReader]::new($pipe, $utf8)
$writer = [System.IO.StreamWriter]::new($pipe, $utf8)
$writer.AutoFlush = $true
$writer.WriteLine('{"request_id":"cap-1","operation":"get_capabilities"}')
$response = $reader.ReadLine()
$writer.Dispose()
$reader.Dispose()
$pipe.Dispose()
```

標準出力・標準入力の`--stdio`はテストと障害調査用の予備経路として残す。
