unit PmxCatalogGroupShortcut;

// ポーズ・表情一覧で共通する数字キーのグループ割り当て規則を提供する。

interface

uses
  System.Classes;

// 修飾なしの0～9またはテンキーを解釈し、0は解除用-1、1～9は0始まりのグループ番号を返す。
function TryPmxCatalogGroupShortcut(Key: Word; Shift: TShiftState;
  out GroupIndex: Integer): Boolean;

implementation

uses
  Winapi.Windows;

function TryPmxCatalogGroupShortcut(Key: Word; Shift: TShiftState;
  out GroupIndex: Integer): Boolean;
var
  Number: Integer;
begin
  Result := False;
  GroupIndex := -1;
  if Shift <> [] then
    Exit;
  if (Key >= Ord('0')) and (Key <= Ord('9')) then
    Number := Key - Ord('0')
  else if (Key >= VK_NUMPAD0) and (Key <= VK_NUMPAD9) then
    Number := Key - VK_NUMPAD0
  else
    Exit;
  if Number > 0 then
    GroupIndex := Number - 1;
  Result := True;
end;

end.
