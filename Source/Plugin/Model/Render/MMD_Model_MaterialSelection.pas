unit MMD_Model_MaterialSelection;

// AviUtl2の頂点キュー上限内で描画するPMX材質順を共通決定する。

interface

uses
  PmxModel;

// 全材質が上限内ならPMX順、大型モデルなら検証済み主要材質順を返す。
function SelectPmxMaterialDrawOrder(const Model: TPmxModel;
  ReservedVertexCount: Integer = 0): TArray<Integer>;
// 基本材質の選択を維持し、モーフで新たに現れた材質だけを空き枠へ加える。
function SelectResolvedPmxMaterialDrawOrder(const Model: TPmxModel;
  const ResolvedMaterials: TArray<TPmxMaterial>;
  ReservedVertexCount: Integer = 0): TArray<Integer>;

implementation

uses
  System.Math;

const
  KIRITAN_CORE_MATERIAL_ORDER: array[0..22] of Integer = (
    0, 1, 2, 3, 4, 5, 6, 12, 14, 15, 16, 28, 29, 30, 34, 35, 36, 38, 39,
    9, 10, 11, 32);
  AVIUTL2_POLYGON_VERTEX_LIMIT = 262144;

function SelectPmxMaterialDrawOrder(const Model: TPmxModel;
  ReservedVertexCount: Integer): TArray<Integer>;
var
  I, MaterialIndex, ResultCount: Integer;
  RequiredVertexCount: Int64;
begin
  RequiredVertexCount := Max(0, ReservedVertexCount);
  for I := 0 to High(Model.Materials) do
    Inc(RequiredVertexCount, Max(0, Model.Materials[I].SurfaceCount));
  if RequiredVertexCount <= AVIUTL2_POLYGON_VERTEX_LIMIT then
  begin
    SetLength(Result, Length(Model.Materials));
    for I := 0 to High(Result) do
      Result[I] := I;
    Exit;
  end;
  SetLength(Result, Length(KIRITAN_CORE_MATERIAL_ORDER));
  ResultCount := 0;
  for I := 0 to High(KIRITAN_CORE_MATERIAL_ORDER) do
  begin
    MaterialIndex := KIRITAN_CORE_MATERIAL_ORDER[I];
    if MaterialIndex > High(Model.Materials) then
      Continue;
    Result[ResultCount] := MaterialIndex;
    Inc(ResultCount);
  end;
  SetLength(Result, ResultCount);
end;

function SelectResolvedPmxMaterialDrawOrder(const Model: TPmxModel;
  const ResolvedMaterials: TArray<TPmxMaterial>;
  ReservedVertexCount: Integer): TArray<Integer>;
const
  ALPHA_EPSILON = 0.0001;
var
  Added: TArray<Boolean>;
  BaseSelected: TArray<Boolean>;
  I, MaterialIndex, ResultCount: Integer;
  BaseRequiredVertexCount, BaseUsedVertexCount: Int64;
  RequiredVertexCount, UsedVertexCount: Int64;

  procedure MarkBase(MaterialIndex: Integer);
  var
    VertexCount: Integer;
  begin
    if (MaterialIndex < 0) or (MaterialIndex > High(Model.Materials)) or
      BaseSelected[MaterialIndex] then
      Exit;
    VertexCount := 0;
    if Model.Materials[MaterialIndex].Diffuse.W > ALPHA_EPSILON then
      VertexCount := Max(0, Model.Materials[MaterialIndex].SurfaceCount);
    if BaseUsedVertexCount + VertexCount > AVIUTL2_POLYGON_VERTEX_LIMIT then
      Exit;
    BaseSelected[MaterialIndex] := True;
    Inc(BaseUsedVertexCount, VertexCount);
  end;

  procedure TryAdd(MaterialIndex: Integer);
  var
    VertexCount: Integer;
  begin
    if (MaterialIndex < 0) or (MaterialIndex > High(Model.Materials)) or
      Added[MaterialIndex] then
      Exit;
    VertexCount := 0;
    if (MaterialIndex <= High(ResolvedMaterials)) and
      (ResolvedMaterials[MaterialIndex].Diffuse.W > ALPHA_EPSILON) then
      VertexCount := Max(0, Model.Materials[MaterialIndex].SurfaceCount);
    if UsedVertexCount + VertexCount > AVIUTL2_POLYGON_VERTEX_LIMIT then
      Exit;
    Added[MaterialIndex] := True;
    Result[ResultCount] := MaterialIndex;
    Inc(ResultCount);
    Inc(UsedVertexCount, VertexCount);
  end;

begin
  if Length(ResolvedMaterials) <> Length(Model.Materials) then
    Exit(SelectPmxMaterialDrawOrder(Model, ReservedVertexCount));
  BaseRequiredVertexCount := Max(0, ReservedVertexCount);
  RequiredVertexCount := Max(0, ReservedVertexCount);
  for I := 0 to High(Model.Materials) do
  begin
    if Model.Materials[I].Diffuse.W > ALPHA_EPSILON then
      Inc(BaseRequiredVertexCount, Max(0, Model.Materials[I].SurfaceCount));
    if ResolvedMaterials[I].Diffuse.W > ALPHA_EPSILON then
      Inc(RequiredVertexCount, Max(0, Model.Materials[I].SurfaceCount));
  end;
  if (BaseRequiredVertexCount <= AVIUTL2_POLYGON_VERTEX_LIMIT) and
    (RequiredVertexCount <= AVIUTL2_POLYGON_VERTEX_LIMIT) then
  begin
    SetLength(Result, Length(Model.Materials));
    for I := 0 to High(Result) do
      Result[I] := I;
    Exit;
  end;

  // 元から大きいモデルでは、非表示化で空いた枠に無関係な目や衣装を
  // 後から追加すると見た目が変わる。通常時の選択集合を固定する。
  SetLength(BaseSelected, Length(Model.Materials));
  BaseUsedVertexCount := Max(0, ReservedVertexCount);
  if BaseRequiredVertexCount <= AVIUTL2_POLYGON_VERTEX_LIMIT then
    for MaterialIndex := 0 to High(Model.Materials) do
      BaseSelected[MaterialIndex] := True
  else
  begin
    for I := 0 to High(KIRITAN_CORE_MATERIAL_ORDER) do
      MarkBase(KIRITAN_CORE_MATERIAL_ORDER[I]);
    for MaterialIndex := 0 to High(Model.Materials) do
      if Model.Materials[MaterialIndex].Diffuse.W > ALPHA_EPSILON then
        MarkBase(MaterialIndex);
  end;

  SetLength(Result, Length(Model.Materials));
  SetLength(Added, Length(Model.Materials));
  ResultCount := 0;
  UsedVertexCount := Max(0, ReservedVertexCount);
  for I := 0 to High(KIRITAN_CORE_MATERIAL_ORDER) do
    TryAdd(KIRITAN_CORE_MATERIAL_ORDER[I]);

  // 表示モーフで透明材質から現れた袖や衣装等を、固定順だけで落とさない。
  for MaterialIndex := 0 to High(Model.Materials) do
    if (Model.Materials[MaterialIndex].Diffuse.W <= ALPHA_EPSILON) and
      (ResolvedMaterials[MaterialIndex].Diffuse.W > ALPHA_EPSILON) then
      TryAdd(MaterialIndex);

  // 元から表示対象だった材質をPMX順で追加する。透明化で空いた枠を
  // 無関係な材質で埋めず、装飾品のON/OFFで目の重なりを変えない。
  for MaterialIndex := 0 to High(Model.Materials) do
    if BaseSelected[MaterialIndex] then
      TryAdd(MaterialIndex);
  SetLength(Result, ResultCount);
end;

end.
