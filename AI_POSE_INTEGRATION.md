# Codexポーズ連携

Codexはアプリから指示を受け取らない。ユーザーがCodexでポーズを指示し、Codexが起動中のMMDAnimationStudioへローカルNamed Pipe経由でJSONを渡す。

通信先は`MMD.AI.Preview.v1`、形式はUTF-8 NDJSONである。PowerShellからはJSONの引用符崩れを避けるため、`MMDAIPreview.exe --pipe-request-file <JSONファイル>`を使う。

## Codex MCP

プロジェクトの`.codex/config.toml`は`MMDAIPreview.exe --mcp`をSTDIO MCPサーバーとして登録する。新しいCodexタスク、またはMCP設定の再読込後は、次の6ツールをJSONファイルなしで利用できる。

- `get_pose_catalog_context`
- `get_active_pose_context`
- `get_model_schema`
- `preview_pose`
- `preview_pose_in_session`
- `create_pose_file`

`create_pose_file`だけは永続ファイルとカタログを書き換えるため、プロジェクト設定で書込み承認対象にしている。MCPはJSON-RPC 2.0のSTDIO変換だけを担当し、姿勢処理とカタログ操作の正本は既存Named Pipe側に置く。

## バックグラウンドでポーズを作る

1. AviUtl2でMMDAnimationStudioを開き、登録先PMXを選ぶ。
2. `get_pose_catalog_context`で`pmx_id`と`model_file`を取得する。
3. `get_model_schema`と`preview_pose`で、そのモデル用の完全な`pose_data`を作る。
4. `create_pose_file`へ名前と`pose_data`を渡す。

```json
{
  "operation": "create_pose_file",
  "pose_name": "右手を上げた挨拶",
  "pose_data": "{\"version\":1,\"bones\":[]}"
}
```

成功すると、共通VPDフォルダへ重複しないファイル名で保存し、選択PMX用のPoseUIDへ登録する。PMX管理とポーズの一覧が開いていれば直ちに再読込し、新しいポーズを選択する。`pmx_id`または`model_file`を明示すれば、画面選択ではなく指定モデルへ登録できる。

ポーズ設定画面が開いている間は、その画面が持つ編集中の古い一覧で登録結果を上書きしないよう、`create_pose_file`を拒否する。この場合は次のライブ編集を使う。

## 開いているポーズ設定へ候補を反映する

1. PMX管理またはポーズ一覧から設定画面を開く。
2. `get_active_pose_context`で`session_id`、`model_file`、現在の`pose_data`、`revision`を取得する。
3. 現在姿勢を基に完全な候補を作り、`preview_pose_in_session`へ渡す。

```json
{
  "operation": "preview_pose_in_session",
  "session_id": "get_active_pose_contextで得た値",
  "base_revision": 1,
  "candidate_id": "greeting-2",
  "pose_name": "挨拶 修正2",
  "pose_data": "{\"version\":1,\"bones\":[]}"
}
```

候補は既存の3D編集画面へ即時反映され、通常、ボーンのみ、通常＋ボーンを切り替えられる。AI適用前の姿勢はUndo履歴へ入るため、ユーザーは通常のボーン操作で修正し、さらにCodexへ修正を依頼できる。手動編集で`revision`が変わった後に古いAI応答が届いた場合は`pose_revision_changed`として拒否する。画面を閉じる操作で既存どおり確定・保存する。

## CLI例

```powershell
D:\DelphiProg\AviUtl2Plugin\MMDAnimationStudio\MMDAIPreview.exe --pipe-request-file D:\work\mmd-pose-request.json
```

`--request-file`はMMDAIPreview自身で処理する。起動中MMDAnimationStudioの選択状態や編集画面を操作するときは`--pipe-request-file`を使う。

MCPサーバーを単体で確認する場合は`MMDAIPreview.exe --mcp`を起動し、1行1件のJSON-RPC要求を標準入力へ渡す。通常はCodexが自動起動するため、ユーザーが直接実行する必要はない。
