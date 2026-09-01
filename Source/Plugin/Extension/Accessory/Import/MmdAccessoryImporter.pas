unit MmdAccessoryImporter;

// PMXとOBJの専用Importerを同じドロップ受付と集計へ統合する。

interface

uses
  MmdAccessoryCatalog,
  MmdAccessoryPmxImporter;

// 入力をPMX／OBJの各Importerへ渡し、両形式の登録結果を1件の集計へまとめる。
function ImportMmdAccessoryFiles(const Inputs: TArray<string>;
  Catalog: TMmdAccessoryCatalog;
  out Summary: TMmdAccessoryPmxImportSummary): Boolean;

implementation

uses
  MmdAccessoryObjImporter;

procedure AddSummary(var Target: TMmdAccessoryPmxImportSummary;
  const Source: TMmdAccessoryPmxImportSummary);
begin
  Inc(Target.Added, Source.Added);
  Inc(Target.AlreadyRegistered, Source.AlreadyRegistered);
  Inc(Target.Failed, Source.Failed);
  Inc(Target.MissingDependencies, Source.MissingDependencies);
  Inc(Target.Scanned, Source.Scanned);
  Inc(Target.WithBones, Source.WithBones);
  Inc(Target.WithoutBones, Source.WithoutBones);
  if Source.LastAccessoryId <> '' then
    Target.LastAccessoryId := Source.LastAccessoryId;
end;

function ImportMmdAccessoryFiles(const Inputs: TArray<string>;
  Catalog: TMmdAccessoryCatalog;
  out Summary: TMmdAccessoryPmxImportSummary): Boolean;
var
  Part: TMmdAccessoryPmxImportSummary;
begin
  Summary := Default(TMmdAccessoryPmxImportSummary);
  ImportMmdAccessoryPmxFiles(Inputs, Catalog, Part);
  AddSummary(Summary, Part);
  ImportMmdAccessoryObjFiles(Inputs, Catalog, Part);
  AddSummary(Summary, Part);
  Result := (Summary.Added > 0) or (Summary.AlreadyRegistered > 0);
end;

end.
