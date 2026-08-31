unit MmdSerifModuleAdapter;

// AviUtl2 Script Module ABIのUTF-8引数をDelphi文字列へ安全に変換する。

interface

uses
  MmdSerifModuleTypes;

// Paramの文字列引数をUTF-8として読み取る。未設定や範囲外相当のnilでは空文字列を返す。
function MmdModuleParamString(Param: PMMD_SCRIPT_MODULE_PARAM;
  Index: Integer): string;
// Scriptのobj.idを共有メモリとキャッシュ用の安定した64bit識別子へ変換する。
function MmdModuleObjectID(const Value: string): Int64;

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

function MmdModuleObjectID(const Value: string): Int64;
var
  Character: Char;
  Hash: UInt64;
begin
  if TryStrToInt64(Value, Result) and (Result <> 0) then Exit;
  Hash := $9E3779B97F4A7C15;
  for Character in Value do
  begin
    Hash := (Hash shl 5) or (Hash shr 59);
    Hash := Hash xor Ord(Character);
  end;
  if Hash = 0 then Hash := 1;
  Result := Int64(Hash);
end;

end.
