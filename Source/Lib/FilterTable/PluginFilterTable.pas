unit PluginFilterTable;

// AviUtl2 Filterテーブルと設定項目の順次登録を一か所で管理する。
// MMD配下の複数Filterプロジェクトから共通利用する。

interface

uses
  AviUtl2FilterTypes;

// 登録中のテーブルを初期化する。既存の設定項目は破棄される。
procedure SetupPluginTable(Flag: Integer; Name, Label_, Information: PWideChar;
  VideoProc: TFuncProcVideo; AudioProc: TFuncProcAudio);
// AviUtl2オブジェクトの生成・破棄通知を現在のテーブルへ設定する。
procedure SetFilterLifecycle(CreateProc: TFuncCreate; DestroyProc: TFuncDestroy);
// 以下のAdd系手続きは呼出順に項目を登録し、AviUtl2へ渡すnil終端配列を更新する。
procedure AddFile(var Item: TFILTER_ITEM_FILE; Name, Value, FileFilter: PWideChar);
procedure AddButton(var Item: TFILTER_ITEM_BUTTON; Name: PWideChar;
  Callback: TFilterItemButtonCallback);
procedure AddString(var Item: TFILTER_ITEM_STRING; Name, Value: PWideChar);
procedure AddColor(var Item: TFILTER_ITEM_COLOR; Name: PWideChar;
  B, G, R: Byte; X: Byte = 255);
procedure AddTrack(var Item: TFILTER_ITEM_TRACK; Name: PWideChar;
  Value, S, E, Step: Double);
procedure AddCheck(var Item: TFILTER_ITEM_CHECK; Name: PWideChar; Value: Byte);
procedure AddSelect(var Item: TFILTER_ITEM_SELECT; Name: PWideChar;
  Value: Integer; List: Pointer);
procedure AddGroup(var Item: TFILTER_ITEM_GROUP; Name: PWideChar;
  DefaultVisible: Byte);

procedure AddFilterItem(var Item: TFILTER_ITEM_TRACK); overload;
procedure AddFilterItem(var Item: TFILTER_ITEM_CHECK); overload;
procedure AddFilterItem(var Item: TFILTER_ITEM_GROUP); overload;
procedure AddFilterItem(var Item: TFILTER_ITEM_SELECT); overload;
procedure AddFilterItem(var Item: TFILTER_ITEM_COLOR); overload;

// 構築済みテーブルの静的領域を返す。DLLが有効な間だけ参照できる。
function GetPluginTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  System.SysUtils;

const
  MAX_GUI_ITEMS = 100;

var
  GTable: TFILTER_PLUGIN_TABLE;
  GItems: array[0..MAX_GUI_ITEMS - 1] of Pointer;
  GItemIndex: Integer;

procedure RegisterItem(Item: Pointer);
begin
  // 最後の1要素はAviUtl2が要求するnil終端用に予約する。
  if GItemIndex >= High(GItems) then
    raise ERangeError.CreateFmt(
      'Filter setting item count exceeds the limit (%d)',
      [High(GItems)]);
  GItems[GItemIndex] := Item;
  Inc(GItemIndex);
  GItems[GItemIndex] := nil;
end;

procedure SetupPluginTable(Flag: Integer; Name, Label_, Information: PWideChar;
  VideoProc: TFuncProcVideo; AudioProc: TFuncProcAudio);
begin
  GItemIndex := 0;
  FillChar(GItems, SizeOf(GItems), 0);
  GTable.Flag := Flag;
  GTable.Name := Name;
  GTable.Label_ := Label_;
  GTable.Information := Information;
  GTable.Items := @GItems[0];
  GTable.Func_Proc_Video := VideoProc;
  GTable.Func_Proc_Audio := AudioProc;
  GTable.Func_Create := nil;
  GTable.Func_Destroy := nil;
end;

procedure SetFilterLifecycle(CreateProc: TFuncCreate; DestroyProc: TFuncDestroy);
begin
  GTable.Func_Create := CreateProc;
  GTable.Func_Destroy := DestroyProc;
end;

procedure AddFile(var Item: TFILTER_ITEM_FILE; Name, Value, FileFilter: PWideChar);
begin
  Item.ItemType := 'file';
  Item.Name := Name;
  Item.Value := Value;
  Item.FileFilter := FileFilter;
  RegisterItem(@Item);
end;

procedure AddButton(var Item: TFILTER_ITEM_BUTTON; Name: PWideChar;
  Callback: TFilterItemButtonCallback);
begin
  Item.ItemType := 'button';
  Item.Name := Name;
  Item.Callback := Callback;
  RegisterItem(@Item);
end;

procedure AddString(var Item: TFILTER_ITEM_STRING; Name, Value: PWideChar);
begin
  Item.ItemType := 'string';
  Item.Name := Name;
  Item.Value := Value;
  RegisterItem(@Item);
end;

procedure AddColor(var Item: TFILTER_ITEM_COLOR; Name: PWideChar;
  B, G, R, X: Byte);
begin
  Item.ItemType := 'color';
  Item.Name := Name;
  Item.B := B;
  Item.G := G;
  Item.R := R;
  Item.X := X;
  RegisterItem(@Item);
end;

procedure AddTrack(var Item: TFILTER_ITEM_TRACK; Name: PWideChar;
  Value, S, E, Step: Double);
begin
  Item.ItemType := 'track';
  Item.Name := Name;
  Item.Value := Value;
  Item.S := S;
  Item.E := E;
  Item.Step := Step;
  RegisterItem(@Item);
end;

procedure AddCheck(var Item: TFILTER_ITEM_CHECK; Name: PWideChar; Value: Byte);
begin
  Item.ItemType := 'check';
  Item.Name := Name;
  Item.Value := Value;
  RegisterItem(@Item);
end;

procedure AddSelect(var Item: TFILTER_ITEM_SELECT; Name: PWideChar;
  Value: Integer; List: Pointer);
begin
  Item.ItemType := 'select';
  Item.Name := Name;
  Item.Value := Value;
  Item.List := List;
  RegisterItem(@Item);
end;

procedure AddGroup(var Item: TFILTER_ITEM_GROUP; Name: PWideChar;
  DefaultVisible: Byte);
begin
  Item.ItemType := 'group';
  Item.Name := Name;
  Item.DefaultVisible := DefaultVisible;
  RegisterItem(@Item);
end;

procedure AddFilterItem(var Item: TFILTER_ITEM_TRACK);
begin
  RegisterItem(@Item);
end;

procedure AddFilterItem(var Item: TFILTER_ITEM_CHECK);
begin
  RegisterItem(@Item);
end;

procedure AddFilterItem(var Item: TFILTER_ITEM_GROUP);
begin
  RegisterItem(@Item);
end;

procedure AddFilterItem(var Item: TFILTER_ITEM_SELECT);
begin
  RegisterItem(@Item);
end;

procedure AddFilterItem(var Item: TFILTER_ITEM_COLOR);
begin
  RegisterItem(@Item);
end;

function GetPluginTable: PFILTER_PLUGIN_TABLE;
begin
  Result := @GTable;
end;

end.
