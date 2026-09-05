# アーキテクチャ

## 全体方針

- 汎用3Dではなく、ボーンを利用するMMD専用Filterプラグイン群として設計する。
- MMD側でボーン、モーフ、スキニングを計算し、AviUtl2の`draw_poly()`へ3D頂点を渡す。
- カメラ、光源、最終3D描画はAviUtl2側を使用する。自前D3Dによる最終2D生成は行わない。
- D3D11は編集GUIのプレビューと、必要に応じた計算高速化に限定する。
- MMD内部縮尺はAviUtl2標準のオブジェクト拡大率と分離する。

## 責務と状態所有

### MMDアニメーションスタジオ拡張プラグイン

- `MMDAnimationStudio.dproj`を製品の本命プロジェクトとする。
- AviUtl2拡張プラグインとして「MMDアニメーションスタジオ」を登録する。
- `MMD`プラグイングループへ配置し、AviUtl2内に同名のクライアントウィンドウを持つ。
- VCLフォームへメインフレームを埋め込み、上部に「PMX管理／ポーズ・モーション／表情／セリフ／エクスプローラー／音楽／起動」の表示切替用ツールバーを置く。
- ツールバーは`Syncroh2_Extension2`と同じサイズ、配色、DPI対応線画アイコン生成方式を使い、対応するページを切り替える。
- PMX管理ページは`Source\Plugin\Extension\PMX\Catalog`の専用フレームで実装する。拡張ウィンドウのルートでファイルドロップを受け、`.pmx`をPMX管理、`.vpd`とVPDを含むフォルダを選択中PMXのポーズ登録へ振り分ける。
- 登録したPMXは正規化した絶対パスで識別し、Windowsのパスとして大文字・小文字を区別せず重複を拒否する。画面にはパスと拡張子を除いたファイル名だけを表示する。
- PMXカタログは`PMX\Catalog.json`に表示順のPmxUIDを保存し、各モデルのパスと表示名は`PMX\Models\<PmxUID>\Model.json`へ分離する。旧`PmxCatalog.txt`は初回読込時にこの構造へ移行する。
- PMX管理ページは左右の専用一覧で構成する。左はPMX名と標準姿勢の全身画像、右は選択PMXに属するポーズ名とポーズ適用後の全身画像を表示する。
- ポーズの順序と`defaultPoseId`は`Models\<PmxUID>\Poses\Index.json`、各データは`Poses\Items\<PoseUID>.json`で管理する。個別データはPoseUID、PmxUID、PMX表示名、ポーズ名、種別、版付き姿勢JSONを持つ。ポーズが0件なら正規の空姿勢JSONを持つ「初期状態」を自動生成し、右一覧には常に1件以上表示する。
- 右一覧のダブルクリックで共通MMDポーズ編集GUIを開く。画面を閉じた時点の姿勢を採用して個別JSONへ保存し、PoseUIDと更新後の姿勢データを含むキーで右サムネイルを再生成する。
- サムネイルは非表示の単一D3D描画面で1件ずつ生成し、一覧の描画処理内でPMX解析やGPU描画を行わない。骨格・選択オーバーレイは画像へ含めない。
- PNGキャッシュはモデル用`PMX\Cache\Model`とポーズ用`PMX\Cache\Pose`へ分離する。PMX更新状態、画像寸法、PoseUIDとポーズデータをキーにし、元データ更新時には旧画像を使用しない。
- PMX登録が0件の場合だけドロップ案内を表示し、1件以上ある場合は専用一覧だけを表示する。
- `Catalog\Storage`はPMX項目とモデルJSON codec、`Catalog\Pose\Storage`はポーズ項目・索引・個別JSON codec、`Catalog\Pose\Drag`は画像D&Dを担当する。フレームは配置と操作調停だけを持ち、永続化形式やドラッグ用一時ファイル生成を抱えない。
- 左一覧の人物分類、右一覧の編集ツールバー／メニュー／ショートカット、選択色、1px境界線は専用Controlへ閉じ込める。削除確認は共通`ConfirmDialog`を使い、192 DPIでも96 DPIと同じ論理寸法を保つ。
- 人物分類コンボとPMX画像一覧は`TPmxCatalogSelector`へまとめ、PMX管理、ポーズ・モーション、後続ページから共用する。メインフレームが選択中PmxUIDを保持し、ページ切替と各左一覧の選択変更時に同期する。
- ポーズ・モーションページは共通PMX選択ペインとPMX別ポーズ一覧を持ち、右側の操作ツールバー、ポップアップメニュー、ショートカットはPMX管理と同じ実装を共用する。VPD原本とメタデータは`Extension\VPD\Catalog`、ファイル列挙とPMX別PoseUID生成は`Extension\VPD\Import`、分類横断の選択状態と単一プレビューは`Extension\VPD\Reuse`が担当する。PMX管理の右一覧D&Dはモデル表示オブジェクト、ポーズページの右一覧D&Dはポーズオブジェクトを出力する。
- VMD原本は内容ハッシュ由来のVmdUIDで識別し、`VMD\Sources\{VmdUID}.vmd`と、全キー／Bezierを格納した変更しない内部正本`VMD\Data\{VmdUID}.json`を持つ。PMXへ登録したMotionUIDは、一覧用メタデータ`Motions\Items\{MotionUID}.json`と編集可能な実データ`Motions\Data\{MotionUID}.json`に分ける。
- モーション実データは版付き`TMmdMotionDocument`としてシリアライズし、編集・評価などで必要になった時だけデシリアライズする。MotionUID複製は実データも複製し、将来の原本復元はSourceVmdIdに対応するVmdUID正本から行う。
- ポーズ／モーション一覧D&DはScriptを基底エフェクト、標準描画を第2エフェクトとするBOMなしUTF-8 `.object`を生成する。効果名は`MMDポーズ@MMD_Script`／`MMDモーション@MMD_Script`とし、透明図形と入力Filterを使わない。
- 表情ページのD&Dは`Extension\Face\Catalog\Drag`が担当し、FaceUIDの保存JSONを`MMD_Face_Filter`の`表情`項目へそのまま格納する。出力はポーズと同じく標準描画を伴う単一入力オブジェクトとし、PMX管理のモデル表示エイリアスとは分離する。
- ポーズページの編集入口はPMX管理と同じ`TMmdModelSettingEditorForm`を使い、`ConfigureSettingControls(False, True)`でポーズ専用構成にする。D3Dプレビューとボーン操作、閉じる際の確定処理を共用しつつ、表情・目パチ・口パクを選ぶページ切替ツールバーは生成しない。

### モデル表示

- PMX読込と読取専用キャッシュ
- 現在フレームの外部入力評価
- モデル固有のモーフ解決
- IK、最終姿勢、スキニング、AviUtl2描画
- EffectID単位の可変コンテキスト
- AI MIRAIが要求した短時間の診断描画。通常描画、骨格、骨格重畳、単色シルエット、指ID色、身体材質だけの表示を切り替える。

表示モデルは外部ポーズの編集項目やキーフレームを所有しない。外部入力が現在フレームに存在しない場合、以前の状態を維持せず標準姿勢へ戻す。

### アクセサリ表示

- `MMD_Accessory_Filter`は人物以外のPMX／OBJを扱い、設定項目を`モデルファイル`と`MMD倍率`へ限定する。
- 拡張子でPMX ReaderまたはOBJ Readerの読取専用キャッシュを選び、両形式を共通の`TPmxModel`としてモデル表示の材質・テクスチャ・`draw_poly()`レンダラーへ渡す。
- ボーン変形、ポーズ、モーション、表情、目パチ、口パク、AI診断は適用せず、保存形状を静的メッシュとして描画する。
- `Extension\Accessory\Catalog\Drag`は選択SourceUIDの管理下ファイルから、アクセサリFilterと標準描画を持つ単一BOMなしUTF-8 `.object`を生成する。

### ポーズ

- 対象PMXの参照
- シリアライズ済み姿勢データの正本
- 設定GUIまたは将来の拡張UIによる編集
- `@MMD_Script.obj2`から`MMD_Module.mod2`の`set_pose`を呼び、現在フレーム値を共有メモリへ発行

### モーション

- `MMD_Motion_Runtime`はScriptの`obj.id`由来キー別に版付きモーションJSONの解析結果をキャッシュし、設定値が変化した場合だけ再デシリアライズする。
- `MmdMotionDocumentEvaluator`はオブジェクト相対フレームを、右側キーのX／Y／Z／回転Bezier、Quaternion Slerp、線形モーフ補間で名前付き現在状態へ変換する。
- `MmdMotionSharedMemory`はレイヤー別の専用チャネルへ、版、書込み世代、送信元ObjectID／EffectID、タイムライン／モーションフレーム、PMXパスハッシュ、ボーン／モーフ件数とFloat32中心のバイナリPayloadを発行する。
- `MMD_Model_MotionInput`は参照Scriptを強制評価し、レイヤー、PMXパス、タイムラインフレームが一致する値だけを同名PMXボーン／モーフへ解決する。送信側は特定のモデル表示を宛先指定しない。

### Script Module

- `MMD_Serif_Module.dproj`は1つの`MMD_Module.mod2`と`@MMD_Script.obj2`を生成し、`set_text`、`set_pose`、`set_motion`をまとめて公開する。
- Pose／Motion Scriptは`obj.layer - 1`をModuleへ渡し、SDKの0始まりレイヤーを使う既存共有メモリとモデル参照規約を維持する。
- 旧`MMD_Pose_Filter`／`MMD_Motion_Filter`は移行参照用ソースだけを残し、グループビルドと配布には含めない。

### セリフ入力

- `MMD_Serif_Module.dproj`は共通Scriptテンプレートを`MmdSerifScript.json`で展開し、MMD固有名の独立Scriptオブジェクトを配置する。図形オブジェクトと入力Filterは使わない。
- `Source\Plugin\Serif\Module`はScript Module ABIとUTF-8境界を担当し、12引数の`set_text`以降は`AviUtl2PluginLib\Serif\Plugin\Module`の共通発行処理へ渡す。
- `Source\Plugin\Serif\AviUtl`が製品別名称、共通Serif用Profile、Script基底エフェクトと標準描画のエイリアス直列化を担当する。
- `Source\Plugin\Serif\Host\MmdSerifHost`が共有フレームの遅延生成、プロジェクト読込／保存、シーン変更通知を担当する。AviUtl2コールバック内ではGUI同期せず、VCLタイマーへ遅延する。
- 共有Serifから製品固有表示への補助通知は`SerifHostNotifications`の登録式コールバックを通す。MMDは追加処理なし、Syncroh2だけがPSD更新を登録する。
- `SerifTalkSharedCodec`が現在フレームのLAB行と発話状態を含むSyncroh2互換キー文字列を生成し、`SerifTalkSharedMemory`が`Local\ShareTalk`を名前付きMutex付きで発行・読取する。
- Scriptの`obj.layer`を1始まりの共有スロットへそのまま発行し、モデル表示の1始まり参照レイヤーと対応させる。モデル側は参照レイヤーから1を引いて送信元Scriptを強制評価し、実在と現在フレームを検証する。Scriptの`obj.id`とSDKの`POBJECT_INFO.ID`は別体系なので比較しない。
- セリフ表示の実装本体は`AviUtl2PluginLib\Serif\Plugin\Draw`に置き、MMDとSyncroh2の各プロジェクトは公開名、グループ名、配置先だけを製品Profileで切り替える。

### 編集GUI

- 開いている間だけ作業用のモデル、姿勢、カメラ、選択、履歴、GPU資源を所有する。
- OKで姿勢全体を一括保存し、キャンセルで作業用コピーを破棄する。
- GUIの作業用コピーは共有メモリへ発行しない。

編集GUIは次の継承境界にする。

1. `TMmdPoseEditorFormBase`: 共通レイアウトとD3Dビュー
2. `TStandardPoseEditorForm`: PMX読込、ボーン編集、対称編集、履歴、Undo/Redo
3. `TMmdAiPreviewMainForm`: JSON候補一覧、最終PMX記録、Named Pipe受信、自動保存

Model／Poseプラグインは2段目だけを使用し、Named Pipeユニットへ依存しない。単体アプリだけが3段目を使用するため、編集GUIを一系統に保ったまま実装内容を分離する。

## 姿勢の処理順

基本の合成順は次の通り。

1. モデルの初期姿勢
2. モデル表示オブジェクトの標準姿勢
3. 現在フレームのモーション
4. 現在フレームの外部ポーズ
5. Motionモーフ、表情、口パク、まばたき等のモーフ
6. 親子変換、付与変形、IKによる最終ボーン計算
7. CPUスキニング
8. AviUtl2描画

同名ボーンは外部PoseがMotionを上書きする。モーフはMotionを土台に表情を上書きし、目パチ／口パクを加算する。それ以外の複数入力を追加する場合の優先順位は別途定義する。

## ソース構成

- Delphiプロジェクトファイルはルートへ配置し、`MMDAnimationStudioGroup.groupproj`でまとめる。
- MMD共通ライブラリは`..\AviUtl2PluginLib\MMD`、プラグイン固有コードは`Source\Plugin`へ置く。
- 拡張プラグイン固有コードは`Source\Plugin\Extension`へ置く。
- 拡張画面の外部入力分類は`Extension\Input`、ページ間の選択同期は`Extension\UI\Navigation`へ置き、メインフレームにはControl配置とイベント調停だけを残す。
- 既存のAIプレビュー関連コードは`Source\AI`へ残すが、初期の拡張プラグインには接続しない。
- MMD共通部の形式固有コードは`MMD\PMX`、`MMD\VMD`、`MMD\VPD`等へ分け、その下を`Model`、`IO`、`Editor`等の責務で分割する。
- 複数形式にまたがる処理は`MMD\Common`、共有メモリ等は`MMD\IPC`、AI境界は`MMD\AI`へ置く。既存配置は関連コードの変更時に段階的に移行する。
- Plugin固有部は`Context`、`Input`、`Runtime`、`Render`、`Editor`へ分け、口パク等はさらに機能別の下位フォルダーへ分ける。共通編集GUIはモーフ一覧を`Editor\Morph`、初期設定フォームを`Editor\Setting`、暗色ボタン・一覧・コンボを`Editor\Theme`へ配置する。`MmdPoseEditorTheme`は配色定数、共通項目描画、タイトルバーだけを持つ。
- D3D編集画面ではGPU資源を`Editor\D3D\Resource`、描画生成を`Editor\D3D\Render`、入力と選択を`Editor\D3D\Interaction`、参照画像の所有と合成を`Editor\D3D\Reference`へ分離し、直下にはViewportだけを置く。設定画面のツールバー構築は`Editor\Setting\Toolbar`が担当する。
- Filter設定項目は`Source\Lib\FilterTable\PluginFilterTable.pas`で登録する。
- 1ユニットは原則400行未満とし、統括ユニットへ詳細実装を集積しない。

## 並列性と障害境界

- 解析済みPMXだけを絶対パス単位で共有し、共有キャッシュへ可変状態を持たせない。
- 表示状態はEffectID単位、編集状態とD3D資源はGUIインスタンス単位、描画用一時配列はレンダースレッド単位で分離する。
- 外部ポーズと表情の存在範囲はModel側の`GetImageObject`で判定する。オブジェクトが存在する場合だけ機能別共有メモリを読み、レイヤーとモデルハッシュを照合して別モデルの値を拒否する。発行側とModelの開始位置が異なってもよいため、両者のオブジェクト相対フレームは照合しない。
- ファイル不存在、未知形式、破損、解析失敗、外部入力不正によってAviUtl2を停止させない。
- Filter、GUI、C ABIのコールバック境界からDelphi例外を漏らさない。
- AI診断表示はモデルDLL内のロック付き状態へモデルパス、表示種別、解除トークン、有効期限だけを保持する。C ABIの必要サイズ取得と本書込みによる同一要求2回実行に対して、開始と解除を冪等に扱う。
- AI MIRAIは診断開始、AviUtl2フレームレンダリング、診断解除を1操作として管理する。取得失敗時も`finally`相当の経路で解除する。
