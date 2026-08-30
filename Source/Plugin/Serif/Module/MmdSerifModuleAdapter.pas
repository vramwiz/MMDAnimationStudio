unit MmdSerifModuleAdapter;

// AviUtl2 Script Module ABIのUTF-8引数をDelphi文字列へ安全に変換する。

interface

uses
  MmdSerifModuleTypes;

// Paramの文字列引数をUTF-8として読み取る。未設定や範囲外相当のnilでは空文字列を返す。
function MmdModuleParamString(Param: PMMD_SCRIPT_MODULE_PARAM;
  Index: Integer): string;

implementation

uses
  System.SysUtils;

function MmdModuleParamString(Param: PMMD_SCRIPT_MODULE_PARAM;
  Index: Integer): string;
var
  Value: PAnsiChar;
begin
  Result := '';
  if (Param = nil) or not Assigned(Param^.GetParamString) then
    Exit;
  Value := Param^.GetParamString(Index);
  if Value <> nil then
    Result := UTF8ToString(UTF8String(Value));
end;

end.
