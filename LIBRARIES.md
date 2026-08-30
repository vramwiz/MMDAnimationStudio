# 共通GUIライブラリ

複数画面から再利用するGUI部品の所在と選定基準を記録する。

## 共通ダークテーマ基盤

この基盤は2026-08-30時点で完成扱いとする。新しい標準VCL画面は以下の共通Controlを利用し、
画面ごとの配色・文字高・DPI計算を追加しない。`TListView`と独自描画UIは対象外とし、
今後の独自GUI系統で扱う。

- 配色: `..\AviUtl2PluginLib\Lib\DarkTheme\Core\DarkThemeColors.pas`
- 96 DPI基準寸法: `..\AviUtl2PluginLib\Lib\DarkTheme\Core\DarkThemeMetrics.pas`
- 画面内共有DPI: `..\AviUtl2PluginLib\Lib\DarkTheme\Core\DarkThemeDpiContext.pas`

VCL部品は1フォルダへ集積せず、基本表示を`VclControls\Basic`、文字入力を
`VclControls\Input`、選択操作を`VclControls\Selection`へ分ける。各フォルダは3ユニットとし、
新しい部品も責務に対応する下位フォルダへ追加する。
- 共通ボタン: `..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkButton.pas`
- 共通チェック一覧: `..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Selection\DarkCheckListBox.pas`
- 共通コンボ: `..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Input\DarkComboBox.pas`
- 共通単行入力: `..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Input\DarkEdit.pas`
- 共通複数行入力: `..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Input\DarkMemo.pas`
- 共通ラベル: `..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkLabel.pas`
- 共通一覧: `..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Selection\DarkListBox.pas`
- 共通ツリー: `..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Selection\DarkTreeView.pas`
- 共通パネル: `..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkPanel.pas`

`TDarkThemeDpiContext`をフォームまたはルートフレームごとに1個作成し、同じ画面の
`TDarkButton`へ渡す。DPIを変更すると登録済みボタンへ一括通知され、文字高、ボタン高、
境界幅、余白を同じ丸め規則で更新する。`TDarkButton`はマウス、Enter／Space、フォーカス、
Default／Cancel、ModalResultに対応する。

`TDarkPanel`は`TPanel`を一段継承し、背景、文字色、枠を共通テーマへ揃える。
`DesignHeight`へ96 DPI基準の高さを指定すると、共有DPI変更時に同じ丸め規則で高さを更新する。

`TDarkLabel`は`TLabel`を一段継承し、通常／無効文字色、基準文字高、任意の固定高さを
共通化する。`DesignFontHeight`と`DesignHeight`は96 DPI基準で指定し、同じ画面の
`TDarkThemeDpiContext`から一括反映する。最初の移行先はMMDモーフ設定一覧の見出しとした。

`TDarkEdit`は`TEdit`を一段継承し、通常／フォーカス／無効状態の背景、文字、枠、
テキスト内側余白、基準文字高、基準高さを共通化する。TEdit互換のため既存の入力検証や
`OnExit`処理をそのまま利用できる。最初の移行先は目パチ設定3項目と口パク設定2項目とした。

`TDarkMemo`は`TMemo`を一段継承し、入力色、フォーカス、無効状態、基準文字高を共通化する。
複数行の高さは既存レイアウトへ任せるため既定では固定せず、必要な画面だけ`DesignHeight`を指定する。
最初の移行先はVOICEVOXの通常セリフ入力欄2種とし、独自ズームとWindowProcを持つシーン一覧内編集は保留する。

`TDarkComboBox`は`TComboBox`を一段継承し、選択欄、候補一覧、矢印、フォーカス、
無効表示、基準文字高と項目高を共通化する。MMD専用の旧`TMmdDarkComboBox`は互換派生名として残し、
実装を共通コンボへ接続した。標準VCLからはセリフのシーン選択欄とボード解像度選択を移行した。
リスト内セル編集用コンボは編集プラグイン固有のサイズ・確定処理を持つため、この段階では置換しない。

`TDarkListBox`は`TListBox`を一段継承し、背景、通常／選択／無効文字、フォーカス、
基準文字高と項目高を共通化する。MMD専用の旧`TMmdDarkListBox`は互換派生名として共通実装へ接続し、
ボードのスタイル一覧とセリフ・エイリアスのレイヤー一覧を標準VCLから移行した。
チェック付き一覧、セル編集一覧、画像一覧等の派生クラスは機能境界が異なるため個別段階で扱う。

`TDarkCheckListBox`は`TCheckListBox`を一段継承し、チェック状態と操作をVCLへ委譲したまま、
一覧配色、文字高、項目高とDPIを共通化する。MMDの旧`TMmdDarkCheckListBox`は互換名として接続する。
MMDの一覧2種はフォーム側で調整済みのフォントを継承し、共通部品による文字DPIの再適用を行わない。

`TDarkTreeView`は`TTreeView`を一段継承し、背景、文字、接続線、文字高、項目高、インデントとDPIを
共通化する。ノード、画像リスト、展開、編集等は標準VCLのまま利用する。共有`TFolderSelect`の内部
ツリーを置き換えたため、Explorerを含むフォルダツリーは画面ごとのテーマ処理を持たない。

`TDarkButton`、`TDarkPanel`、`TDarkLabel`、`TDarkEdit`、`TDarkMemo`はVCLの`ChangeScale`を受けた際にも共有DPIを
更新するため、異なるDPIのモニターへ移動した場合も同じ画面内で寸法を揃える。
埋込みフレームからDPIを取得する場合はVCLが管理する`CurrentPPI`を優先し、Windows側の
`GetDpiForWindow`による再拡大を避ける。

ランチャー登録画面と確認ダイアログを最初の移行対象とし、ボタンとパネルを共通化した。独自スクロールバー、
トラックバー、仮想一覧は標準VCLのテーマ派生部品ではないため、このフォルダへ移さない。
`TListView`とその派生一覧も将来の完全独自GUI化を前提とし、`TDarkListView`は作成しない。

## AviUtl2共通配色（互換API）

- ユニット: `AviUtl2StyleColors`
- ソース: `..\AviUtl2PluginLib\Lib\Style\AviUtl2StyleColors.pas`
- 利用先: Syncroh2、MMDAnimationStudio、共有ランチャー

旧Syncroh2側の配色を基準とし、背景、文字、選択、ツールバー、一覧の正本は`DarkThemeColors`とする。
`AviUtl2StyleColors`は未移行コード向けの互換定数を提供する。
各製品へ同名ユニットをコピーせず、DPR／DPROJから共有ソースを直接参照する。
音声ソフトの水色は当該ランチャーが起動・管理中、緑は外部起動を検出した状態を表す。

## 共有Explorer

- 画面: `..\AviUtl2PluginLib\Explorer\ExplorerFrame.pas`
- AviUtl2境界: `..\AviUtl2PluginLib\Explorer\AviUtl\ExplorerAviUtlBridge.pas`
- エイリアス生成: `..\AviUtl2PluginLib\Explorer\AviUtl\ExplorerAliasBuilder.pas`

`TFrameExplorer`は画面、履歴、フォルダ監視、一覧、設定を共通実装として持つ。
フレーム時間と選択オブジェクト取得は呼出元が`SetExplorerAviUtlBridge`で登録し、
画像・音声D&Dは共有ビルダーでAviUtl2エイリアスを生成する。製品固有のPSD管理や
セリフ管理をExplorerへ依存させない。

## MMDポーズ編集の暗色テーマ

- 共通色、項目描画、タイトルバー: `MMD\Editor\MmdPoseEditorTheme.pas`
- 暗色ボタン: `MMD\Editor\Theme\MmdPoseEditorButtonTheme.pas`
- 暗色一覧／チェック一覧: `MMD\Editor\Theme\MmdPoseEditorListTheme.pas`
- 暗色コンボ: `MMD\Editor\Theme\MmdPoseEditorComboTheme.pas`

画面側は必要なControlのユニットだけを参照する。色を独自に複製せず、配色定数と
項目描画は基盤テーマを使う。チェック一覧はVCL標準のチェック操作を維持したまま、
本文と選択状態だけを共通配色で描画する。
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
