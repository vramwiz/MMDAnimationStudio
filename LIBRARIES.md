# 共通GUIライブラリ

複数画面から再利用するGUI部品の所在と選定基準を記録する。
新しい画面で同種の部品が必要になった場合は、個別実装の前にこの一覧を確認する。

## 横型トラックバー

- ユニット: `HorizontalTrackBarControl`
- クラス: `THorizontalTrackBarControl`
- ソース: `..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas`
- 現在の利用先: `MmdMorphPreviewPanel.pas`のモーフ確認ウェイト
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
