# 共通GUIライブラリ

複数画面から再利用するGUI部品の所在と選定基準を記録する。
新しい画面で同種の部品が必要になった場合は、個別実装の前にこの一覧を確認する。

## 横型トラックバー

- ユニット: `HorizontalTrackBarControl`
- クラス: `THorizontalTrackBarControl`
- ソース: `..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas`
- 現在の利用先: 単独の数値入力GUI。モーフ一覧は仮想行描画のため、描画部だけを利用する。
- 対応環境: Delphi 37.0 / VCL / Win64 / DPIスケーリング

Windows標準の`TTrackBar`は使用せず、背景、チャンネル、到達部分、目盛り、つまみ、
フォーカスをすべてVCL Canvasで描画する。テーマに依存せず、明色・暗色どちらにも
合わせられる。

主な機能:

- `Minimum`、`Maximum`、`Position`による整数範囲
- `SmallChange`単位への値の丸め
- `LargeChange`によるPageUp／PageDown移動
- `Frequency`間隔の目盛りと`ShowTicks`
- クリック、ドラッグ、矢印キー、Home／End、PageUp／PageDown、マウスホイール
- 値が実際に変わった場合だけ`OnChange`を通知
- 有効／無効状態、フォーカス、DPIに応じた独自描画
- 背景、チャンネル、到達部分、つまみ、枠、目盛り、無効色を個別指定可能

基本的な使用例:

```pascal
uses
  HorizontalTrackBarControl;

Track := THorizontalTrackBarControl.Create(Owner);
Track.Parent := ParentControl;
Track.SetBounds(8, 8, 220, 40);
Track.SetRange(0, 100);
Track.SmallChange := 1;
Track.LargeChange := 10;
Track.Frequency := 10;
Track.Position := 50;
Track.OnChange := TrackChanged;
```

ダーク配色で使用する場合:

```pascal
Track.BackgroundColor := TColor($001E1E1E);
Track.ChannelColor := TColor($00505050);
Track.FillColor := TColor($00FF6666);
Track.ThumbColor := TColor($003A3A3A);
Track.ThumbBorderColor := TColor($00DCDCDC);
Track.TickColor := TColor($00808080);
Track.DisabledColor := TColor($00808080);
```

プロジェクトへ追加する際は、DPRまたはDPROJに次のソースを登録する。

```text
..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas
```

## 類似部品との使い分け

- 任意の数値を選ぶ横型スライダー: `THorizontalTrackBarControl`
- コンテンツの表示位置を動かす横スクロールバー: `THorizontalScrollBarControl`
- 数値表示・直接入力付きの縦型スライダー: `TVerticalSliderControl`
- 透明度専用の複合UI: `TTransparencyTrackControl`

単なる数値選択にWindows標準`TTrackBar`を新規使用せず、原則として
`THorizontalTrackBarControl`を使う。

## モーフ設定一覧

- 入力と状態管理: `MmdMorphSettingList`
- 分類行モデル: `MmdMorphSettingRows`
- 行描画: `MmdMorphSettingListRenderer`
- 端吸着と2値規則: `MmdMorphSettingValue`
- 見出しとプレビュー通知: `MmdMorphPreviewPanel`
- 名前付き初期表情JSON: `MmdMorphSettingCodec`
- ポーズ・表情の共通設定フォーム: `MmdModelSettingEditor`
- 共通設定フォームのアイコン: `MmdModelSettingEditorIcons`
- 単一目パチモーフと閉眼時ウェイトのUI: `MmdEyeBlinkSettingPanel`
- 目パチ設定の版付きJSON: `MmdEyeBlinkSettingCodec`

モーフ数に比例してVCLコントロールを生成せず、表示中の行だけをCanvasへ描画する。
PMXのモーフ順を維持し、`Panel`値が変わる位置へ眉、目、リップ、その他、未分類の
見出し行を挿入する。ウェイト配列と連続値／2値方式はPMXのモーフ番号順で保持するため、
見出し行を追加してもモデル側の番号は変化しない。

`SetWeights`で保存済みウェイトを一覧へ復元できる。永続化では
`MmdMorphSettingCodec`を使い、モーフ名と非ゼロウェイトだけを版付きJSONへ保存する。

モデル表示の`設定`ボタンとPMX管理の初期状態ダブルクリックは、どちらも
`EditMmdModelSettings`を呼ぶ。既定ではフォーム上端にポーズと表情の2アイコンだけを表示する。初期状態編集は末尾の`ShowAllPages=True`を渡し、目パチと口パクを含む全4アイコンを表示する。

初期状態の全データを扱う場合は`EditMmdInitialStateSettings`を呼ぶ。目パチはモーフ、閉眼ウェイト、間隔、速度、オフセットを、口パクは開閉と6音素のモーフ割当、内部ウェイト、速度、強さをそれぞれ版付きJSONで受け渡す。

`TryBuildPmxPoseObjectAlias`と`TryWritePmxPoseObjectAlias`には、ポーズ、初期表情、初期目パチ、初期口パクの順でJSONを渡す。目パチと口パクのJSONはモデル表示の各データ項目へ、時間設定や強さは対応する数値パラメーターへ展開される。

モデル表示の目パチ時間計算は`MMD_Model_EyeBlink`を使う。`TMmdEyeBlinkRuntimeState`は必ずモデル表示のオブジェクト別コンテキストに保持し、共有してはならない。`CalculateMmdEyeBlinkAmount`はオブジェクト相対フレーム、FPS、間隔、速度、オフセット、安定シードから0～1の閉眼量を返す。

縦スクロールには`TVerticalScrollBarControl`を使う。ホイールは一覧スクロール専用とし、
トラック操作はクリックとドラッグだけで行う。左右端の近傍は0または1へ吸着する。
