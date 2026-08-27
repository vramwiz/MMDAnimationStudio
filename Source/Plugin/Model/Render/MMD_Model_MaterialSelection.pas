unit MMD_Model_MaterialSelection;

// AviUtl2の頂点キュー上限内で描画するPMX材質順を共通決定する。

interface

uses
  PmxModel;

// 全材質が上限内ならPMX順、大型モデルなら検証済み主要材質順を返す。
function SelectPmxMaterialDrawOrder(const Model: TPmxModel;
  ReservedVertexCount: Integer = 0): TArray<Integer>;

implementation

uses
  System.Math;

const
  KIRITAN_CORE_MATERIAL_ORDER: array[0..20] of Integer = (
    0, 1, 2, 3, 4, 6, 12, 14, 15, 16, 28, 29, 30, 34, 35, 36, 9, 8, 11,
    13, 32);
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

end.
