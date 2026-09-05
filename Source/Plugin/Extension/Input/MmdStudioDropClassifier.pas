unit MmdStudioDropClassifier;

// 拡張画面へ届いたファイル群を、表示ページを変更せず受理できる形式へ分類する。

interface

type
  TMmdStudioDropKind = (mdkPmx, mdkVpd, mdkVmd);
  TMmdStudioDropKinds = set of TMmdStudioDropKind;

// ファイル拡張子とフォルダ内容を調べ、PMX・VPD・VMDの存在を返す。読めないフォルダは無視する。
function ClassifyMmdStudioDropFiles(const Files: TArray<string>): TMmdStudioDropKinds;

implementation

uses
  System.IOUtils,
  System.SysUtils;

function ClassifyMmdStudioDropFiles(const Files: TArray<string>): TMmdStudioDropKinds;
var
  FileName: string;
begin
  Result := [];
  for FileName in Files do
    if SameText(ExtractFileExt(FileName), '.pmx') then
      Include(Result, mdkPmx)
    else if SameText(ExtractFileExt(FileName), '.vmd') then
      Include(Result, mdkVmd)
    else if SameText(ExtractFileExt(FileName), '.vpd') then
      Include(Result, mdkVpd)
    else if TDirectory.Exists(FileName) then
      try
        if Length(TDirectory.GetFiles(FileName, '*.vpd',
          TSearchOption.soAllDirectories)) > 0 then
          Include(Result, mdkVpd);
        if Length(TDirectory.GetFiles(FileName, '*.vmd',
          TSearchOption.soAllDirectories)) > 0 then
          Include(Result, mdkVmd);
      except
        // 読取り失敗はImporter側の失敗集計へ任せ、分類処理から例外を出さない。
      end;
end;

end.
