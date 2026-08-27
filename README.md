# MMDAnimationStudio

表示名は「MMDアニメーションスタジオ」。MMDを利用したアニメーション制作機能を統合する製品側プロジェクトです。

## 配置

- AviUtl2プラグイン境界と製品固有コードは、このリポジトリに置きます。
- PMX、姿勢計算、編集GUI、D3Dプレビュー、AI用MMD処理は`..\AviUtl2PluginLib\MMD`を直接参照します。
- 共通MMDコードをこのリポジトリへ複製しません。
- ユーザーのPMXモデルとビルド成果物はGitへ追加しません。

`MMDAnimationStudioGroup.groupproj`から、本命の拡張プラグイン、Modelプラグイン、Poseプラグインをまとめて開けます。

## プロジェクト

- `MMDAnimationStudio.dproj`: 本命となるAviUtl2拡張プラグイン。表示名は「MMDアニメーションスタジオ」、プラグイングループは`MMD`
- `MMD_Model_Filter.dproj`: AviUtl2 Modelプラグイン（Named Pipeなし）
- `MMD_Pose_Filter.dproj`: AviUtl2 Poseプラグイン（Named Pipeなし）
- `Source\Plugin\Extension`: 拡張プラグインの登録処理とクライアントフォーム
- `Source\AI`: 既存のAIプレビュー関連コード。現在は本命拡張プラグインへ未接続
- `Poses`: Git同期するポーズJSON。新規AI候補は重複名を回避し、選択後の微調整は自動保存する

Debug / Releaseとも、拡張プラグインは`C:\ProgramData\aviutl2\Plugin\MMD\MMDAnimationStudio.aux2`へ配置します。
