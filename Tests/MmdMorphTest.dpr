program MmdMorphTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Messages,
  Winapi.Windows,
  System.IOUtils,
  System.Math,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  HorizontalTrackBarRenderer in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarRenderer.pas',
  HorizontalTrackBarControl in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas',
  VerticalScrollBarControl in '..\AviUtl2PluginLib\Lib\VerticalScrollBar\VerticalScrollBarControl.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxMorph in '..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxBoneSolver in '..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxReader in '..\AviUtl2PluginLib\MMD\IO\PmxReader.pas',
  PmxBinaryStream in '..\AviUtl2PluginLib\MMD\IO\PmxBinaryStream.pas',
  PmxGeometryReader in '..\AviUtl2PluginLib\MMD\IO\PmxGeometryReader.pas',
  PmxMaterialReader in '..\AviUtl2PluginLib\MMD\IO\PmxMaterialReader.pas',
  PmxBoneReader in '..\AviUtl2PluginLib\MMD\IO\PmxBoneReader.pas',
  PmxMorphReader in '..\AviUtl2PluginLib\MMD\IO\PmxMorphReader.pas',
  MmdMorphSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdEyeBlinkSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdEyeBlinkSettingCodec.pas',
  MmdEyeBlinkSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdEyeBlinkSettingPanel.pas',
  MmdSettingPanelValue in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdSettingPanelValue.pas',
  MMD_Model_EyeBlink in 'Source\Plugin\Model\Runtime\EyeBlink\MMD_Model_EyeBlink.pas',
  MmdLipSyncSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  SharedMemoryBase in '..\AviUtl2PluginLib\Lib\SharedMemory\SharedMemoryBase.pas',
  KeyValueText in '..\AviUtl2PluginLib\Lib\KeyValue\KeyValueText.pas',
  MMD_Model_LipSyncProtocol in 'Source\Plugin\Model\Input\LipSync\MMD_Model_LipSyncProtocol.pas',
  MMD_Model_LipSyncInput in 'Source\Plugin\Model\Input\LipSync\MMD_Model_LipSyncInput.pas',
  MMD_Model_LipSyncContext in 'Source\Plugin\Model\Context\LipSync\MMD_Model_LipSyncContext.pas',
  MMD_Model_Context in 'Source\Plugin\Model\Context\MMD_Model_Context.pas',
  MmdLipSyncSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdLipSyncSettingPanel.pas',
  MmdD3DDeform in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DDeform.pas',
  MmdMorphSettingListRenderer in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingListRenderer.pas',
  MmdMorphSettingRows in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingRows.pas',
  MmdMorphSettingValue in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingValue.pas',
  MmdMorphSettingList in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingList.pas',
  MmdMorphPreviewPanel in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphPreviewPanel.pas';

type
  TMmdMorphSettingListAccess = class(TMmdMorphSettingList)
  public
    procedure ClickAt(const ClientPoint: TPoint);
    function WheelAt(WheelDelta: Integer; const ScreenPoint: TPoint): Boolean;
  end;

procedure TMmdMorphSettingListAccess.ClickAt(const ClientPoint: TPoint);
begin
  MouseDown(mbLeft, [], ClientPoint.X, ClientPoint.Y);
  MouseUp(mbLeft, [], ClientPoint.X, ClientPoint.Y);
end;

function TMmdMorphSettingListAccess.WheelAt(WheelDelta: Integer;
  const ScreenPoint: TPoint): Boolean;
begin
  Result := DoMouseWheel([], WheelDelta, ScreenPoint);
end;

procedure CheckNear(Actual, Expected: Single; const Name: string);
begin
  if Abs(Actual - Expected) > 0.0001 then
    raise Exception.CreateFmt('%s: expected %.6f, got %.6f',
      [Name, Expected, Actual]);
end;

procedure TestMorphPanelCreation;
var
  Form: TForm;
  I: Integer;
  Model: TPmxModel;
  Panel: TMmdMorphPreviewPanel;
  List: TMmdMorphSettingList;
  ScrollBar: TVerticalScrollBarControl;
  Weights: TPmxMorphWeights;
begin
  Form := TForm.Create(nil);
  Model := TPmxModel.Create;
  try
    SetLength(Model.Morphs, 12);
    for I := 0 to High(Model.Morphs) do
    begin
      Model.Morphs[I].Name := 'morph-' + I.ToString;
      Model.Morphs[I].Panel := (I div 4) + 1;
      Model.Morphs[I].MorphType := pmtVertex;
    end;
    Panel := TMmdMorphPreviewPanel.Create(Form);
    Panel.Parent := Form;
    Panel.SetBounds(0, 0, MulDiv(300, Screen.PixelsPerInch, 96),
      MulDiv(180, Screen.PixelsPerInch, 96));
    Form.Show;
    Application.ProcessMessages;
    Panel.SetModel(Model);
    List := nil;
    for I := 0 to Panel.ComponentCount - 1 do
      if Panel.Components[I] is TMmdMorphSettingList then
        List := TMmdMorphSettingList(Panel.Components[I]);
    if List = nil then
      raise Exception.Create('virtual morph setting list was not found');
    ScrollBar := nil;
    for I := 0 to List.ComponentCount - 1 do
      if List.Components[I] is TVerticalScrollBarControl then
        ScrollBar := TVerticalScrollBarControl(List.Components[I]);
    if (ScrollBar = nil) or not ScrollBar.Visible then
      raise Exception.Create('custom vertical morph scroll bar was not shown');
    TMmdMorphSettingListAccess(List).WheelAt(-WHEEL_DELTA,
      List.ClientToScreen(Point(List.ClientWidth div 2,
        MulDiv(15, Screen.PixelsPerInch, 96))));
    Panel.CopyWeights(Weights);
    CheckNear(Weights[0], 0.0, 'track hover wheel must not edit weight');
    if ScrollBar.Position <= 0 then
      raise Exception.Create('track hover wheel did not scroll the list');
    ScrollBar.Position := 0;
    TMmdMorphSettingListAccess(List).ClickAt(Point(
      ScrollBar.Left - MulDiv(24, Screen.PixelsPerInch, 96),
      MulDiv(45, Screen.PixelsPerInch, 96)));
    Panel.CopyWeights(Weights);
    CheckNear(Weights[0], 1.0, 'right edge snap');
    TMmdMorphSettingListAccess(List).ClickAt(Point(
      Max(MulDiv(82, Screen.PixelsPerInch, 96),
        (ScrollBar.Left - MulDiv(8, Screen.PixelsPerInch, 96)) div 3) +
        MulDiv(4, Screen.PixelsPerInch, 96),
      MulDiv(45, Screen.PixelsPerInch, 96)));
    Panel.CopyWeights(Weights);
    CheckNear(Weights[0], 0.0, 'left edge snap');
    for I := 1 to 60 do
      SendMessage(List.Handle, WM_KEYDOWN, VK_RIGHT, 0);
    Panel.CopyWeights(Weights);
    if (Weights[0] < 0.59) or (Weights[0] > 0.61) then
      raise Exception.Create('virtual morph track did not update its weight');
    // 右端の操作方式を2値へ切り替えると、現在値は0または1へ丸める。
    SendMessage(List.Handle, WM_KEYDOWN, VK_SPACE, 0);
    Panel.CopyWeights(Weights);
    CheckNear(Weights[0], 1.0, 'binary morph mode snap');
    for I := 1 to 4 do
      SendMessage(List.Handle, WM_KEYDOWN, VK_DOWN, 0);
    SendMessage(List.Handle, WM_KEYDOWN, VK_RIGHT, 0);
    Panel.CopyWeights(Weights);
    CheckNear(Weights[4], 0.01, 'keyboard skips category header');
  finally
    Model.Free;
    Form.Free;
  end;
end;

procedure TestGroupedVertexAndBoneMorph;
var
  Model: TPmxModel;
  Positions: TPmxVertexPositions;
  Poses: TPmxBonePoses;
  Skinned: TPmxSkinnedVertices;
  Transforms: TPmxBoneTransforms;
  Weights: TPmxMorphWeights;
begin
  Model := TPmxModel.Create;
  try
    SetLength(Model.Vertices, 1);
    Model.Vertices[0].DeformType := pdtBdef1;
    Model.Vertices[0].BoneIndices[0] := 0;
    Model.Vertices[0].BoneWeights[0] := 1;
    SetLength(Model.Bones, 1);
    Model.Bones[0].ParentIndex := -1;
    SetLength(Model.Morphs, 3);
    Model.Morphs[0].MorphType := pmtVertex;
    SetLength(Model.Morphs[0].VertexOffsets, 1);
    Model.Morphs[0].VertexOffsets[0].Offset.X := 2;
    Model.Morphs[1].MorphType := pmtBone;
    SetLength(Model.Morphs[1].BoneOffsets, 1);
    Model.Morphs[1].BoneOffsets[0].Translation.Y := 3;
    Model.Morphs[1].BoneOffsets[0].Rotation.W := Cos(Pi / 4);
    Model.Morphs[1].BoneOffsets[0].Rotation.Z := Sin(Pi / 4);
    Model.Morphs[2].MorphType := pmtGroup;
    SetLength(Model.Morphs[2].GroupOffsets, 2);
    Model.Morphs[2].GroupOffsets[0].MorphIndex := 0;
    Model.Morphs[2].GroupOffsets[0].Weight := 0.4;
    Model.Morphs[2].GroupOffsets[1].MorphIndex := 1;
    Model.Morphs[2].GroupOffsets[1].Weight := 0.4;
    InitializeBonePoses(Model, Poses);
    InitializeMorphWeights(Model, Weights);
    Weights[2] := 0.5;
    ApplyMorphs(Model, Weights, Poses, Positions);
    CheckNear(Positions[0].X, 0.4, 'grouped vertex');
    CheckNear(Poses[0].Translation.Y, 0.6, 'grouped bone translation');
    CheckNear(Poses[0].Rotation.W, Cos(Pi / 20), 'grouped bone rotation');
    CalculateBoneTransforms(Model, Poses, Transforms);
    SkinVerticesLinear(Model, Positions, Transforms, Skinned);
    CheckNear(Skinned[0].Position.X, 0.4 * Cos(Pi / 10), 'morphed skin x');
    CheckNear(Skinned[0].Position.Y, 0.6 + 0.4 * Sin(Pi / 10),
      'morphed skin y');
    InitializeBonePoses(Model, Poses);
    DeformPreviewModel(Model, Poses, Weights, Transforms, Skinned);
    CheckNear(Skinned[0].Position.X, 0.4 * Cos(Pi / 10),
      'preview morphed skin x');
    CheckNear(Skinned[0].Position.Y, 0.6 + 0.4 * Sin(Pi / 10),
      'preview morphed skin y');
  finally
    Model.Free;
  end;
end;

procedure TestMorphSettingCodec;
var
  Encoded: string;
  Model: TPmxModel;
  Named: TMmdNamedMorphWeights;
  Resolved, Weights: TPmxMorphWeights;
begin
  Model := TPmxModel.Create;
  try
    SetLength(Model.Morphs, 3);
    Model.Morphs[0].Name := #$7B11#$3044;
    Model.Morphs[1].Name := #$7167#$308C;
    Model.Morphs[2].Name := #$307E#$3070#$305F#$304D;
    InitializeMorphWeights(Model, Weights);
    Weights[0] := 1.0;
    Weights[2] := 0.35;
    Encoded := EncodeMmdMorphSettingData(Model, Weights);
    if Pos(Model.Morphs[1].Name, Encoded) > 0 then
      raise Exception.Create('zero morph was serialized');
    if not TryDecodeMmdMorphSettingData(Encoded, Named) then
      raise Exception.Create('encoded morph setting was rejected');
    if Length(Named) <> 2 then
      raise Exception.Create('non-zero morph count was not preserved');
    if not ApplyMmdNamedMorphWeights(Model, Named, Resolved) then
      raise Exception.Create('resolved setting was reported as empty');
    CheckNear(Resolved[0], 1.0, 'codec first morph');
    CheckNear(Resolved[1], 0.0, 'codec omitted morph');
    CheckNear(Resolved[2], 0.35, 'codec second morph');
    if TryDecodeMmdMorphSettingData(
      '{"version":1,"morphs":[{"name":"x","weight":1.1}]}', Named) then
      raise Exception.Create('out-of-range morph weight was accepted');
    if TryDecodeMmdMorphSettingData(
      '{"version":1,"morphs":[{"name":"x","weight":1},' +
      '{"name":"X","weight":0.5}]}', Named) then
      raise Exception.Create('duplicate morph name was accepted');
  finally
    Model.Free;
  end;
end;

procedure TestEyeBlinkSetting;
var
  Data: string;
  Form: TForm;
  Model: TPmxModel;
  Panel: TMmdEyeBlinkSettingPanel;
  Setting: TMmdEyeBlinkSetting;
  Weights: TPmxMorphWeights;
begin
  Data := EncodeMmdEyeBlinkSettingData(#$307E#$3070#$305F#$304D, 0.65,
    5.5, 0.2, 1.25);
  if not TryDecodeMmdEyeBlinkSettingData(Data, Setting) or
    (Setting.MorphName <> #$307E#$3070#$305F#$304D) then
    raise Exception.Create('eye blink setting did not round-trip');
  CheckNear(Setting.ClosedWeight, 0.65, 'eye blink codec weight');
  CheckNear(Setting.IntervalSec, 5.5, 'eye blink codec interval');
  CheckNear(Setting.SpeedSec, 0.2, 'eye blink codec speed');
  CheckNear(Setting.OffsetSec, 1.25, 'eye blink codec offset');
  if not TryDecodeMmdEyeBlinkSettingData(
    '{"version":1,"morph":"blink","closedWeight":0.8}', Setting) then
    raise Exception.Create('legacy eye blink setting was not accepted');
  CheckNear(Setting.IntervalSec, 4.0, 'legacy eye blink default interval');
  CheckNear(Setting.SpeedSec, 0.1, 'legacy eye blink default speed');
  CheckNear(Setting.OffsetSec, 0.0, 'legacy eye blink default offset');
  if TryDecodeMmdEyeBlinkSettingData(
    '{"version":1,"morph":"","closedWeight":1}', Setting) then
    raise Exception.Create('none eye blink accepted a non-zero stage');

  Form := TForm.Create(nil);
  Model := TPmxModel.Create;
  try
    SetLength(Model.Morphs, 2);
    Model.Morphs[0].Name := #$307E#$3070#$305F#$304D;
    Model.Morphs[0].MorphType := pmtVertex;
    Model.Morphs[1].Name := #$7B11#$3044;
    Model.Morphs[1].MorphType := pmtVertex;
    Panel := TMmdEyeBlinkSettingPanel.Create(Form);
    Panel.Parent := Form;
    Panel.MatchParentFont;
    Panel.SetModel(Model);
    if (Panel.MorphCombo.Items.Count <> 3) or
      (Panel.MorphCombo.Items[0] <> #$306A#$3057) then
      raise Exception.Create('eye blink morph combo is invalid');
    Panel.MorphCombo.ItemIndex := 2;
    Panel.MorphCombo.OnChange(Panel.MorphCombo);
    CheckNear(Panel.ClosedWeight, 1.0, 'new combo eye blink selection stage');
    Panel.LoadSetting(#$307E#$3070#$305F#$304D, 0.35, 6.0, 0.25, -0.5);
    CheckNear(Panel.ClosedWeight, 0.35, 'restored eye blink stage');
    CheckNear(Panel.IntervalSec, 6.0, 'restored eye blink interval');
    CheckNear(Panel.SpeedSec, 0.25, 'restored eye blink speed');
    CheckNear(Panel.OffsetSec, -0.5, 'restored eye blink offset');
    Panel.CopyPreviewWeights(Weights);
    CheckNear(Weights[0], 0.35, 'eye blink preview selected morph');
    CheckNear(Weights[1], 0.0, 'eye blink preview unselected morph');
    Panel.MorphCombo.ItemIndex := 0;
    Panel.MorphCombo.OnChange(Panel.MorphCombo);
    CheckNear(Panel.ClosedWeight, 0.0, 'none eye blink stage');
    if Panel.StageTrack.Enabled then
      raise Exception.Create('none eye blink stage remains enabled');
  finally
    Model.Free;
    Form.Free;
  end;
end;

procedure TestLipSyncSetting;
var
  Data: string;
  Form: TForm;
  Model: TPmxModel;
  Panel: TMmdLipSyncSettingPanel;
  Saved, Setting: TMmdLipSyncSetting;
  Weights: TPmxMorphWeights;
begin
  Setting := DefaultMmdLipSyncSetting;
  Setting.Initialized := True;
  Setting.OpenClose.MorphName := 'open';
  Setting.OpenClose.Weight := 1.0;
  Setting.Phonemes[mlpA].MorphName := 'a';
  Setting.Phonemes[mlpA].Weight := 1.0;
  Setting.SpeedSec := 0.2;
  Setting.Strength := 0.75;
  Data := EncodeMmdLipSyncSettingData(Setting);
  if not TryDecodeMmdLipSyncSettingData(Data, Saved) then
    raise Exception.Create('lip sync setting did not round-trip');
  if not Saved.Initialized or (Saved.OpenClose.MorphName <> 'open') or
    (Saved.Phonemes[mlpA].MorphName <> 'a') then
    raise Exception.Create('lip sync morph names did not round-trip');
  CheckNear(Saved.OpenClose.Weight, 1.0, 'lip sync open stage');
  CheckNear(Saved.Phonemes[mlpA].Weight, 1.0, 'lip sync phoneme stage');
  CheckNear(Saved.SpeedSec, 0.2, 'lip sync speed');
  CheckNear(Saved.Strength, 0.75, 'lip sync strength');

  Data := StringReplace(Data, '"version":2,"initialized":true',
    '"version":1', []);
  if not TryDecodeMmdLipSyncSettingData(Data, Saved) or
    not Saved.Initialized then
    raise Exception.Create('configured lip sync version 1 migration failed');
  Data := EncodeMmdLipSyncSettingData(DefaultMmdLipSyncSetting);
  Data := StringReplace(Data, '"version":2,"initialized":false',
    '"version":1', []);
  if not TryDecodeMmdLipSyncSettingData(Data, Saved) or
    Saved.Initialized then
    raise Exception.Create('empty lip sync version 1 migration failed');

  Form := TForm.Create(nil);
  Model := TPmxModel.Create;
  try
    SetLength(Model.Morphs, 2);
    Model.Morphs[0].Name := 'open';
    Model.Morphs[0].MorphType := pmtVertex;
    Model.Morphs[1].Name := 'a';
    Model.Morphs[1].MorphType := pmtVertex;
    Panel := TMmdLipSyncSettingPanel.Create(Form);
    Panel.Parent := Form;
    Panel.MatchParentFont;
    Panel.SetModel(Model);
    Panel.LoadSetting(Setting);
    Panel.BuildSetting(Saved);
    if (Saved.OpenClose.MorphName <> 'open') or
      (Saved.Phonemes[mlpA].MorphName <> 'a') then
      raise Exception.Create('lip sync UI did not restore morphs');
    CheckNear(Saved.OpenClose.Weight, 1.0, 'lip sync UI fixed open stage');
    CheckNear(Saved.Phonemes[mlpA].Weight, 1.0,
      'lip sync UI fixed phoneme stage');
    Panel.PhonemeCombo(mlpA).OnChange(Panel.PhonemeCombo(mlpA));
    Panel.CopyPreviewWeights(Weights);
    CheckNear(Weights[0], 0.0, 'lip sync preview unselected morph');
    CheckNear(Weights[1], 1.0, 'lip sync preview selected morph');

    SetLength(Model.Morphs, 5);
    Model.Morphs[0].Name := #$3042;
    Model.Morphs[1].Name := #$3044;
    Model.Morphs[2].Name := #$3046;
    Model.Morphs[3].Name := #$3048;
    Model.Morphs[4].Name := #$304A;
    Model.Morphs[0].MorphType := pmtVertex;
    Model.Morphs[1].MorphType := pmtVertex;
    Model.Morphs[2].MorphType := pmtVertex;
    Model.Morphs[3].MorphType := pmtVertex;
    Model.Morphs[4].MorphType := pmtVertex;
    Panel.SetModel(Model);
    Panel.LoadSetting(DefaultMmdLipSyncSetting);
    Panel.BuildSetting(Saved);
    if not Saved.Initialized or
      (Saved.OpenClose.MorphName <> #$3042) or
      (Saved.Phonemes[mlpA].MorphName <> #$3042) or
      (Saved.Phonemes[mlpI].MorphName <> #$3044) or
      (Saved.Phonemes[mlpU].MorphName <> #$3046) or
      (Saved.Phonemes[mlpE].MorphName <> #$3048) or
      (Saved.Phonemes[mlpO].MorphName <> #$304A) or
      (Saved.Phonemes[mlpN].MorphName <> '') then
      raise Exception.Create('lip sync initial morph assignment is invalid');

    Setting := DefaultMmdLipSyncSetting;
    Setting.Initialized := True;
    Panel.LoadSetting(Setting);
    Panel.BuildSetting(Saved);
    if (Saved.OpenClose.MorphName <> '') or
      (Saved.Phonemes[mlpA].MorphName <> '') then
      raise Exception.Create('explicit lip sync none was not preserved');
  finally
    Model.Free;
    Form.Free;
  end;
end;

procedure TestLipSyncRuntime;
var
  Context: TMmdModelContext;
  Model: TPmxModel;
  Sample: TMmdLipSyncSample;
  Setting: TMmdLipSyncSetting;
begin
  if not TryParseMmdLipSyncTalkText(
    'lab=t0,t1,vol:65;lab_data=1;', 0.1, Sample) or
    (Sample.Kind <> mlskOpenClose) then
    raise Exception.Create('volume lip sync sample was not parsed');
  CheckNear(Sample.OpenAmount, 0.65, 'volume lip sync amount');
  if not TryParseMmdLipSyncTalkText(
    'lab=t0,t1,A;lab_data=1;', 0.1, Sample) or
    (Sample.Kind <> mlskPhoneme) or (Sample.Phoneme <> mlpA) then
    raise Exception.Create('phoneme lip sync sample was not parsed');
  if not TryParseMmdLipSyncTalkText('lab=;lab_data=1;', 0.1, Sample) or
    (Sample.Kind <> mlskOpenClose) or (Sample.OpenAmount <> 0) then
    raise Exception.Create('silent lip sync sample was not parsed');
  if not TryParseMmdLipSyncSongText(
    'note_AIUEO=I;note_lab=;', Sample) or
    (Sample.Kind <> mlskPhoneme) or (Sample.Phoneme <> mlpI) then
    raise Exception.Create('song lip sync sample was not parsed');
  if not TryParseMmdLipSyncTalkText(
    'aiueo=ai;frame=5;total_frames=10;speech_active=1;', 0.1,
    Sample) or (Sample.Kind <> mlskPhoneme) or
    (Sample.Phoneme <> mlpI) then
    raise Exception.Create('talk aiueo sample was not parsed');
  if not TryParseMmdLipSyncTalkText(
    'serif=test;frame=0;framerate=30;total_frames=30;speech_active=1;',
    0.1, Sample) or (Sample.Kind <> mlskOpenClose) or
    (Sample.OpenAmount <= 0) then
    raise Exception.Create('talk open-close fallback was not parsed');
  if not TryParseMmdLipSyncTalkText(
    'serif=test;frame=0;framerate=30;speech_active=0;', 0.1, Sample) or
    (Sample.Kind <> mlskOpenClose) or (Sample.OpenAmount <> 0) then
    raise Exception.Create('inactive talk sample did not close the mouth');

  Model := TPmxModel.Create;
  Context := TMmdModelContext.Create(High(Int64));
  try
    SetLength(Model.Morphs, 2);
    Model.Morphs[0].Name := 'open';
    Model.Morphs[1].Name := 'a';
    Setting := DefaultMmdLipSyncSetting;
    Setting.Initialized := True;
    Setting.OpenClose.MorphName := 'open';
    Setting.OpenClose.Weight := 1.0;
    Setting.Phonemes[mlpA].MorphName := 'a';
    Setting.Phonemes[mlpA].Weight := 0.8;
    Context.UpdateLipSync(EncodeMmdLipSyncSettingData(Setting));
    if not Context.ResolveLipSync(Model) then
      raise Exception.Create('lip sync morphs were not resolved');
    Sample.Kind := mlskOpenClose;
    Sample.OpenAmount := 0.5;
    if not Context.UpdateLipSyncWeights(Sample, True, 1, 30.0, 0.01,
      1.0) then
      raise Exception.Create('open-close lip sync was not activated');
    CheckNear(Context.LipSyncWeights[0], 0.5,
      'open-close lip sync weight');
    Sample.Kind := mlskPhoneme;
    Sample.Phoneme := mlpA;
    Context.UpdateLipSyncWeights(Sample, True, 2, 30.0, 0.01, 1.0);
    CheckNear(Context.LipSyncWeights[0], 0.0,
      'phoneme closes open-close morph');
    CheckNear(Context.LipSyncWeights[1], 0.8, 'phoneme lip sync weight');
  finally
    Context.Free;
    Model.Free;
  end;
end;

procedure TestEyeBlinkRuntime;
var
  Amount, Expected, MaxAmount: Single;
  EvenDurationReachedFull, OddDurationReachedFull: Boolean;
  F, BlinkFrame, SecondBlinkStart: Integer;
  SeedA, SeedB: UInt64;
  State, ShiftedState: TMmdEyeBlinkRuntimeState;
begin
  // Regression for the overflow-checked model filter build.
  SeedA := BuildMmdEyeBlinkSeed(High(Int64), High(Int64));
  SeedB := BuildMmdEyeBlinkSeed(High(Int64), High(Int64) - 1);
  if (SeedA = 0) or (SeedA = SeedB) then
    raise Exception.Create('eye blink object seed was not mixed');

  ResetMmdEyeBlinkState(State);
  MaxAmount := 0;
  BlinkFrame := -1;
  for F := 0 to 90 do
  begin
    Amount := CalculateMmdEyeBlinkAmount(F, 30.0, 1.0, 0.2, 0.0,
      12345, State);
    if Amount > MaxAmount then
      MaxAmount := Amount;
    if (BlinkFrame < 0) and (Amount > 0) then
      BlinkFrame := F;
  end;
  if (BlinkFrame < 0) or (MaxAmount < 0.8) then
    raise Exception.Create('eye blink runtime did not close the morph');

  EvenDurationReachedFull := False;
  OddDurationReachedFull := False;
  ResetMmdEyeBlinkState(State);
  for F := 0 to 120 do
  begin
    Amount := CalculateMmdEyeBlinkAmount(F, 60.0, 1.0, 0.1, 0.0,
      12345, State); // 6 frames
    EvenDurationReachedFull := EvenDurationReachedFull or
      SameValue(Amount, 1.0, 0.000001);
  end;
  ResetMmdEyeBlinkState(State);
  for F := 0 to 120 do
  begin
    Amount := CalculateMmdEyeBlinkAmount(F, 50.0, 1.0, 0.1, 0.0,
      12345, State); // 5 frames
    OddDurationReachedFull := OddDurationReachedFull or
      SameValue(Amount, 1.0, 0.000001);
  end;
  if not EvenDurationReachedFull or not OddDurationReachedFull then
    raise Exception.Create('eye blink did not reach 100 percent');

  // Run the first blink normally, then skip both peak frames of the second
  // blink as can happen during playback. The sampled result must still close
  // fully instead of turning back at a partial value.
  ResetMmdEyeBlinkState(State);
  CalculateMmdEyeBlinkAmount(0, 60.0, 1.0, 0.1, 0.0, 12345, State);
  for F := 1 to State.BlinkEnd + 1 do
    CalculateMmdEyeBlinkAmount(F, 60.0, 1.0, 0.1, 0.0, 12345, State);
  SecondBlinkStart := State.NextBlinkStart;
  CalculateMmdEyeBlinkAmount(SecondBlinkStart - 1, 60.0, 1.0, 0.1,
    0.0, 12345, State);
  Amount := CalculateMmdEyeBlinkAmount(SecondBlinkStart + 4, 60.0, 1.0,
    0.1, 0.0, 12345, State);
  CheckNear(Amount, 1.0, 'eye blink skipped second peak');

  ResetMmdEyeBlinkState(State);
  Expected := CalculateMmdEyeBlinkAmount(BlinkFrame, 30.0, 1.0, 0.2,
    0.0, 12345, State);
  Amount := CalculateMmdEyeBlinkAmount(BlinkFrame, 30.0, 1.0, 0.2,
    0.0, 12345, State);
  CheckNear(Amount, Expected, 'eye blink repeated frame');
  CalculateMmdEyeBlinkAmount(BlinkFrame + 100, 30.0, 1.0, 0.2,
    0.0, 12345, State);
  Amount := CalculateMmdEyeBlinkAmount(BlinkFrame, 30.0, 1.0, 0.2,
    0.0, 12345, State);
  CheckNear(Amount, Expected, 'eye blink rewind');

  ResetMmdEyeBlinkState(ShiftedState);
  Amount := CalculateMmdEyeBlinkAmount(BlinkFrame + 30, 30.0, 1.0, 0.2,
    1.0, 12345, ShiftedState);
  CheckNear(Amount, Expected, 'eye blink positive offset');
end;

procedure TestRealModel;
var
  FileNames: TArray<string>;
  BaseSkinned, MorphedSkinned: TPmxSkinnedVertices;
  BaseTransforms, MorphedTransforms: TPmxBoneTransforms;
  BonePoses: TPmxBonePoses;
  Delta, MaxDelta: Double;
  I, MovedCount: Integer;
  Model: TPmxModel;
  Weights: TPmxMorphWeights;
begin
  if ParamCount > 0 then
  begin
    SetLength(FileNames, 1);
    FileNames[0] := ParamStr(1);
  end
  else if not TDirectory.Exists(TPath.Combine(GetCurrentDir, 'Model')) then
  begin
    Writeln('Real model: SKIP (Model directory was not found)');
    Exit;
  end;
  if Length(FileNames) = 0 then
    FileNames := TDirectory.GetFiles(TPath.Combine(GetCurrentDir, 'Model'),
      '*.pmx', TSearchOption.soAllDirectories);
  if Length(FileNames) = 0 then
  begin
    Writeln('Real model: SKIP (Model directory has no PMX)');
    Exit;
  end;
  Model := GetCachedPmxModel(FileNames[0]);
  if Length(Model.Morphs) = 0 then
    raise Exception.Create('real PMX has no morphs');
  Writeln(Format('Real model: morphs=%d', [Length(Model.Morphs)]));
  InitializeBonePoses(Model, BonePoses);
  InitializeMorphWeights(Model, Weights);
  DeformPreviewModel(Model, BonePoses, Weights, BaseTransforms, BaseSkinned);
  MovedCount := 0;
  for I := 0 to High(Model.Morphs) do
    if IsPreviewMorphSupported(Model.Morphs[I].MorphType) then
    begin
      InitializeMorphWeights(Model, Weights);
      Weights[I] := 1.0;
      DeformPreviewModel(Model, BonePoses, Weights, MorphedTransforms,
        MorphedSkinned);
      MaxDelta := 0;
      for var VertexIndex := 0 to High(BaseSkinned) do
      begin
        Delta := Sqr(MorphedSkinned[VertexIndex].Position.X -
          BaseSkinned[VertexIndex].Position.X) +
          Sqr(MorphedSkinned[VertexIndex].Position.Y -
          BaseSkinned[VertexIndex].Position.Y) +
          Sqr(MorphedSkinned[VertexIndex].Position.Z -
          BaseSkinned[VertexIndex].Position.Z);
        MaxDelta := Max(MaxDelta, Sqrt(Delta));
      end;
      if MaxDelta > 0.000001 then
        Inc(MovedCount);
      Writeln(Format('%d'#9'%s'#9'type=%d'#9'max_delta=%.6f',
        [I, Model.Morphs[I].Name, Ord(Model.Morphs[I].MorphType), MaxDelta]));
    end;
  if MovedCount = 0 then
    raise Exception.Create('real PMX preview morphs did not move any vertex');
  Writeln(Format('Real model preview movers=%d', [MovedCount]));
end;

begin
  Application.Initialize;
  try
    TestMorphPanelCreation;
    Writeln('Morph preview panel creation: PASS');
    TestGroupedVertexAndBoneMorph;
    Writeln('Synthetic morph and preview deformation: PASS');
    TestMorphSettingCodec;
    Writeln('Morph setting codec: PASS');
    TestEyeBlinkSetting;
    TestEyeBlinkRuntime;
    TestLipSyncSetting;
    TestLipSyncRuntime;
    Writeln('Eye blink and lip sync setting, UI, and runtime: PASS');
    TestRealModel;
    Writeln('MmdMorphTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdMorphTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
