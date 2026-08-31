unit MMD_Model_FilterItems;

// モデル表示Filterの設定項目を登録し、AviUtl2が所有する値への参照をまとめる。

interface

uses
  AviUtl2FilterTypes;

type
  TMmdModelFilterItems = record
    BoneOffsetX: TFILTER_ITEM_TRACK;
    DataGroup: TFILTER_ITEM_GROUP;
    DisplayMode: TFILTER_ITEM_SELECT;
    DisplayModeEntries: array[0..3] of TFILTER_ITEM_SELECT_ITEM;
    ExpressionData: TFILTER_ITEM_STRING;
    ExpressionLayer: TFILTER_ITEM_TRACK;
    EyeBlinkData: TFILTER_ITEM_STRING;
    EyeBlinkGroup: TFILTER_ITEM_GROUP;
    EyeBlinkInterval: TFILTER_ITEM_TRACK;
    EyeBlinkOffset: TFILTER_ITEM_TRACK;
    EyeBlinkSpeed: TFILTER_ITEM_TRACK;
    LipSyncData: TFILTER_ITEM_STRING;
    LipSyncGroup: TFILTER_ITEM_GROUP;
    LipSyncSpeed: TFILTER_ITEM_TRACK;
    LipSyncStrength: TFILTER_ITEM_TRACK;
    ModelFile: TFILTER_ITEM_FILE;
    ModelScale: TFILTER_ITEM_TRACK;
    MotionLayer: TFILTER_ITEM_TRACK;
    PoseLayer: TFILTER_ITEM_TRACK;
    ReferenceLayerGroup: TFILTER_ITEM_GROUP;
    SerifLayer: TFILTER_ITEM_TRACK;
    SettingsButton: TFILTER_ITEM_BUTTON;
    SongLayer: TFILTER_ITEM_TRACK;
    StandardPoseData: TFILTER_ITEM_STRING;
  end;

// Filterテーブルへ全設定項目を順番どおり追加する。
// Itemsは登録後もホストが更新するValueへの参照を保持する。
procedure RegisterMmdModelFilterItems(var Items: TMmdModelFilterItems);

implementation

uses
  PluginFilterTable,
  MmdEyeBlinkSettingCodec,
  MmdLipSyncSettingCodec,
  MMD_Model_Renderer,
  MMD_Model_SettingsButton;

procedure RegisterDisplayMode(var Items: TMmdModelFilterItems);
begin
  Items.DisplayModeEntries[0].Name := '標準';
  Items.DisplayModeEntries[0].Value := DISPLAY_MODE_MODEL;
  Items.DisplayModeEntries[1].Name := 'ボーンのみ';
  Items.DisplayModeEntries[1].Value := DISPLAY_MODE_BONES;
  Items.DisplayModeEntries[2].Name := '両方';
  Items.DisplayModeEntries[2].Value := DISPLAY_MODE_BOTH;
  Items.DisplayModeEntries[3].Name := nil;
  Items.DisplayModeEntries[3].Value := 0;
  AddSelect(Items.DisplayMode, '表示モード', DISPLAY_MODE_MODEL,
    @Items.DisplayModeEntries[0]);
end;

procedure RegisterMmdModelFilterItems(var Items: TMmdModelFilterItems);
begin
  AddFile(Items.ModelFile, 'モデルファイル', '',
    'PMXモデル (*.pmx)'#0'*.pmx'#0 +
    'すべてのファイル (*.*)'#0'*.*'#0#0);
  AddButton(Items.SettingsButton, '設定', ModelSettingsButtonCallback);
  AddTrack(Items.ModelScale, 'MMD倍率', 15.0, 0.1, 100.0, 0.1);

  AddGroup(Items.ReferenceLayerGroup, '参照レイヤー', 1);
  AddTrack(Items.ExpressionLayer, '表情参照レイヤー', 1.0, 1.0, 99.0, 1.0);
  AddTrack(Items.PoseLayer, 'ポーズ参照レイヤー', 1.0, 1.0, 99.0, 1.0);
  AddTrack(Items.MotionLayer, 'モーション参照レイヤー', 1.0, 1.0, 99.0, 1.0);
  AddTrack(Items.SerifLayer, 'セリフ参照レイヤー', 1.0, 1.0, 99.0, 1.0);
  AddTrack(Items.SongLayer, 'ソング参照レイヤー', 1.0, 1.0, 99.0, 1.0);

  AddGroup(Items.EyeBlinkGroup, '目パチ', 1);
  AddTrack(Items.EyeBlinkInterval, '目パチ間隔（秒）',
    DefaultMmdEyeBlinkIntervalSec, 1.0, 20.0, 0.01);
  AddTrack(Items.EyeBlinkSpeed, '目パチ速度（秒）',
    DefaultMmdEyeBlinkSpeedSec, 0.01, 100.0, 0.01);
  AddTrack(Items.EyeBlinkOffset, '目パチオフセット（秒）',
    DefaultMmdEyeBlinkOffsetSec, -20.0, 20.0, 0.01);
  AddGroup(Items.LipSyncGroup, '口パク', 1);
  AddTrack(Items.LipSyncSpeed, '口パク速度（秒）',
    DefaultMmdLipSyncSpeedSec, 0.01, 100.0, 0.01);
  AddTrack(Items.LipSyncStrength, '口パク強さ（%）',
    DefaultMmdLipSyncStrength * 100, 0.0, 100.0, 1.0);

  RegisterDisplayMode(Items);
  AddTrack(Items.BoneOffsetX, '比較用骨格Xずらし', 30.0, -100.0, 100.0, 1.0);

  // AviUtl2 2.1.3aでは初期の閉状態が保持されない可能性があるが、SDK上の既定値は閉として登録する。
  AddGroup(Items.DataGroup, 'データ', 0);
  AddString(Items.StandardPoseData, 'ポーズ', '{"version":1,"bones":[]}');
  AddString(Items.ExpressionData, '表情', '{"version":1,"morphs":[]}');
  AddString(Items.EyeBlinkData, '目パチデータ', EmptyMmdEyeBlinkSettingData);
  AddString(Items.LipSyncData, '口パクデータ', EmptyMmdLipSyncSettingData);
end;

end.
