unit MmdAiDiagnosticModel;

// MMD診断描画の材質・指分類を基に、D3Dプレビュー用の一時診断モデルを構築する。

interface

uses
  PmxModel;

type
  TMmdAiPreviewPass = (appNormal, appBones, appBoneOverlay, appSilhouette,
    appFingerId, appBodyOnly);

// 外部名を診断表示種別へ変換する。
function TryParsePreviewPass(const Name: string;
  out Pass: TMmdAiPreviewPass): Boolean;
// 通常・骨格表示ならnil、それ以外なら呼出し側が解放する一時モデルを返す。
function CreateDiagnosticModel(const Source: TPmxModel;
  Pass: TMmdAiPreviewPass; const FocusName: string = 'all'): TPmxModel;

implementation

uses
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils;

type
  TFingerGroup = (fgOther, fgLeftThumb, fgLeftIndex, fgLeftMiddle,
    fgLeftRing, fgLeftLittle, fgRightThumb, fgRightIndex, fgRightMiddle,
    fgRightRing, fgRightLittle);

function TryParsePreviewPass(const Name: string;
  out Pass: TMmdAiPreviewPass): Boolean;
begin
  Result := True;
  if SameText(Name, 'normal') then
    Pass := appNormal
  else if SameText(Name, 'bones') then
    Pass := appBones
  else if SameText(Name, 'bone_overlay') then
    Pass := appBoneOverlay
  else if SameText(Name, 'silhouette') then
    Pass := appSilhouette
  else if SameText(Name, 'finger_id') then
    Pass := appFingerId
  else if SameText(Name, 'body_only') then
    Pass := appBodyOnly
  else
    Result := False;
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

function IsFocusedHandBoneName(const BoneName, FocusName: string): Boolean;
var
  SideMatches: Boolean;
begin
  if SameText(FocusName, 'left_hand') then
    SideMatches := StartsText(#$5DE6, BoneName)
  else if SameText(FocusName, 'right_hand') then
    SideMatches := StartsText(#$53F3, BoneName)
  else
    SideMatches := StartsText(#$5DE6, BoneName) or
      StartsText(#$53F3, BoneName);
  Result := SideMatches and ContainsAny(BoneName,
    [#$624B#$9996, #$624B#$6369, #$89AA#$6307, #$4EBA#$6307,
     #$4E2D#$6307, #$85AC#$6307, #$5C0F#$6307, 'wrist', 'hand',
     'thumb', 'index', 'middle', 'ring', 'little', 'pinky']);
end;

function TriangleTouchesFocusedHand(const Model: TPmxModel;
  IndexOffset: Integer; const FocusName: string): Boolean;
var
  BoneIndex, InfluenceIndex, TriangleIndex, VertexIndex: Integer;
begin
  for TriangleIndex := 0 to 2 do
  begin
    VertexIndex := Model.Indices[IndexOffset + TriangleIndex];
    for InfluenceIndex := 0 to High(Model.Vertices[VertexIndex].BoneIndices) do
    begin
      BoneIndex := Model.Vertices[VertexIndex].BoneIndices[InfluenceIndex];
      if (BoneIndex >= 0) and (BoneIndex <= High(Model.Bones)) and
         (Model.Vertices[VertexIndex].BoneWeights[InfluenceIndex] > 0.0) and
         IsFocusedHandBoneName(Model.Bones[BoneIndex].Name, FocusName) then
        Exit(True);
    end;
  end;
  Result := False;
end;

function DominantFingerBoneName(const Model: TPmxModel;
  const Vertex: TPmxVertex): string;
var
  BoneIndex, Index: Integer;
  Weight: Single;
begin
  Result := '';
  Weight := -1.0;
  for Index := 0 to High(Vertex.BoneIndices) do
  begin
    BoneIndex := Vertex.BoneIndices[Index];
    if (BoneIndex >= 0) and (BoneIndex <= High(Model.Bones)) and
       IsFingerBoneName(Model.Bones[BoneIndex].Name) and
       (Vertex.BoneWeights[Index] > Weight) then
    begin
      Weight := Vertex.BoneWeights[Index];
      Result := Model.Bones[BoneIndex].Name;
    end;
  end;
end;

function FingerGroup(const BoneName: string): TFingerGroup;
var
  RightSide: Boolean;
begin
  Result := fgOther;
  if BoneName = '' then
    Exit;
  RightSide := ContainsAny(BoneName, [#$53F3, 'right']);
  if ContainsAny(BoneName, [#$89AA#$6307, 'thumb']) then
    if RightSide then Result := fgRightThumb else Result := fgLeftThumb
  else if ContainsAny(BoneName,
    [#$4EBA#$5DEE#$6307, #$4EBA#$6307, 'index']) then
    if RightSide then Result := fgRightIndex else Result := fgLeftIndex
  else if ContainsAny(BoneName, [#$4E2D#$6307, 'middle']) then
    if RightSide then Result := fgRightMiddle else Result := fgLeftMiddle
  else if ContainsAny(BoneName, [#$85AC#$6307, 'ring']) then
    if RightSide then Result := fgRightRing else Result := fgLeftRing
  else if ContainsAny(BoneName, [#$5C0F#$6307, 'little', 'pinky']) then
    if RightSide then Result := fgRightLittle else Result := fgLeftLittle;
end;

procedure FingerColor(Group: TFingerGroup; out Color: TPmxVector4);
var
  Brightness: Single;
begin
  Color.X := 0.48;
  Color.Y := 0.48;
  Color.Z := 0.48;
  Color.W := 1.0;
  case Group of
    fgLeftThumb, fgRightThumb:
      begin Color.X := 1.0; Color.Y := 0.12; Color.Z := 0.12; end;
    fgLeftIndex, fgRightIndex:
      begin Color.X := 1.0; Color.Y := 0.9; Color.Z := 0.05; end;
    fgLeftMiddle, fgRightMiddle:
      begin Color.X := 0.1; Color.Y := 0.95; Color.Z := 0.2; end;
    fgLeftRing, fgRightRing:
      begin Color.X := 0.15; Color.Y := 0.4; Color.Z := 1.0; end;
    fgLeftLittle, fgRightLittle:
      begin Color.X := 0.8; Color.Y := 0.15; Color.Z := 1.0; end;
  end;
  Brightness := 1.0;
  if Group >= fgRightThumb then
    Brightness := 0.65;
  Color.X := Color.X * Brightness;
  Color.Y := Color.Y * Brightness;
  Color.Z := Color.Z * Brightness;
end;

function CloneModel(const Source: TPmxModel): TPmxModel;
begin
  Result := TPmxModel.Create;
  Result.SourcePath := Source.SourcePath;
  Result.Name := Source.Name;
  Result.Vertices := Copy(Source.Vertices);
  Result.Indices := Copy(Source.Indices);
  Result.Textures := Copy(Source.Textures);
  Result.TextureAvailable := Copy(Source.TextureAvailable);
  Result.Materials := Copy(Source.Materials);
  Result.Bones := Copy(Source.Bones);
  Result.Morphs := Copy(Source.Morphs);
end;

procedure SetDiagnosticMaterial(var Material: TPmxMaterial;
  const Name: string; const Color: TPmxVector4; SurfaceStart,
  SurfaceCount: Integer);
begin
  Material := Default(TPmxMaterial);
  Material.Name := Name;
  Material.Diffuse := Color;
  Material.TextureIndex := -1;
  Material.SurfaceStart := SurfaceStart;
  Material.SurfaceCount := SurfaceCount;
end;

procedure BuildFlatModel(const Source: TPmxModel; Target: TPmxModel;
  BodyOnly: Boolean; const Color: TPmxVector4);
var
  ExplicitBodyNames: Boolean;
  IndexList: TList<Integer>;
  Material: TPmxMaterial;
  Offset: Integer;
begin
  ExplicitBodyNames := HasExplicitBodyMaterial(Source);
  IndexList := TList<Integer>.Create;
  try
    for Material in Source.Materials do
    begin
      if Material.Diffuse.W <= 0.0001 then
        Continue;
      if BodyOnly and not ShouldDrawBodyMaterial(Material,
        ExplicitBodyNames) then
        Continue;
      for Offset := 0 to Material.SurfaceCount - 1 do
        IndexList.Add(Source.Indices[Material.SurfaceStart + Offset]);
    end;
    Target.Indices := IndexList.ToArray;
  finally
    IndexList.Free;
  end;
  SetLength(Target.Materials, 1);
  SetDiagnosticMaterial(Target.Materials[0], 'diagnostic', Color, 0,
    Length(Target.Indices));
end;

function TriangleFingerGroup(const Model: TPmxModel; IndexOffset: Integer): TFingerGroup;
var
  Candidate: TFingerGroup;
  Index: Integer;
begin
  Result := fgOther;
  for Index := 0 to 2 do
  begin
    Candidate := FingerGroup(DominantFingerBoneName(Model,
      Model.Vertices[Model.Indices[IndexOffset + Index]]));
    if Candidate <> fgOther then
      Exit(Candidate);
  end;
end;

procedure BuildFingerModel(const Source: TPmxModel; Target: TPmxModel;
  const FocusName: string);
var
  Color: TPmxVector4;
  ExplicitBodyNames: Boolean;
  Group: TFingerGroup;
  Groups: array[TFingerGroup] of TList<Integer>;
  GroupStart: Integer;
  Material: TPmxMaterial;
  MaterialCount, MaterialIndex, Offset: Integer;
begin
  for Group := Low(TFingerGroup) to High(TFingerGroup) do
    Groups[Group] := TList<Integer>.Create;
  try
    ExplicitBodyNames := HasExplicitBodyMaterial(Source);
    for MaterialIndex := 0 to High(Source.Materials) do
    begin
      Material := Source.Materials[MaterialIndex];
      if (Material.Diffuse.W <= 0.0001) or
         not ShouldDrawBodyMaterial(Material, ExplicitBodyNames) then
        Continue;
      Offset := 0;
      while Offset + 2 < Material.SurfaceCount do
      begin
        if not SameText(FocusName, 'all') and
           not TriangleTouchesFocusedHand(Source,
             Material.SurfaceStart + Offset, FocusName) then
        begin
          Inc(Offset, 3);
          Continue;
        end;
        Group := TriangleFingerGroup(Source, Material.SurfaceStart + Offset);
        Groups[Group].Add(Source.Indices[Material.SurfaceStart + Offset]);
        Groups[Group].Add(Source.Indices[Material.SurfaceStart + Offset + 1]);
        Groups[Group].Add(Source.Indices[Material.SurfaceStart + Offset + 2]);
        Inc(Offset, 3);
      end;
    end;
    Target.Indices := nil;
    SetLength(Target.Materials, Succ(Ord(High(TFingerGroup))));
    MaterialCount := 0;
    GroupStart := 0;
    for Group := Low(TFingerGroup) to High(TFingerGroup) do
    begin
      if Groups[Group].Count = 0 then
        Continue;
      for Offset in Groups[Group] do
      begin
        SetLength(Target.Indices, Length(Target.Indices) + 1);
        Target.Indices[High(Target.Indices)] := Offset;
      end;
      FingerColor(Group, Color);
      SetDiagnosticMaterial(Target.Materials[MaterialCount],
        'finger_' + IntToStr(Ord(Group)), Color, GroupStart,
        Groups[Group].Count);
      Inc(GroupStart, Groups[Group].Count);
      Inc(MaterialCount);
    end;
    SetLength(Target.Materials, MaterialCount);
  finally
    for Group := Low(TFingerGroup) to High(TFingerGroup) do
      Groups[Group].Free;
  end;
end;

function CreateDiagnosticModel(const Source: TPmxModel;
  Pass: TMmdAiPreviewPass; const FocusName: string): TPmxModel;
var
  Color: TPmxVector4;
begin
  Result := nil;
  if Pass in [appNormal, appBones, appBoneOverlay] then
    Exit;
  Result := CloneModel(Source);
  try
    Result.Textures := nil;
    Result.TextureAvailable := nil;
    if Pass = appFingerId then
      BuildFingerModel(Source, Result, FocusName)
    else
    begin
      Color.W := 1.0;
      if Pass = appBodyOnly then
      begin
        Color.X := 1.0;
        Color.Y := 0.72;
        Color.Z := 0.48;
        BuildFlatModel(Source, Result, True, Color);
      end
      else
      begin
        Color.X := 0.92;
        Color.Y := 0.96;
        Color.Z := 1.0;
        BuildFlatModel(Source, Result, False, Color);
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
