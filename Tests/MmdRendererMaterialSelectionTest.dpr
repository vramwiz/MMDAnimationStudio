program MmdRendererMaterialSelectionTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxMorph in '..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxBoneSolver in '..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  MmdAiDiagnosticState in '..\AviUtl2PluginLib\MMD\AI\MmdAiDiagnosticState.pas',
  MMD_Model_MaterialSelection in 'Source\Plugin\Model\Render\MMD_Model_MaterialSelection.pas',
  MMD_Model_DiagnosticRenderer in 'Source\Plugin\Model\Render\MMD_Model_DiagnosticRenderer.pas',
  MMD_Model_Renderer in 'Source\Plugin\Model\Render\MMD_Model_Renderer.pas';

procedure SetMaterialCounts(Model: TPmxModel; const Counts: array of Integer);
var
  I: Integer;
begin
  SetLength(Model.Materials, Length(Counts));
  for I := 0 to High(Counts) do
    Model.Materials[I].SurfaceCount := Counts[I];
end;

procedure CheckAllMaterialsAreSelected;
var
  DrawOrder: TArray<Integer>;
  I: Integer;
  Model: TPmxModel;
begin
  Model := TPmxModel.Create;
  try
    SetMaterialCounts(Model, [3000, 3000, 3000, 3000, 3000, 3000,
      3000, 3000, 3000, 3000, 3000, 3000]);
    DrawOrder := BuildPmxMaterialDrawOrder(Model);
    if Length(DrawOrder) <> 12 then
      raise Exception.Create('low polygon model did not select all materials');
    for I := 0 to High(DrawOrder) do
      if DrawOrder[I] <> I then
        raise Exception.CreateFmt('material %d was omitted', [I]);
  finally
    Model.Free;
  end;
end;

procedure CheckLargeModelFallback;
var
  DrawOrder: TArray<Integer>;
  Model: TPmxModel;
begin
  Model := TPmxModel.Create;
  try
    SetMaterialCounts(Model, [20000, 20000, 20000, 20000, 20000, 20000,
      20000, 20000, 20000, 20000, 20000, 20000, 20000, 20000, 20000]);
    DrawOrder := BuildPmxMaterialDrawOrder(Model);
    if Length(DrawOrder) >= Length(Model.Materials) then
      raise Exception.Create('large model did not use the fallback order');
    if (Length(DrawOrder) < 9) or (DrawOrder[5] <> 5) or
      (DrawOrder[6] <> 6) or (DrawOrder[7] <> 12) then
      raise Exception.Create('fallback material priority changed');
  finally
    Model.Free;
  end;
end;

procedure CheckKiritanFallbackKeepsConnectedArms;
const
  MATERIAL_COUNTS: array[0..42] of Integer = (
    1512, 24720, 4692, 32076, 720, 3456, 3456, 33564, 6048, 16032,
    9216, 1152, 2784, 13440, 20220, 9072, 7008, 1512, 1512, 1512,
    1512, 1512, 1512, 1512, 1512, 13368, 13368, 5760, 10992, 9102,
    40284, 1152, 480, 576, 13788, 17544, 22032, 23352, 7056, 1848,
    5748, 12012, 15060);
var
  DrawOrder: TArray<Integer>;
  Found: array[0..42] of Boolean;
  I, SelectedVertexCount: Integer;
  Model: TPmxModel;
begin
  Model := TPmxModel.Create;
  try
    SetMaterialCounts(Model, MATERIAL_COUNTS);
    DrawOrder := BuildPmxMaterialDrawOrder(Model);
    SelectedVertexCount := 0;
    for I in DrawOrder do
    begin
      Found[I] := True;
      Inc(SelectedVertexCount, MATERIAL_COUNTS[I]);
    end;
    if not Found[5] or not Found[6] then
      raise Exception.Create('fallback omitted one side of the hair');
    if not Found[36] or not Found[38] or not Found[39] then
      raise Exception.Create('fallback separated the hand from the arm');
    if not Found[10] or Found[8] then
      raise Exception.Create('fallback omitted the accessory toggle target');
    if Found[13] then
      raise Exception.Create('weapon metal displaced a body material');
    if SelectedVertexCount > 262144 then
      raise Exception.Create('fallback exceeded the AviUtl2 vertex limit');
  finally
    Model.Free;
  end;
end;

procedure CheckVisibleMaterialMorphTargetsAreSelected;
const
  MATERIAL_COUNTS: array[0..42] of Integer = (
    1512, 24720, 4692, 32076, 720, 3456, 3456, 33564, 6048, 16032,
    9216, 1152, 2784, 13440, 20220, 9072, 7008, 1512, 1512, 1512,
    1512, 1512, 1512, 1512, 1512, 13368, 13368, 5760, 10992, 9102,
    40284, 1152, 480, 576, 13788, 17544, 22032, 23352, 7056, 1848,
    5748, 12012, 15060);
var
  DrawOrder: TArray<Integer>;
  Found: array[0..42] of Boolean;
  I, SelectedVertexCount: Integer;
  Model: TPmxModel;
  Resolved: TArray<TPmxMaterial>;
begin
  Model := TPmxModel.Create;
  try
    SetMaterialCounts(Model, MATERIAL_COUNTS);
    for I := 0 to High(Model.Materials) do
      Model.Materials[I].Diffuse.W := 1.0;
    Model.Materials[38].Diffuse.W := 0.0;
    Model.Materials[40].Diffuse.W := 0.0;
    Model.Materials[42].Diffuse.W := 0.0;
    Resolved := Copy(Model.Materials);
    // 袖切替で通常トップ・靴・武器が消え、別袖材質が現れた状態を模擬する。
    Resolved[9].Diffuse.W := 0.0;
    Resolved[10].Diffuse.W := 0.0;
    Resolved[14].Diffuse.W := 0.0;
    Resolved[38].Diffuse.W := 1.0;
    Resolved[40].Diffuse.W := 1.0;
    Resolved[42].Diffuse.W := 1.0;
    DrawOrder := SelectResolvedPmxMaterialDrawOrder(Model, Resolved);
    SelectedVertexCount := 0;
    for I in DrawOrder do
    begin
      Found[I] := True;
      if Resolved[I].Diffuse.W > 0.0001 then
        Inc(SelectedVertexCount, MATERIAL_COUNTS[I]);
    end;
    if not Found[38] or not Found[40] or not Found[42] then
      raise Exception.Create('visible material morph target was omitted');
    if SelectedVertexCount > 262144 then
      raise Exception.Create('resolved material order exceeded vertex limit');
  finally
    Model.Free;
  end;
end;

begin
  try
    CheckAllMaterialsAreSelected;
    CheckLargeModelFallback;
    CheckKiritanFallbackKeepsConnectedArms;
    CheckVisibleMaterialMorphTargetsAreSelected;
    Writeln('MmdRendererMaterialSelectionTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
