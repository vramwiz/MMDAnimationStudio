unit MMD_Model_FilterPlugin;

// モデル表示Filterの登録と、1フレームの姿勢合成・描画順序を統括する。

interface

uses
  AviUtl2FilterTypes;

// 初回呼出時に設定項目を登録し、DLL有効期間中のFilterテーブルを返す。
function GetModelFilterTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  System.Math,
  System.SysUtils,
  PluginFilterTable,
  MmdAiDiagnosticState,
  PmxModel,
  PmxPose,
  PmxReader,
  MMD_Model_Context,
  MMD_Model_PoseInput,
  MMD_Model_Renderer,
  MMD_Model_StandardPoseButton;

var
  BoneOffsetXItem: TFILTER_ITEM_TRACK;
  DisplayModeItem: TFILTER_ITEM_SELECT;
  DisplayModeItems: array[0..3] of TFILTER_ITEM_SELECT_ITEM;
  ModelFileItem: TFILTER_ITEM_FILE;
  ModelScaleItem: TFILTER_ITEM_TRACK;
  PluginTableInitialized: Boolean;
  PoseLayerItem: TFILTER_ITEM_TRACK;
  StandardPoseButtonItem: TFILTER_ITEM_BUTTON;
  StandardPoseDataItem: TFILTER_ITEM_STRING;

threadvar
  BonePoses: TPmxBonePoses;
  BoneTransforms: TPmxBoneTransforms;
  SkinnedVertices: TPmxSkinnedVertices;

function ModelProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  Context: TMmdModelContext;
  DiagnosticActive: Boolean;
  DiagnosticMode: TMmdAiDiagnosticMode;
  DisplayMode: Integer;
  InternalScale: Single;
  Model: TPmxModel;
  ModelFileName: string;
  PoseDataText: string;
  PoseLayer: Integer;
  SerializedPoseActive: Boolean;
begin
  Result := 1;
  Context := nil;
  try
    try
      if (Video = nil) or not Assigned(Video^.DrawPoly) or
        (Video^.Object_ = nil) or (ModelFileItem.Value = nil) then
        Exit;
      ModelFileName := string(ModelFileItem.Value);
      if ModelFileName = '' then
        Exit;
      Model := GetCachedPmxModel(ModelFileName);
      DiagnosticActive := TryGetMmdAiDiagnosticMode(ModelFileName,
        DiagnosticMode);
      Context := AcquireModelContext(Video^.Object_^.EffectID,
        Video^.Object_^.ID);
      InternalScale := EnsureRange(ModelScaleItem.Value, 0.1, 100.0);
      DisplayMode := EnsureRange(DisplayModeItem.Value, DISPLAY_MODE_MODEL,
        DISPLAY_MODE_BOTH);
      PoseLayer := Round(EnsureRange(PoseLayerItem.Value, 0.0, 999.0));
      TryGetReferencedPoseData(Video, PoseLayer, ModelFileName, PoseDataText);
      Context.UpdateStandardPose(string(StandardPoseDataItem.Value));
      Context.UpdateExternalPose(PoseDataText);

      SerializedPoseActive := False;
      InitializeBonePoses(Model, BonePoses);
      if Context.StandardPoseValid and (Length(Context.StandardPoses) > 0) then
        SerializedPoseActive := ApplyNamedBonePoses(Model,
          Context.StandardPoses, BonePoses);
      if Context.ExternalPoseValid and (Length(Context.ExternalPoses) > 0) then
        // 外部姿勢は標準姿勢を土台として、同名ボーンだけを上書きする。
        SerializedPoseActive := ApplyNamedBonePoses(Model,
          Context.ExternalPoses, BonePoses) or SerializedPoseActive;
      if SerializedPoseActive then
      begin
        CalculateBoneTransforms(Model, BonePoses, BoneTransforms);
        SkinVerticesLinear(Model, BoneTransforms, SkinnedVertices);
      end;
      RenderPmxModel(Video, Model, BoneTransforms, SkinnedVertices,
        SerializedPoseActive, DisplayMode, DiagnosticMode, DiagnosticActive,
        InternalScale,
        EnsureRange(BoneOffsetXItem.Value, -100.0, 100.0));
      if Assigned(Video^.SetDefaultAnchor) then
        Video^.SetDefaultAnchor(640, 640);
      Result := 0;
    except
      // Delphi例外をAviUtl2のコールバック境界より外へ漏らさない。
    end;
  finally
    ReleaseModelContext(Context);
  end;
end;

procedure RegisterDisplayMode;
begin
  DisplayModeItems[0].Name := '標準';
  DisplayModeItems[0].Value := DISPLAY_MODE_MODEL;
  DisplayModeItems[1].Name := 'ボーンのみ';
  DisplayModeItems[1].Value := DISPLAY_MODE_BONES;
  DisplayModeItems[2].Name := '両方';
  DisplayModeItems[2].Value := DISPLAY_MODE_BOTH;
  DisplayModeItems[3].Name := nil;
  DisplayModeItems[3].Value := 0;
  AddSelect(DisplayModeItem, '表示モード', DISPLAY_MODE_MODEL,
    @DisplayModeItems[0]);
end;

function GetModelFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if not PluginTableInitialized then
  begin
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT,
      'モデル表示', 'MMD', 'PMXモデルをAviUtl2の3D空間へ表示するフィルター',
      ModelProcVideo, nil);
    SetFilterLifecycle(CreateModelContext, DestroyModelContext);
    AddFile(ModelFileItem, 'モデルファイル', '',
      'PMXモデル (*.pmx)'#0'*.pmx'#0 +
      'すべてのファイル (*.*)'#0'*.*'#0#0);
    RegisterDisplayMode;
    AddTrack(ModelScaleItem, 'MMD倍率', 15.0, 0.1, 100.0, 0.1);
    AddTrack(PoseLayerItem, 'ポーズ参照レイヤー', 0.0, 0.0, 999.0, 1.0);
    AddString(StandardPoseDataItem, '標準姿勢データ',
      '{"version":1,"bones":[]}');
    AddButton(StandardPoseButtonItem, '標準ポーズ設定',
      StandardPoseButtonCallback);
    AddTrack(BoneOffsetXItem, '比較用骨格Xずらし', 30.0, -100.0, 100.0,
      1.0);
    PluginTableInitialized := True;
  end;
  Result := GetPluginTable;
end;

end.
