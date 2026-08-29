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
  MmdEyeBlinkSettingCodec,
  MmdLipSyncSettingCodec,
  PmxModel,
  PmxMorph,
  PmxPose,
  PmxReader,
  MMD_Model_Context,
  MMD_Model_LipSyncInput,
  MMD_Model_LipSyncProtocol,
  MMD_Model_PoseInput,
  MMD_Model_Renderer,
  MMD_Model_SettingsButton;

var
  BoneOffsetXItem: TFILTER_ITEM_TRACK;
  DisplayModeItem: TFILTER_ITEM_SELECT;
  DisplayModeItems: array[0..3] of TFILTER_ITEM_SELECT_ITEM;
  DataGroupItem: TFILTER_ITEM_GROUP;
  ModelFileItem: TFILTER_ITEM_FILE;
  ExpressionDataItem: TFILTER_ITEM_STRING;
  ExpressionLayerItem: TFILTER_ITEM_TRACK;
  EyeBlinkDataItem: TFILTER_ITEM_STRING;
  EyeBlinkGroupItem: TFILTER_ITEM_GROUP;
  EyeBlinkIntervalItem: TFILTER_ITEM_TRACK;
  EyeBlinkOffsetItem: TFILTER_ITEM_TRACK;
  EyeBlinkSpeedItem: TFILTER_ITEM_TRACK;
  LipSyncDataItem: TFILTER_ITEM_STRING;
  LipSyncGroupItem: TFILTER_ITEM_GROUP;
  LipSyncSpeedItem: TFILTER_ITEM_TRACK;
  LipSyncStrengthItem: TFILTER_ITEM_TRACK;
  ModelScaleItem: TFILTER_ITEM_TRACK;
  MotionLayerItem: TFILTER_ITEM_TRACK;
  PluginTableInitialized: Boolean;
  PoseLayerItem: TFILTER_ITEM_TRACK;
  ReferenceLayerGroupItem: TFILTER_ITEM_GROUP;
  SerifLayerItem: TFILTER_ITEM_TRACK;
  SettingsButtonItem: TFILTER_ITEM_BUTTON;
  SongLayerItem: TFILTER_ITEM_TRACK;
  StandardPoseDataItem: TFILTER_ITEM_STRING;

threadvar
  BonePoses: TPmxBonePoses;
  BoneTransforms: TPmxBoneTransforms;
  CombinedMorphWeights: TPmxMorphWeights;
  MorphPositions: TPmxVertexPositions;
  SkinnedVertices: TPmxSkinnedVertices;

function ModelProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  BaseMorphWeight: Single;
  Context: TMmdModelContext;
  DiagnosticActive: Boolean;
  DiagnosticMode: TMmdAiDiagnosticMode;
  DisplayMode: Integer;
  EyeBlinkAmount: Single;
  EyeBlinkConfigured: Boolean;
  Fps: Double;
  Frame, I: Integer;
  InternalScale: Single;
  InitialExpressionActive: Boolean;
  LipSyncActive, LipSyncConfigured, LipSyncHasSample: Boolean;
  LipSyncSample: TMmdLipSyncSample;
  LipSyncSpeed: Double;
  MorphActive: Boolean;
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
      Frame := Video^.Object_^.Frame;
      PoseLayer := Round(EnsureRange(PoseLayerItem.Value, 1.0, 99.0));
      TryGetReferencedPoseData(Video, PoseLayer, ModelFileName, PoseDataText);
      Context.UpdateStandardPose(string(StandardPoseDataItem.Value));
      Context.UpdateInitialExpression(string(ExpressionDataItem.Value));
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
      InitialExpressionActive := Context.ResolveInitialExpression(Model);
      Fps := 0;
      if (Video^.Scene <> nil) and (Video^.Scene^.Scale <> 0) then
        Fps := Video^.Scene^.Rate / Video^.Scene^.Scale;
      // 目パチは任意機能とし、旧形式や時刻計算の異常時も姿勢・表情の通常描画を継続する。
      EyeBlinkConfigured := False;
      try
        if EyeBlinkDataItem.Value <> nil then
        begin
          Context.UpdateEyeBlink(string(EyeBlinkDataItem.Value));
          EyeBlinkConfigured := Context.ResolveEyeBlink(Model);
        end;
        if EyeBlinkConfigured then
        begin
          InitializeMorphWeights(Model, CombinedMorphWeights);
          if InitialExpressionActive then
            for I := 0 to Min(High(CombinedMorphWeights),
              High(Context.InitialExpressionWeights)) do
              CombinedMorphWeights[I] := Context.InitialExpressionWeights[I];
          EyeBlinkAmount := Context.EyeBlinkAmount(Frame, Fps,
            EnsureRange(EyeBlinkIntervalItem.Value, 1.0, 20.0),
            EnsureRange(EyeBlinkSpeedItem.Value, 0.01, 100.0),
            EnsureRange(EyeBlinkOffsetItem.Value, -20.0, 20.0));
          I := Context.EyeBlinkMorphIndex;
          BaseMorphWeight := CombinedMorphWeights[I];
          CombinedMorphWeights[I] := BaseMorphWeight +
            (Context.EyeBlinkClosedWeight - BaseMorphWeight) * EyeBlinkAmount;
        end;
      except
        EyeBlinkConfigured := False;
      end;

      // 口パク共有領域は読み取り専用とし、不在や不正値でもモデル描画を継続する。
      LipSyncConfigured := False;
      LipSyncActive := False;
      try
        if LipSyncDataItem.Value <> nil then
        begin
          Context.UpdateLipSync(string(LipSyncDataItem.Value));
          LipSyncConfigured := Context.ResolveLipSync(Model);
        end;
        if LipSyncConfigured then
        begin
          LipSyncSpeed := EnsureRange(LipSyncSpeedItem.Value, 0.01, 100.0);
          LipSyncHasSample := ReadMmdLipSyncSample(
            Round(EnsureRange(SerifLayerItem.Value, 1.0, 99.0)),
            Round(EnsureRange(SongLayerItem.Value, 1.0, 99.0)),
            LipSyncSpeed, LipSyncSample);
          LipSyncActive := Context.UpdateLipSyncWeights(LipSyncSample,
            LipSyncHasSample, Frame, Fps, LipSyncSpeed,
            EnsureRange(LipSyncStrengthItem.Value / 100, 0.0, 1.0));
          if LipSyncActive then
          begin
            if not EyeBlinkConfigured then
            begin
              InitializeMorphWeights(Model, CombinedMorphWeights);
              if InitialExpressionActive then
                for I := 0 to Min(High(CombinedMorphWeights),
                  High(Context.InitialExpressionWeights)) do
                  CombinedMorphWeights[I] :=
                    Context.InitialExpressionWeights[I];
            end;
            for I := 0 to Min(High(CombinedMorphWeights),
              High(Context.LipSyncWeights)) do
              CombinedMorphWeights[I] := EnsureRange(CombinedMorphWeights[I] +
                Context.LipSyncWeights[I], 0.0, 1.0);
          end;
        end;
      except
        LipSyncActive := False;
      end;

      MorphActive := InitialExpressionActive;
      if EyeBlinkConfigured or LipSyncActive then
      begin
        MorphActive := False;
        for I := 0 to High(CombinedMorphWeights) do
          if Abs(CombinedMorphWeights[I]) > 0.000001 then
          begin
            MorphActive := True;
            Break;
          end;
      end;
      if MorphActive then
      begin
        if EyeBlinkConfigured or LipSyncActive then
          ApplyMorphs(Model, CombinedMorphWeights, BonePoses,
            MorphPositions)
        else
          ApplyMorphs(Model, Context.InitialExpressionWeights, BonePoses,
            MorphPositions);
        CalculateBoneTransforms(Model, BonePoses, BoneTransforms);
        SkinVerticesLinear(Model, MorphPositions, BoneTransforms,
          SkinnedVertices);
      end
      else if SerializedPoseActive then
      begin
        CalculateBoneTransforms(Model, BonePoses, BoneTransforms);
        SkinVerticesLinear(Model, BoneTransforms, SkinnedVertices);
      end;
      RenderPmxModel(Video, Model, BoneTransforms, SkinnedVertices,
        SerializedPoseActive or MorphActive, DisplayMode,
        DiagnosticMode, DiagnosticActive,
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
    AddButton(SettingsButtonItem, '設定', ModelSettingsButtonCallback);
    AddTrack(ModelScaleItem, 'MMD倍率', 15.0, 0.1, 100.0, 0.1);

    AddGroup(ReferenceLayerGroupItem, '参照レイヤー', 1);
    AddTrack(ExpressionLayerItem, '表情参照レイヤー', 1.0, 1.0, 99.0,
      1.0);
    AddTrack(PoseLayerItem, 'ポーズ参照レイヤー', 1.0, 1.0, 99.0, 1.0);
    AddTrack(MotionLayerItem, 'モーション参照レイヤー', 1.0, 1.0, 99.0,
      1.0);
    AddTrack(SerifLayerItem, 'セリフ参照レイヤー', 1.0, 1.0, 99.0, 1.0);
    AddTrack(SongLayerItem, 'ソング参照レイヤー', 1.0, 1.0, 99.0, 1.0);

    AddGroup(EyeBlinkGroupItem, '目パチ', 1);
    AddTrack(EyeBlinkIntervalItem, '目パチ間隔（秒）',
      DefaultMmdEyeBlinkIntervalSec, 1.0, 20.0, 0.01);
    AddTrack(EyeBlinkSpeedItem, '目パチ速度（秒）',
      DefaultMmdEyeBlinkSpeedSec, 0.01, 100.0, 0.01);
    AddTrack(EyeBlinkOffsetItem, '目パチオフセット（秒）',
      DefaultMmdEyeBlinkOffsetSec, -20.0, 20.0, 0.01);
    AddGroup(LipSyncGroupItem, '口パク', 1);
    AddTrack(LipSyncSpeedItem, '口パク速度（秒）',
      DefaultMmdLipSyncSpeedSec, 0.01, 100.0, 0.01);
    AddTrack(LipSyncStrengthItem, '口パク強さ（%）',
      DefaultMmdLipSyncStrength * 100, 0.0, 100.0, 1.0);

    RegisterDisplayMode;
    AddTrack(BoneOffsetXItem, '比較用骨格Xずらし', 30.0, -100.0, 100.0,
      1.0);

    // AviUtl2 2.1.3aでは初期の閉状態が保持されない可能性があるが、
    // SDK上の既定値は閉として登録する。
    AddGroup(DataGroupItem, 'データ', 0);
    AddString(StandardPoseDataItem, 'ポーズ',
      '{"version":1,"bones":[]}');
    AddString(ExpressionDataItem, '表情',
      '{"version":1,"morphs":[]}');
    AddString(EyeBlinkDataItem, '目パチデータ',
      EmptyMmdEyeBlinkSettingData);
    AddString(LipSyncDataItem, '口パクデータ',
      EmptyMmdLipSyncSettingData);
    PluginTableInitialized := True;
  end;
  Result := GetPluginTable;
end;

end.
