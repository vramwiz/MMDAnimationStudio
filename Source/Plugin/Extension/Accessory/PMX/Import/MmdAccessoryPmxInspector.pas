unit MmdAccessoryPmxInspector;

// PMXを非キャッシュで解析し、アクセサリ表示に必要な形状とボーン数を診断する。

interface

type
  TMmdAccessoryPmxInspection = record
    // 描画可否判定と依存ファイル保管に必要なPMX診断結果を保持する。
    BoneCount: Integer;
    MaterialCount: Integer;
    TextureFiles: TArray<string>;
    VertexCount: Integer;
  end;

// PMX全体を既存Readerで検証し、描画可能な形状がある場合だけ診断値を返す。
function InspectMmdAccessoryPmx(const FileName: string;
  out Inspection: TMmdAccessoryPmxInspection): Boolean;

implementation

uses
  PmxModel,
  PmxReader;

function InspectMmdAccessoryPmx(const FileName: string;
  out Inspection: TMmdAccessoryPmxInspection): Boolean;
var
  Model: TPmxModel;
begin
  Result := False;
  Inspection := Default(TMmdAccessoryPmxInspection);
  Model := nil;
  try
    try
      Model := LoadPmxModel(FileName);
      Inspection.VertexCount := Length(Model.Vertices);
      Inspection.MaterialCount := Length(Model.Materials);
      Inspection.BoneCount := Length(Model.Bones);
      Inspection.TextureFiles := Copy(Model.Textures);
      Result := (Inspection.VertexCount > 0) and
        (Length(Model.Indices) > 0) and (Inspection.MaterialCount > 0);
    except
      Inspection := Default(TMmdAccessoryPmxInspection);
    end;
  finally
    Model.Free;
  end;
end;

end.
