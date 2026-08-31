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
  MmdMorphSettingCodec,
  PmxModel,
  PmxMorph,
  PmxPose,
  PmxReader,
  MMD_Model_Context,
  MMD_Model_DebugLog,
  MMD_Model_FaceInput,
  MMD_Model_LipSyncInput,
  MMD_Model_LipSyncProtocol,
  MMD_Model_MotionInput,
  MMD_Model_PoseInput,
  MMD_Model_FilterItems,
  MMD_Model_Renderer;

var
  ModelItems: TMmdModelFilterItems;
  PluginTableInitialized: Boolean;
{$IFDEF DEBUG}
  ModelLipSyncLogCount: Integer;
{$ENDIF}

threadvar
  BonePoses: TPmxBonePoses;
  BoneTransforms: TPmxBoneTransforms;
  CombinedMorphWeights: TPmxMorphWeights;
  MorphPositions: TPmxVertexPositions;
  SkinnedVertices: TPmxSkinnedVertices;

function ModelProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  BaseMorphWeight: Single;
  BaseExpressionWeights: TPmxMorphWeights;
  Context: TMmdModelContext;
  DiagnosticActive: Boolean;
  DiagnosticMode: TMmdAiDiagnosticMode;
  DisplayMode: Integer;
  EyeBlinkAmount: Single;
  EyeBlinkConfigured: Boolean;
  ExpressionUsesEye: Boolean;
  ExpressionUsesLip: Boolean;
  ExternalExpressionActive: Boolean;
  FaceDataText: string;
  FaceLayer: Integer;
  Fps: Double;
  Frame, I: Integer;
  InternalScale: Single;
  InitialExpressionActive: Boolean;
  LipSyncActive, LipSyncConfigured, LipSyncHasSample: Boolean;
  LipSyncSample: TMmdLipSyncSample;
  LipSyncSpeed: Double;
  LipSyncStrength: Single;
  MorphActive: Boolean;
  Model: TPmxModel;
  ModelFileName: string;
  MotionLayer: Integer;
  MotionMorphActive, MotionPoseActive, MotionReceived: Boolean;
  MotionMorphs: TMmdNamedMorphWeights;
  MotionMorphWeights: TPmxMorphWeights;
  MotionPoses: TPmxNamedBonePoses;
  PoseDataText: string;
  PoseLayer: Integer;
  SerializedPoseActive: Boolean;
begin
  Result := 1;
  Context := nil;
  try
    try
      if (Video = nil) or not Assigned(Video^.DrawPoly) or
        (Video^.Object_ = nil) or (ModelItems.ModelFile.Value = nil) then
        Exit;
      ModelFileName := string(ModelItems.ModelFile.Value);
      if ModelFileName = '' then
        Exit;
      Model := GetCachedPmxModel(ModelFileName);
      DiagnosticActive := TryGetMmdAiDiagnosticMode(ModelFileName,
        DiagnosticMode);
      Context := AcquireModelContext(Video^.Object_^.EffectID,
        Video^.Object_^.ID);
      InternalScale := EnsureRange(ModelItems.ModelScale.Value, 0.1, 100.0);
      DisplayMode := EnsureRange(ModelItems.DisplayMode.Value, DISPLAY_MODE_MODEL,
        DISPLAY_MODE_BOTH);
      Frame := Video^.Object_^.Frame;
      FaceLayer := Round(EnsureRange(ModelItems.ExpressionLayer.Value, 1.0, 99.0));
      PoseLayer := Round(EnsureRange(ModelItems.PoseLayer.Value, 1.0, 99.0));
      MotionLayer := Round(EnsureRange(ModelItems.MotionLayer.Value, 1.0, 99.0));
      TryGetReferencedFaceData(Video, FaceLayer, ModelFileName, FaceDataText);
      TryGetReferencedPoseData(Video, PoseLayer, ModelFileName, PoseDataText);
      MotionReceived := TryGetReferencedMotion(Video, MotionLayer,
        ModelFileName, MotionPoses, MotionMorphs);
      Context.UpdateStandardPose(string(ModelItems.StandardPoseData.Value));
      Context.UpdateInitialExpression(string(ModelItems.ExpressionData.Value));
      Context.UpdateExternalExpression(FaceDataText);
      Context.UpdateExternalPose(PoseDataText);

      SerializedPoseActive := False;
      InitializeBonePoses(Model, BonePoses);
      if Context.StandardPoseValid and (Length(Context.StandardPoses) > 0) then
        SerializedPoseActive := ApplyNamedBonePoses(Model,
          Context.StandardPoses, BonePoses);
      MotionPoseActive := False;
      MotionMorphActive := False;
      InitializeMorphWeights(Model, MotionMorphWeights);
      if MotionReceived then
        ResolveMotionForModel(Model, MotionPoses, MotionMorphs, BonePoses,
          MotionMorphWeights, MotionPoseActive, MotionMorphActive);
      SerializedPoseActive := MotionPoseActive or SerializedPoseActive;
      if Context.ExternalPoseValid and (Length(Context.ExternalPoses) > 0) then
        // 外部Poseは標準姿勢とMotionを土台に、同名ボーンを上書きする。
        SerializedPoseActive := ApplyNamedBonePoses(Model,
          Context.ExternalPoses, BonePoses) or SerializedPoseActive;
      InitialExpressionActive := Context.ResolveInitialExpression(Model);
      ExternalExpressionActive := Context.ResolveExternalExpression(Model);
      if Context.ExternalExpressionValid then
        BaseExpressionWeights := Context.ExternalExpressionWeights
      else
        BaseExpressionWeights := Context.InitialExpressionWeights;
      InitializeMorphWeights(Model, CombinedMorphWeights);
      if MotionMorphActive then
        for I := 0 to Min(High(CombinedMorphWeights),
          High(MotionMorphWeights)) do
          CombinedMorphWeights[I] := MotionMorphWeights[I];
      if InitialExpressionActive or ExternalExpressionActive then
        for I := 0 to Min(High(CombinedMorphWeights),
          High(BaseExpressionWeights)) do
          if Abs(BaseExpressionWeights[I]) > 0.000001 then
            CombinedMorphWeights[I] := BaseExpressionWeights[I];
      ExpressionUsesEye := MorphWeightsUsePanel(Model,
        CombinedMorphWeights, PMX_MORPH_PANEL_EYE);
      ExpressionUsesLip := MorphWeightsUsePanel(Model,
        CombinedMorphWeights, PMX_MORPH_PANEL_LIP);
      Fps := 0;
      if (Video^.Scene <> nil) and (Video^.Scene^.Scale <> 0) then
        Fps := Video^.Scene^.Rate / Video^.Scene^.Scale;
      // 目パチは任意機能とし、旧形式や時刻計算の異常時も姿勢・表情の通常描画を継続する。
      EyeBlinkConfigured := False;
      try
        if ModelItems.EyeBlinkData.Value <> nil then
        begin
          Context.UpdateEyeBlink(string(ModelItems.EyeBlinkData.Value));
          EyeBlinkConfigured := not ExpressionUsesEye and
            Context.ResolveEyeBlink(Model);
        end;
        if EyeBlinkConfigured then
        begin
          EyeBlinkAmount := Context.EyeBlinkAmount(Frame, Fps,
            EnsureRange(ModelItems.EyeBlinkInterval.Value, 1.0, 20.0),
            EnsureRange(ModelItems.EyeBlinkSpeed.Value, 0.01, 100.0),
            EnsureRange(ModelItems.EyeBlinkOffset.Value, -20.0, 20.0));
          I := Context.EyeBlinkMorphIndex;
          BaseMorphWeight := CombinedMorphWeights[I];
          CombinedMorphWeights[I] := BaseMorphWeight +
            (Context.EyeBlinkClosedWeight - BaseMorphWeight) * EyeBlinkAmount;
        end;
      except
      end;

      // 口パク共有領域は読み取り専用とし、不在や不正値でもモデル描画を継続する。
      LipSyncConfigured := False;
      try
        if ModelItems.LipSyncData.Value <> nil then
        begin
          Context.UpdateLipSync(string(ModelItems.LipSyncData.Value));
          LipSyncConfigured := not ExpressionUsesLip and
            Context.ResolveLipSync(Model);
{$IFDEF DEBUG}
          if ModelLipSyncLogCount < 300 then
          begin
            Inc(ModelLipSyncLogCount);
            MmdModelDebugLog(Format(
              'LipSync gate: frame=%d data_len=%d expression_uses_lip=%d ' +
              'configured=%d serif_layer=%.3f song_layer=%.3f fps=%.3f',
              [Frame, Length(string(ModelItems.LipSyncData.Value)),
               Ord(ExpressionUsesLip), Ord(LipSyncConfigured),
               ModelItems.SerifLayer.Value, ModelItems.SongLayer.Value, Fps]));
          end;
{$ENDIF}
        end;
        if LipSyncConfigured then
        begin
          LipSyncSpeed := EnsureRange(ModelItems.LipSyncSpeed.Value,
            0.01, 100.0);
          LipSyncStrength := EnsureRange(ModelItems.LipSyncStrength.Value / 100,
            0.0, 1.0);
          LipSyncHasSample := ReadReferencedMmdLipSyncSample(Video,
            Round(EnsureRange(ModelItems.SerifLayer.Value, 1.0, 99.0)),
            Round(EnsureRange(ModelItems.SongLayer.Value, 1.0, 99.0)),
            LipSyncSpeed, LipSyncSample);
          LipSyncActive := Context.UpdateLipSyncWeights(LipSyncSample,
            LipSyncHasSample, Frame, Fps, LipSyncSpeed,
            LipSyncStrength);
{$IFDEF DEBUG}
          if ModelLipSyncLogCount < 300 then
          begin
            Inc(ModelLipSyncLogCount);
            MmdModelDebugLog(Format(
              'LipSync apply: frame=%d has_sample=%d kind=%d phoneme=%d ' +
              'open=%.4f speed=%.4f strength=%.4f active=%d',
              [Frame, Ord(LipSyncHasSample), Ord(LipSyncSample.Kind),
               Ord(LipSyncSample.Phoneme), LipSyncSample.OpenAmount,
               LipSyncSpeed, LipSyncStrength, Ord(LipSyncActive)]));
          end;
{$ENDIF}
          if LipSyncActive then
          begin
            for I := 0 to Min(High(CombinedMorphWeights),
              High(Context.LipSyncWeights)) do
              CombinedMorphWeights[I] := EnsureRange(CombinedMorphWeights[I] +
                Context.LipSyncWeights[I], 0.0, 1.0);
          end;
        end;
      except
        on E: Exception do
        begin
{$IFDEF DEBUG}
          if ModelLipSyncLogCount < 300 then
          begin
            Inc(ModelLipSyncLogCount);
            MmdModelDebugLog('LipSync exception: ' + E.ClassName + ': ' +
              E.Message);
          end;
{$ENDIF}
        end;
      end;

      MorphActive := False;
      for I := 0 to High(CombinedMorphWeights) do
        if Abs(CombinedMorphWeights[I]) > 0.000001 then
        begin
          MorphActive := True;
          Break;
        end;
      if MorphActive then
      begin
        ApplyMorphs(Model, CombinedMorphWeights, BonePoses, MorphPositions);
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
        EnsureRange(ModelItems.BoneOffsetX.Value, -100.0, 100.0));
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

function GetModelFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if not PluginTableInitialized then
  begin
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT,
      'モデル表示', 'MMD', 'PMXモデルをAviUtl2の3D空間へ表示するフィルター',
      ModelProcVideo, nil);
    SetFilterLifecycle(CreateModelContext, DestroyModelContext);
    RegisterMmdModelFilterItems(ModelItems);
    PluginTableInitialized := True;
  end;
  Result := GetPluginTable;
end;

end.
