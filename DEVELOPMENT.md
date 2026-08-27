# MMD 開発・運用ルール

`SYNC_Lyrics` のうち、このプロジェクトでも共通して適用するルールを移植したもの。

## 安全性・性能ルール

- グローバルな可変状態を避け、AviUtl2からの並列呼び出しを前提に共有キャッシュを設計する。
- FilterとGUIの各コールバック境界からDelphi例外を外へ漏らさない。
- ファイル不存在、未知形式、破損、解析失敗によってAviUtl2を停止・終了させない。
- 毎フレームの処理ではファイル再読込、不要なメモリ確保、GUI値の書き戻しを行わない。
- 同じモデルを複数オブジェクトが参照する場合は、解析結果を読み取り専用キャッシュとして共有する。
- ファイル異常時の表示とフォールバック動作は実装前に確定する。

## 共通ビルドルール

- Delphi 37.0を使用し、対象プラットフォームはWin64だけとする。
- DebugとReleaseの両構成を検証する。
- コンパイル警告とエラーを確認し、原則として警告0、エラー0で完了とする。
- Debugは生成した `.dll` と `.rsm` を調査用に残し、`.auf2` も作る。
- Releaseは `.auf2` を作った後、同じ出力先の `.dll` と `.rsm` を削除する。
- ビルド成果物とIDEローカル設定はGitへ登録しない。

## 拡張プラグインのユーザーデータ

- `SetAppFolderRoot('MMDAnimationStudio')`で製品ルートを決め、機能別データはその下位フォルダへ分離する。
- PMX表示順は`PMX\Catalog.json`、モデル情報は`PMX\Models\<PmxUID>\Model.json`へUTF-8 JSONで保存する。旧`PMX\PmxCatalog.txt`は自動移行対象とする。
- 一覧の識別には正規化した絶対パスを使い、表示名にはパスと拡張子を含めない。
- PMXごとのポーズ表示順と初期ポーズIDは`Poses\Index.json`、ポーズ本体は`Poses\Items\<PoseUID>.json`へ分ける。ポーズ本体の`poseData`はJSON文字列へ二重符号化せず、版付きJSONオブジェクトとして保存する。0件の場合は`{"version":1,"bones":[]}`の「初期状態」を自動生成する。
- 正面サムネイルは`PMX\Cache\Model`、ポーズ適用画像は`PMX\Cache\Pose`へPNGで保存する。PMXとポーズの更新状態および表示寸法を含むキーで再利用可否を判定する。
- サムネイル生成はUIスレッドのタイマーで1件ずつ行い、一覧の`Paint`から直接PMXを読み込まない。

## ソース構成とユニット規模

- `..\AviUtl2PluginLib\MMD`直下へユニットを集積しない。形式固有コードは`PMX`、`VMD`、`VPD`等の形式別フォルダを第一階層とし、その下を`Model`、`IO`、`Editor`等の責務で分ける。
- 複数形式にまたがるMMD共通コードは`MMD\Common`、プロセス間連携は`MMD\IPC`、AI境界は`MMD\AI`のように、形式固有コードと分離する。
- 製品側の形式固有コードも、例えば`Source\Plugin\Extension\PMX\Catalog`のように、機能と責務で下位フォルダへ分ける。同じフォルダへ関連ユニットを無制限に集積しない。
- Editor固有の描画実装は`Editor\D3D`のように技術境界でも分け、VCL接続、GPU資源管理、シーン頂点生成を同じユニットへ混在させない。
- Plugin固有コードも`Context`、`Input`、`Render`、`Editor`へ分け、Filter登録・フレーム統括ユニットに詳細実装を置かない。
- 1ユニットは原則400行未満を目安とする。超える前に、ファイル名ではなく変更理由とデータの流れが同じ責務で分割する。
- 新しい機能を追加する際は、既存の大きなユニットへ追記する前に独立した責務として分離できないか確認する。

## 形式名と命名規則

- MMDは製品・機能群の上位概念として使い、形式固有のデータ、ユニット、型には`Pmx`、`Vmd`、`Vpd`等の形式名を先頭へ付ける。
- 名前は左から「大分類→小分類→具体的責務」の順にする。一覧で関連ユニットがまとまるよう、`PmxCatalogItem`、`PmxCatalogStorage`、`PmxCatalogFrame`のように命名する。
- Delphiの識別子では`Pmx`、`Vmd`、`Vpd`のPascalCaseを使い、画面表示や拡張子の説明では`PMX`、`VMD`、`VPD`と表記する。
- `PMX`、`VMD`、`VPD`という名前は、その形式に準拠するデータと処理だけに使う。独自形式や複数形式の共通データは、互換性を誤認させないよう`Mmd`を先頭にする。
- 画面上の機能名は「PMX管理」とするが、内部責務には曖昧な`Manager`を多用せず、用途に応じて`Catalog`、`Repository`、`Storage`、`Reader`、`Writer`等を使い分ける。
- 既存の`MMD\Core`、`MMD\IO`等にある形式固有ユニットは一括移動せず、関連機能を変更する際に依存関係とプロジェクト参照を確認しながら段階的に形式別フォルダへ移す。

Debug Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\AviUtl2Plugin\MMDAnimationStudio\MMD_Model_Filter.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\AviUtl2Plugin\MMDAnimationStudio\MMD_Pose_Filter.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Release Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\AviUtl2Plugin\MMDAnimationStudio\MMD_Model_Filter.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\AviUtl2Plugin\MMDAnimationStudio\MMD_Pose_Filter.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

配備先:

```text
C:\ProgramData\aviutl2\Plugin\MMD\MMD_Model_Filter.auf2
C:\ProgramData\aviutl2\Plugin\MMD\MMD_Pose_Filter.auf2
```

## コメントルール

- コメントはコードだけでは分からない目的、責務、注意点、状態や値の意味を補うために書く。
- 古い仕様や現在の実装と食い違うコメントは、見つけた時点で更新する。
- 処理を日本語へ置き換えただけのコメントや重複コメントを増やさない。
- ユニット先頭には、そのユニットの目的と担当範囲を `//` で書く。
- `interface` の公開関数・手続きには、呼び出し側から見た責務、入出力、重要な副作用を書く。
- コメントと対象の宣言または実装の間に不要な空行を入れない。
- `var` ブロック内へローカル関数・手続きを置かない。
- `property`、`procedure`、`function` の宣言は、112文字以内なら折り返さない。
- 日本語文字列リテラルを持つ `.pas` と `.dpr` はUTF-8 BOM付きで保存する。
- SDKレコードはC/C++側のABIと一致させ、フィールド追加時は順序、型、アラインメントを公式SDKと照合する。

## Git運用ルール

- 同期対象は `.pas`、`.dpr`、`.dproj`、文書、検証に必要なスクリプトと素材とする。
- ビルド成果物、IDEローカル設定、履歴・復旧データは同期しない。
- `.gitattributes` でPascal、プロジェクト、文書の改行をCRLFへ統一する。
- `.res`、画像、AviUtl2プロジェクト等はbinaryとして扱う。
