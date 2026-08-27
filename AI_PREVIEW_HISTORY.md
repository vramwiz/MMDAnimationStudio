# MMD AI Preview 作業ノート

作業再開時に最初に読む入口。このプロジェクトの目的、責任範囲、MMDとの共通事項、現在位置を記録する。

## 目的

CodexからMMDへ直接ポーズ候補を渡し、AviUtl2を起動せずにモデル固有の検証、画像評価、人間による3D確認、JSON保存までを一つのアプリで行うプロジェクトである。AI MIRAIには依存しない。

本プロジェクトは新しいMMD実装を一から作らない。PMX読込み、ボーン・IK計算、ポーズ正規化、スキニングは、隣接する`..\MMD`の共通ユニットを直接参照する。AI専用の画像生成や通信のために変更が必要なD3Dプレビューユニットは、本プロジェクトへコピーし、元ユニットと区別できる名前へ変更して改良してよい。

## 役割分担

- `MMDAIPreview`: Codexとの直接通信、モデルセッション、診断用カメラ、画像キャプチャを担当する。
- `MMD`: PMX、ボーン、IK、姿勢計算、スキニング、描画の正本を担当する。
- `Poses`: Codexが生成し、人間が3D確認できるGit同期可能なJSONポーズを保存する。

処理経路は`Codex -> Named Pipe -> MMDAIPreview -> MMD共通コア`とし、Codexの画像評価が完了した候補だけをGUIへ提示する。

## 共通データの規則

- 拡張名と姿勢形式は既存の`mmd.pose`バージョン1を正本とする。
- ボーンはPMX内の名前で指定し、回転はQuaternionまたは`rotation_euler_degrees`を使用する。
- MMDが返す正規化済み`pose_data`を、プレビューとAviUtl2適用の共通成果物とする。
- MMDAIPreview独自のボーン形式を作らない。
- モデル固有の解釈、存在しないボーンの拒否、最終ボーン位置計算はMMD共通側で行う。
- プレビュー用カメラや診断表示など、保存ポーズに含まれない状態は`pose_data`と分離する。
- PMX、姿勢、IKなど意味計算の正本はMMD側に一つだけ置き、コピーしない。
- D3D表示や画像出力のようにMMDAIPreview固有の責務を持つユニットはコピーして改良してよい。コピー時は元ファイル、コピー日、変更理由を本ノートへ記録し、ユニット名を変えて同名競合を避ける。
- 両プロジェクトへ同じ修正が必要になった場合は、コピー側だけへ重複実装せずMMD共通側へ戻す。

## 現在位置（2026-08-27）

- Delphi 37.0 / Win64コンソールアプリ`MMDAIPreview.exe`の最小プロジェクトを作成した。
- `..\MMD\Source\Lib\MMD`を参照し、既存の`MmdAiProvider`を同一プロセス内で直接呼ぶ。
- `--self-test`でプロバイダー能力を取得できる。
- `--request`と`--request-file`で単発JSON要求を処理できる。
- `--stdio`ではUTF-8の改行区切りJSONを連続処理する。1要求につき1行のJSON応答を返す。
- 現段階で利用できる中心機能は`get_capabilities`、`get_model_schema`、`preview_pose`である。
- Debug / ReleaseのWin64ビルドは警告0・エラー0で成功し、両方の`--self-test`が成功した。
- 実モデル「ふらすこ式風きりたん」で`Samples\banzai-preview.json`をAviUtl2なしで処理し、14ボーンの解決と正規化済み`pose_data`取得に成功した。頭Y約`15.00`、左右手首Y約`16.90`、手首X約`±4.46`で、AIMIRAI経由の確定時と同じ結果になった。
- `--stdio`へ同じ要求を渡し、`status=ok`、`operation=preview_pose`、`bone_count=14`の連続通信用応答を確認した。
- ホスト固有命令`capture_pose`を追加した。同じ要求内でMMDの`preview_pose`を実行し、その正規化済み`pose_data`を既存D3Dプレビューへ渡してBMPを保存する。
- D3D描画には非表示のWin32ウィンドウを使い、AviUtl2とAIMIRAIを起動しない。画像幅・高さは64～4096、出力先は絶対パスまたは省略時の一時フォルダーを使う。
- 固定視点は`front`、`back`、`side`、`opposite_side`、`top`、`bottom`に加え、斜め45度の`front_left_3q`、`front_right_3q`に対応する。
- `capture.focus`へ`all`、`left_hand`、`right_hand`、`hands`を追加した。手対象では最終姿勢の手首・手捩・五指ボーンを抽出し、選択範囲が中央へ収まるようカメラのズームとパンを自動計算する。
- `finger_id`と片手フォーカスを組み合わせた場合は、対象側の手首または指ボーンへウェイトを持つ面だけを描く。頭、胴体、反対側の手を一時的に除外するため、側面でも五指の前後関係を確認しやすい。
- ホスト固有命令`capture_pose_set`を追加した。`views`、`passes`、`focuses`の直積を一要求で生成し、指定ディレクトリへ規則的なファイル名で保存する。
- 一回の画像生成では最終ポーズから変形済み頂点範囲を計算するため、`auto_fit=true`として全身を収める。確定済み「万歳」の正面1024×1024で、AviUtl2では切れていた頭頂、両手、足先がすべて画像内へ収まった。
- 「万歳」の正面、背面、両側面を同じ`--stdio`セッションで連続生成し、全画像でテクスチャ18枚の読込み、全身表示、固定視点の切替を確認した。
- `capture.pass`へ`normal`、`bones`、`bone_overlay`、`silhouette`、`finger_id`、`body_only`を追加し、「万歳」の正面で全6表示をAviUtl2なしに連続生成した。
- `bones`と`bone_overlay`はMMD共通の最終ボーン計算とD3Dプレビューの投影式を使い、モデル本人基準の左を青、右を赤、中央を黄として描く。応答へ同じ凡例を返す。
- `silhouette`は通常テクスチャを除外して淡青色、`body_only`は衣服材質を除外して桃色、`finger_id`は身体材質だけを残し、親指赤、人差指黄、中指緑、薬指青、小指紫、その他灰、右側明度65%で描く。
- `MmdAiDiagnosticModel.pas`は、2026-08-27時点のMMD側`MMD_Model_DiagnosticRenderer.pas`にある材質名・指ボーン分類規則を基に、D3D用一時モデルへ組み直したMMDAIPreview専用ユニットである。MMD本体の意味計算はコピーしていない。
- `MmdAiDiagnosticOverlay.pas`は、MMD共通の最終ボーン位置と`MmdD3DScene`の投影を利用するMMDAIPreview専用ユニットである。
- 全6表示についてDebug / Releaseの768×768 BMPが表示種別ごとにSHA-256一致し、正規化結果、固定カメラ、自動フィット、診断色がビルド構成に依存しないことを確認した。診断モデルは通常テクスチャを読み込まず、`loaded_texture_count=0`となる。
- 「万歳」で全身・左右手、正面・両側面・左右3/4、通常・指ID・ボーン重ねの計45枚を`capture_pose_set`から生成し、応答45件、BMP 45件、空ファイル0件を確認した。片手側面の`finger_id`では頭部等が除外され、親指から小指までの5色と手のひらだけを独立表示できた。
- 左手側面の手指拡大BMPはDebug / ReleaseでSHA-256 `B34A53E47E9E2DF17CC2EB37A454820089AA8D5209FC833089A4704F341E4DF9`が一致した。
- ホスト固有命令`validate_finger_id`を追加した。左右の手指拡大BMPを画素分類し、親指、人差指、中指、薬指、小指の5色について画素数とピーク明度を返す。右/左のピーク明度比が各色とも`0.50～0.82`に収まることも検査する。
- 「万歳」の左手`side`と右手`opposite_side`を組み合わせた機械検査に成功した。左右とも5色すべてを検出し、右/左の平均ピーク明度比は約`0.699`、各色の比は約`0.671～0.714`となり、右側65%指定が描画画像へ反映されていることを確認した。
- Aul2MIRAIの通信スレッドとJSONディスパッチの構成を参考に、専用Named Pipe`MMD.AI.Preview.v1`を追加した。UTF-8 NDJSONを同一接続で連続処理し、切断後は再接続を待ち受ける。要求は最大4 MiBで、任意の`request_id`を応答へ引き継ぐ。
- Named Pipeから同一接続で能力照会、実モデル「万歳」の14ボーン正規化、不正JSONの拒否、約200 KiB要求を連続処理し、切断直後の再接続にも成功した。Aul2MIRAI、AviUtl2、選択状態、Undoには依存しない。
- 4 MiBを超えるNDJSON要求は改行まで安全に破棄して`request_too_large`を返し、同じ接続の次要求と切断後の再接続を継続できることを確認した。
- 引数なし起動でVCLの3D確認画面を開く。GUIと同時にNamed Pipeサーバーを起動し、`present_pose`で受けた完成候補を読み取り専用のPMXプレビューへ表示する。
- GUIはPMXを個別に開ける。最後に開いたPMXの絶対パスを`%LOCALAPPDATA%\MMDAIPreview\settings.json`へ記録し、次回起動時に再読込みする。
- 表示は「通常」「ボーンのみ」「通常＋ボーン」を切り替えられる。ボーンはキャラクター基準の左を青、右を赤、中央を黄で描き、指を含む全ボーンの位置関係を人間とCodexで共有しやすくした。
- GUIの「ポーズを開く」と「保存」を廃止し、左側へプロジェクト直下の`Poses`にあるJSONファイル名を更新日時の新しい順で表示する。選択すると直ちにプレビューへ反映し、起動時は最新ファイルを自動選択する。
- `present_pose`は正規化済みポーズを`Poses`へJSON保存してからGUIへ提示し、応答の`pose_file`へ作成先を返す。同名時は`-2`、`-3`を付け、既存ファイルを上書きしない。PMX絶対パスは保存データへ含めない。
- 実モデル「ふらすこ式風きりたん」と万歳候補をNamed Pipeの`present_pose`で提示し、通常、ボーンのみ、通常＋ボーンの3表示を実画面で確認した。旧GUI保存では連番化と同一`pose_data`を確認済みで、現在は同じ上書き防止処理を`present_pose`時の自動保存へ移した。
- 新しい一覧方式で「右手を上げた挨拶」をNamed Pipeから提示し、JSONの先行作成、一覧先頭への追加・選択、アプリ再起動後の最新JSON自動選択を確認した。
- DFMなしの`CreateNew`ではVCLのメインフォーム生成フラグが設定されないため、フォーム自身の`ShowInTaskBar`を明示した。Named Pipe起動も初回表示時へ移して早期`Handle`生成を避け、所有者なしの`WS_EX_APPWINDOW`として通常アプリと同様にタスクバーから前面復帰・終了できるようにした。
- MMDAIPreviewのDebug / Release、および共有レンダラー変更後のMMD Model / Pose両プラグインのDebug / Releaseをすべて警告0・エラー0でビルドした。
- Delphi IDEのF9実行で外部ホストを要求しないよう、プロジェクト種別を`FrameworkType=VCL`、`AppType=Application`、`Borland.ProjectType=VCLApplication`へ変更し、Win64、Debug / Release構成、`UseLauncher=False`をIDE用メタデータへ明示した。引数なしではGUIを直接起動し、引数付きのCLIモードだけ既存コンソールへ接続する。GUI起動と`--self-test`の双方を確認済みである。
- IDE実行構成は`D:\DelphiProg\test\WRT2646\Client\WRT2646MonitorControlTest`を正本として組み直した。DPRが`Vcl.Forms`からメインフォームを直接生成し、フォーム型をinterfaceへ公開する。EXEはVCLプロジェクト標準どおりプロジェクト直下の`D:\DelphiProg\test\MMDAIPreview\MMDAIPreview.exe`へ出力し、DPROJへWin64構成とProjectOutputのDeployment情報を明示した。
- PMX未指定時は`MmdAiPlaceholderModel.pas`が標準的な全身・左右腕・脚・五指の仮骨格を生成する。仮モデルは保存用データへ混入せず、MMD共通の最終ボーン計算と同じ左右色で表示する。
- `present_pose`の`model_file`を任意化した。省略時もMMD共通プロバイダーのモデル直接指定APIで、Euler角、Quaternion、重複名、未知ボーンを検証して正規化する。`Samples\banzai-placeholder.json`の14ボーンをすべて解決し、万歳の仮骨格表示を確認した。
- `present_pose`へ正規化済み`pose_data`を直接渡す経路も追加した。保存済み万歳を同一Pipe接続で再提示し、再エンコード後の`pose_data`一致を確認した。この経路はモデル固有検証を行わないため、応答へ`model_validation=false`を返す。
- 仮骨格追加直後の`MmdAiPlaceholderModel.pas`にUTF-8 BOMがなく、日本語ボーン名が文字化けしていたためBOMを付与した。DPRと全PascalソースのBOMを再検査し、古いDCUを削除するRebuild後も警告0・エラー0を確認した。
- `Learning\MMD_POSE_LEARNING.md`へAul2MIRAI側の既存学習記録をコピーし、以後の学習記録の正本を本プロジェクトへ移した。`Learning\confirmed-poses.json`には、会釈、通常のお辞儀、深いお辞儀、背を反らす（腰に手）、威張る、万歳の確定ボーン情報を機械可読形式で保存した。全6件をMMD共通プロバイダーへ再入力し、18、18、18、13、13、14ボーンとしてすべて正常解決した。
- AviUtl2、AIMIRAI、選択オブジェクト、`state_token`には依存しない。
- 仮骨格は標準MMDボーン名と概略比率を使うため、モデル独自ボーンの最終確認には実際のPMXを開く必要がある。

## コマンド

Debug Win64ビルド:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\MMDAIPreview\MMDAIPreview.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

能力照会:

```powershell
D:\DelphiProg\test\MMDAIPreview\MMDAIPreview.exe --self-test
```

単発要求:

```powershell
D:\DelphiProg\test\MMDAIPreview\MMDAIPreview.exe --request-file request.json
```

確認済みの「万歳」画像生成要求は`Samples\banzai-preview.json`に置く。これはMMD共通形式の動作確認用であり、独自ボーン形式のテンプレートではない。`capture.file_path`を省略すると一時BMPの絶対パスが応答の`image.file_path`へ返る。

`capture_pose`の`capture`は次の項目を受け取る。

| 項目 | 内容 |
| --- | --- |
| `width` | 画像幅。64～4096、省略時1024。 |
| `height` | 画像高。64～4096、省略時1024。 |
| `view` | `front`、`back`、`side`、`opposite_side`、`top`、`bottom`、`front_left_3q`、`front_right_3q`。省略時`front`。 |
| `pass` | `normal`、`bones`、`bone_overlay`、`silhouette`、`finger_id`、`body_only`。省略時`normal`。 |
| `focus` | `all`、`left_hand`、`right_hand`、`hands`。省略時`all`。手対象は最終ボーン位置から自動拡大する。 |
| `file_path` | BMPの絶対パス。省略時はユーザー一時フォルダーの`MMDAIPreview`へ生成する。 |

成功応答は正規化済み`pose_data`、MMDのプレビュー結果、`image.file_path`、寸法、視点、`auto_fit`、読込みテクスチャ数、ファイルサイズを返す。

斜め視点には`front_left_3q`と`front_right_3q`も指定できる。`finger_id`と`left_hand`または`right_hand`を組み合わせると、対象外の身体メッシュを一時的に描かない。

複数画像の一括生成には`operation`を`capture_pose_set`とし、`capture.file_path`の代わりに次を指定する。

| 項目 | 内容 |
| --- | --- |
| `output_directory` | 必須の絶対出力ディレクトリ。 |
| `file_prefix` | ファイル名の接頭辞。省略時`pose`。 |
| `views` | 視点名の配列。省略時`["front"]`。 |
| `passes` | 表示種別の配列。省略時`["normal"]`。 |
| `focuses` | 注目対象の配列。省略時`["all"]`。 |

ファイル名は`<prefix>-<focus>-<view>-<pass>.bmp`となる。確認済み要求は`Samples\banzai-diagnostic-set.json`に置く。

指ID画像の機械検査には`operation`を`validate_finger_id`とし、キャラクター左手のBMPを`left_file`、右手のBMPを`right_file`へ絶対パスで指定する。照明条件を揃えるため、`side`と`opposite_side`のように左右対称の視点を組み合わせる。成功応答の`passed`は、同じ画像寸法、左右それぞれの5色検出、右側の明度低下がすべて成立した場合に`true`となる。確認済み要求は`Samples\validate-finger-id.json`に置く。

継続セッション:

```powershell
D:\DelphiProg\test\MMDAIPreview\MMDAIPreview.exe --stdio
```

`--stdio`のJSONは1行で完結させる。標準出力には機械可読JSONだけを返し、診断ログは将来追加する場合も標準エラーへ分離する。

Named Pipeサーバー:

```powershell
D:\DelphiProg\test\MMDAIPreview\MMDAIPreview.exe --pipe
```

通信仕様とPowerShell接続例は`PIPE_INTERFACE.md`を正本とする。

## 次の作業

1. GUIの表示状態をPipeから取得できる`get_ui_state`を追加し、Codexが現在のPMX、候補、表示方式を確認できるようにする。
2. 保存完了をPipeへ通知または照会できるようにし、Codex側が人間による確定を識別できるようにする。
3. 背景色指定と、任意の選択ボーン範囲を対象とする自動フィットを追加する。

## 必須条件

- Delphi 37.0、Win64のみを対象とし、Debug / Releaseを警告0・エラー0で確認する。
- DelphiプロジェクトとPascalソースはUTF-8 BOM付きで保存する。
- MMD共通コードへ変更を加える場合は、Model / Poseプラグイン双方への影響を確認する。
- Filter、GUI、通信境界からDelphi例外を漏らさない。
- モデルファイルをプロジェクトへコピーせず、絶対パスで参照する。
- 画像評価用の一時状態をモデルの保存ポーズへ混入させない。
- MMDAIPreviewからAviUtl2のプロジェクト状態を変更しない。
