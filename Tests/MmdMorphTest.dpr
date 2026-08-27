program MmdMorphTest;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.Math,
  System.SysUtils,
  Vcl.ComCtrls,
  Vcl.Forms,
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
  MmdD3DDeform in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DDeform.pas',
  MmdMorphPreviewPanel in '..\AviUtl2PluginLib\MMD\Editor\MmdMorphPreviewPanel.pas';

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
  Track: TTrackBar;
  Weights: TPmxMorphWeights;
begin
  Form := TForm.Create(nil);
  Model := TPmxModel.Create;
  try
    SetLength(Model.Morphs, 1);
    Model.Morphs[0].Name := 'test';
    Model.Morphs[0].MorphType := pmtVertex;
    Panel := TMmdMorphPreviewPanel.Create(Form);
    Panel.Parent := Form;
    Panel.SetModel(Model);
    Track := nil;
    for I := 0 to Panel.ComponentCount - 1 do
      if Panel.Components[I] is TTrackBar then
        Track := TTrackBar(Panel.Components[I]);
    if Track = nil then
      raise Exception.Create('morph preview track bar was not found');
    Track.Position := 100;
    Panel.CopyWeights(Weights);
    CheckNear(Weights[0], 1.0, 'morph preview track weight');
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
