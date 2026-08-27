unit MMD_Model_DiagnosticRenderer;

// AIが骨格、指、シルエットを判別するための非永続な診断描画を担当する。

interface

uses
  AviUtl2FilterTypes,
  MmdAiDiagnosticState,
  PmxModel,
  PmxPose;

// 指定されたAI診断モードでモデルを描画する。
procedure RenderPmxDiagnostic(Video: PFILTER_PROC_VIDEO; const Model: TPmxModel;
  const Transforms: TPmxBoneTransforms; const Skinned: TPmxSkinnedVertices;
  UseSkinning: Boolean; Mode: TMmdAiDiagnosticMode; InternalScale: Single);

implementation

uses
  System.Math,
  System.StrUtils,
  System.SysUtils,
  MMD_Model_MaterialSelection;

type
  TDiagnosticVertices = array of TVERTEX_COLOR_NORM;
  TBoneVertices = array of TVERTEX_COLOR;

const
  WHITE_PIXEL: TPIXEL_RGBA = (R: 255; G: 255; B: 255; A: 255);

threadvar
  DiagnosticVertices: TDiagnosticVertices;
  DiagnosticBones: TBoneVertices;

function SourceIndexOffset(ExpandedOffset: Integer): Integer;
begin
  case ExpandedOffset mod 3 of
    0: Result := ExpandedOffset;
    1: Result := ExpandedOffset + 1;
  else
    Result := ExpandedOffset - 1;
  end;
end;

procedure SetPosition(var X, Y, Z: Single; const Value: TPmxVector3;
  Scale: Single);
begin
  X := Value.X * Scale;
  Y := -Value.Y * Scale;
  Z := Value.Z * Scale;
end;

procedure SetNormal(var X, Y, Z: Single; const Value: TPmxVector3);
begin
  X := Value.X;
  Y := -Value.Y;
  Z := Value.Z;
end;

function ContainsAny(const Text: string; const Values: array of string): Boolean;
var
  Value: string;
begin
  for Value in Values do
    if ContainsText(Text, Value) then
      Exit(True);
  Result := False;
end;

function IsBodyMaterialName(const Name: string): Boolean;
begin
  Result := ContainsAny(Name, ['skin', 'body', 'face', 'hand', 'arm', 'leg',
    #$808C, #$4F53, #$9854, #$624B, #$8155, #$8DB3, #$811A]);
end;

function IsExcludedBodyOnlyMaterial(const Name: string): Boolean;
begin
  Result := ContainsAny(Name, ['hair', 'cloth', 'dress', 'skirt', 'shirt',
    'sleeve', 'shoe', 'boot', 'ribbon', 'accessory', #$9AEA, #$670D, #$8863,
    #$8896, #$30B9#$30AB#$30FC#$30C8, #$9774, #$30EA#$30DC#$30F3]);
end;

function HasExplicitBodyMaterial(const Model: TPmxModel): Boolean;
var
  Material: TPmxMaterial;
begin
  for Material in Model.Materials do
    if IsBodyMaterialName(Material.Name) then
      Exit(True);
  Result := False;
end;

function ShouldDrawBodyMaterial(const Material: TPmxMaterial;
  ExplicitBodyNames: Boolean): Boolean;
begin
  if IsExcludedBodyOnlyMaterial(Material.Name) then
    Exit(False);
  Result := not ExplicitBodyNames or IsBodyMaterialName(Material.Name);
end;

function IsFingerBoneName(const Name: string): Boolean;
begin
  Result := ContainsAny(Name, [#$89AA#$6307, #$4EBA#$5DEE#$6307,
    #$4EBA#$6307, #$4E2D#$6307, #$85AC#$6307, #$5C0F#$6307,
    'thumb', 'index', 'middle', 'ring', 'little', 'pinky']);
end;

function DominantFingerBoneName(const Model: TPmxModel;
  const Vertex: TPmxVertex): string;
var
  BoneIndex, I: Integer;
  Weight: Single;
begin
  Result := '';
  Weight := -1.0;
  for I := 0 to High(Vertex.BoneIndices) do
  begin
    BoneIndex := Vertex.BoneIndices[I];
    if (BoneIndex >= 0) and (BoneIndex <= High(Model.Bones)) and
       IsFingerBoneName(Model.Bones[BoneIndex].Name) and
       (Vertex.BoneWeights[I] > Weight) then
    begin
      Weight := Vertex.BoneWeights[I];
      Result := Model.Bones[BoneIndex].Name;
    end;
  end;
end;

procedure FingerColor(const BoneName: string; out R, G, B: Single);
var
  Brightness: Single;
begin
  R := 0.48;
  G := 0.48;
  B := 0.48;
  if ContainsAny(BoneName, [#$89AA#$6307, 'thumb']) then
  begin
    R := 1.0; G := 0.12; B := 0.12;
  end
  else if ContainsAny(BoneName, [#$4EBA#$5DEE#$6307, #$4EBA#$6307, 'index']) then
  begin
    R := 1.0; G := 0.9; B := 0.05;
  end
  else if ContainsAny(BoneName, [#$4E2D#$6307, 'middle']) then
  begin
    R := 0.1; G := 0.95; B := 0.2;
  end
  else if ContainsAny(BoneName, [#$85AC#$6307, 'ring']) then
  begin
    R := 0.15; G := 0.4; B := 1.0;
  end
  else if ContainsAny(BoneName, [#$5C0F#$6307, 'little', 'pinky']) then
  begin
    R := 0.8; G := 0.15; B := 1.0;
  end;
  Brightness := 1.0;
  if ContainsAny(BoneName, [#$53F3, 'right']) then
    Brightness := 0.65;
  R := R * Brightness;
  G := G * Brightness;
  B := B * Brightness;
end;

procedure GetGeometry(const Model: TPmxModel;
  const Skinned: TPmxSkinnedVertices; SourceIndex: Integer;
  UseSkinning: Boolean; out Position, Normal: TPmxVector3);
begin
  if UseSkinning then
  begin
    Position := Skinned[SourceIndex].Position;
    Normal := Skinned[SourceIndex].Normal;
  end
  else
  begin
    Position := Model.Vertices[SourceIndex].Position;
    Normal := Model.Vertices[SourceIndex].Normal;
  end;
end;

procedure BuildMaterialVertices(const Model: TPmxModel;
  const Material: TPmxMaterial; const Skinned: TPmxSkinnedVertices;
  UseSkinning: Boolean; Mode: TMmdAiDiagnosticMode; Scale: Single);
var
  BoneName: string;
  ExpandedOffset, SourceIndex: Integer;
  Normal, Position: TPmxVector3;
  R, G, B: Single;
begin
  SetLength(DiagnosticVertices, Material.SurfaceCount);
  for ExpandedOffset := 0 to Material.SurfaceCount - 1 do
  begin
    SourceIndex := Model.Indices[Material.SurfaceStart +
      SourceIndexOffset(ExpandedOffset)];
    GetGeometry(Model, Skinned, SourceIndex, UseSkinning, Position, Normal);
    SetPosition(DiagnosticVertices[ExpandedOffset].X,
      DiagnosticVertices[ExpandedOffset].Y,
      DiagnosticVertices[ExpandedOffset].Z, Position, Scale);
    if Mode = madFingerId then
    begin
      BoneName := DominantFingerBoneName(Model, Model.Vertices[SourceIndex]);
      FingerColor(BoneName, R, G, B);
    end
    else if Mode = madBodyOnly then
    begin
      R := 1.0; G := 0.72; B := 0.48;
    end
    else
    begin
      R := 0.92; G := 0.96; B := 1.0;
    end;
    DiagnosticVertices[ExpandedOffset].R := R;
    DiagnosticVertices[ExpandedOffset].G := G;
    DiagnosticVertices[ExpandedOffset].B := B;
    DiagnosticVertices[ExpandedOffset].A := 1.0;
    SetNormal(DiagnosticVertices[ExpandedOffset].VX,
      DiagnosticVertices[ExpandedOffset].VY,
      DiagnosticVertices[ExpandedOffset].VZ, Normal);
  end;
end;

procedure DrawDiagnosticModel(Video: PFILTER_PROC_VIDEO; const Model: TPmxModel;
  const Skinned: TPmxSkinnedVertices; UseSkinning: Boolean;
  Mode: TMmdAiDiagnosticMode; Scale: Single);
var
  DrawOrder: TArray<Integer>;
  DrawOrderIndex: Integer;
  ExplicitBodyNames: Boolean;
  MaterialIndex: Integer;
begin
  ExplicitBodyNames := HasExplicitBodyMaterial(Model);
  DrawOrder := SelectPmxMaterialDrawOrder(Model);
  for DrawOrderIndex := 0 to High(DrawOrder) do
  begin
    MaterialIndex := DrawOrder[DrawOrderIndex];
    if (Model.Materials[MaterialIndex].SurfaceCount <= 0) or
       (Model.Materials[MaterialIndex].Diffuse.W <= 0.0001) then
      Continue;
    if (Mode in [madBodyOnly, madFingerId]) and
       not ShouldDrawBodyMaterial(Model.Materials[MaterialIndex],
         ExplicitBodyNames) then
      Continue;
    BuildMaterialVertices(Model, Model.Materials[MaterialIndex], Skinned,
      UseSkinning, Mode, Scale);
    Video^.DrawPoly(VERTEX_TYPE_TRIANGLE_COLOR_NORM, @DiagnosticVertices[0],
      Length(DiagnosticVertices), 'object');
  end;
end;

procedure AddBoneTriangle(const A, B: TPmxVector3; Scale: Single;
  R, G, Blue: Single; var Index: Integer);
var
  AX, AY, AZ, BX, BY, BZ, DX, DY, DZ, L, PX, PY, PZ: Single;
begin
  SetPosition(AX, AY, AZ, A, Scale);
  SetPosition(BX, BY, BZ, B, Scale);
  DX := BX - AX; DY := BY - AY; DZ := BZ - AZ;
  L := Sqrt(DX * DX + DY * DY + DZ * DZ);
  if L < 0.0001 then
    Exit;
  DX := DX / L; DY := DY / L; DZ := DZ / L;
  if Abs(DZ) < 0.9 then
  begin
    PX := DY; PY := -DX; PZ := 0.0;
  end
  else
  begin
    PX := -DZ; PY := 0.0; PZ := DX;
  end;
  L := Sqrt(PX * PX + PY * PY + PZ * PZ);
  PX := PX / L * Max(0.75, Scale * 0.1);
  PY := PY / L * Max(0.75, Scale * 0.1);
  PZ := PZ / L * Max(0.75, Scale * 0.1);
  DiagnosticBones[Index].X := AX - PX;
  DiagnosticBones[Index].Y := AY - PY;
  DiagnosticBones[Index].Z := AZ - PZ;
  DiagnosticBones[Index + 1].X := AX + PX;
  DiagnosticBones[Index + 1].Y := AY + PY;
  DiagnosticBones[Index + 1].Z := AZ + PZ;
  DiagnosticBones[Index + 2].X := BX;
  DiagnosticBones[Index + 2].Y := BY;
  DiagnosticBones[Index + 2].Z := BZ;
  DiagnosticBones[Index].R := R;
  DiagnosticBones[Index].G := G;
  DiagnosticBones[Index].B := Blue;
  DiagnosticBones[Index].A := 1.0;
  DiagnosticBones[Index + 1] := DiagnosticBones[Index];
  DiagnosticBones[Index + 1].X := AX + PX;
  DiagnosticBones[Index + 1].Y := AY + PY;
  DiagnosticBones[Index + 1].Z := AZ + PZ;
  DiagnosticBones[Index + 2] := DiagnosticBones[Index];
  DiagnosticBones[Index + 2].X := BX;
  DiagnosticBones[Index + 2].Y := BY;
  DiagnosticBones[Index + 2].Z := BZ;
  Inc(Index, 3);
end;

procedure DrawDiagnosticBones(Video: PFILTER_PROC_VIDEO; const Model: TPmxModel;
  const Transforms: TPmxBoneTransforms; UsePose: Boolean; Scale: Single);
var
  BoneIndex, Index: Integer;
  ChildPosition, ParentPosition: TPmxVector3;
begin
  SetLength(DiagnosticBones, Length(Model.Bones) * 3);
  Index := 0;
  for BoneIndex := 0 to High(Model.Bones) do
  begin
    if Model.Bones[BoneIndex].ParentIndex < 0 then
      Continue;
    if UsePose then
    begin
      ChildPosition := Transforms[BoneIndex].Position;
      ParentPosition := Transforms[Model.Bones[BoneIndex].ParentIndex].Position;
    end
    else
    begin
      ChildPosition := Model.Bones[BoneIndex].Position;
      ParentPosition := Model.Bones[Model.Bones[BoneIndex].ParentIndex].Position;
    end;
    if StartsText(#$5DE6, Model.Bones[BoneIndex].Name) then
      AddBoneTriangle(ParentPosition, ChildPosition, Scale, 0.1, 0.45, 1.0, Index)
    else if StartsText(#$53F3, Model.Bones[BoneIndex].Name) then
      AddBoneTriangle(ParentPosition, ChildPosition, Scale, 1.0, 0.2, 0.15, Index)
    else
      AddBoneTriangle(ParentPosition, ChildPosition, Scale, 1.0, 0.85, 0.1, Index);
  end;
  SetLength(DiagnosticBones, Index);
  if Index > 0 then
    Video^.DrawPoly(VERTEX_TYPE_TRIANGLE_COLOR, @DiagnosticBones[0], Index,
      'object');
end;

procedure RenderPmxDiagnostic(Video: PFILTER_PROC_VIDEO; const Model: TPmxModel;
  const Transforms: TPmxBoneTransforms; const Skinned: TPmxSkinnedVertices;
  UseSkinning: Boolean; Mode: TMmdAiDiagnosticMode; InternalScale: Single);
begin
  if Assigned(Video^.SetSamplerMode) then
    Video^.SetSamplerMode(SAMPLER_MODE_LOOP);
  if Assigned(Video^.SetImageData) then
    Video^.SetImageData(@WHITE_PIXEL, 1, 1);
  if Assigned(Video^.SetCullingState) then
    Video^.SetCullingState(0);
  if Assigned(Video^.SetMaterialShine) then
    Video^.SetMaterialShine(0.0);
  if Mode = madBones then
    DrawDiagnosticBones(Video, Model, Transforms, UseSkinning, InternalScale)
  else
  begin
    DrawDiagnosticModel(Video, Model, Skinned, UseSkinning, Mode, InternalScale);
    if Mode = madBoneOverlay then
      DrawDiagnosticBones(Video, Model, Transforms, UseSkinning, InternalScale);
  end;
end;

end.
