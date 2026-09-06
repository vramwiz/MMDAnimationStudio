program MmdModelSettingsSessionTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  AviUtl2FilterTypes,
  MMD_Model_SettingsButton,
  MmdModelSettingEditor,
  MmdMorphSettingList,
  MmdMorphSettingRows,
  PmxModel;

type
  TListAccess = class(TMmdMorphSettingList);
  TControlAccess = class(TControl);
  TSettingsAccess = class(TMmdModelSettingEditorForm)
  public
    procedure ExerciseMaterialMorph;
  end;
  TDriver = class
  public
    Timer: TTimer;
    CloseWithButton: Boolean;
    Failure: string;
    procedure Tick(Sender: TObject);
  end;

var
  InEditSection, Edited: Boolean;
  Writes: Integer;
  ModelPath, PoseValue, FaceValue: UTF8String;
  ExpectedFace: string;

procedure Check(Value: Boolean; const Message_: string);
begin
  if not Value then raise Exception.Create(Message_);
end;

function FocusObject: OBJECT_HANDLE; cdecl;
begin
  Result := Pointer(1);
end;

function GetItem(Obj: OBJECT_HANDLE; Effect, Item: PWideChar): PAnsiChar; cdecl;
begin
  Result := nil;
  if string(Item) = 'モデルファイル' then Result := PAnsiChar(ModelPath);
  if string(Item) = 'ポーズ' then Result := PAnsiChar(PoseValue);
  if string(Item) = '表情' then Result := PAnsiChar(FaceValue);
end;

function SetItem(Obj: OBJECT_HANDLE; Effect, Item: PWideChar;
  Value: PAnsiChar): LongBool; cdecl;
begin
  Check(InEditSection, 'host write outside edit section');
  Check(Edited, 'host write occurred during editing');
  Check(Obj = Pointer(1), 'target object changed');
  Check(string(Effect) = 'モデル表示', 'wrong effect');
  Inc(Writes);
  if string(Item) = 'ポーズ' then PoseValue := UTF8String(Value);
  if string(Item) = '表情' then FaceValue := UTF8String(Value);
  Result := True;
end;

procedure TSettingsAccess.ExerciseMaterialMorph;
var
  Rows: TMmdMorphSettingRows;
  I, TargetRow, TargetIndex: Integer;
  Key: Word;
  List: TListAccess;
  BeforeData: string;
begin
  ModeToolbar.Buttons[Ord(mspExpression)].Click;
  BeforeData := EncodeExpression;
  BuildMorphSettingRows(FModel, Rows);
  TargetRow := -1;
  TargetIndex := -1;
  for I := 0 to High(Rows) do
    if (Rows[I].Kind = msrkMorph) and
      (FModel.Morphs[Rows[I].MorphIndex].MorphType = pmtMaterial) then
    begin
      TargetRow := I;
      TargetIndex := Rows[I].MorphIndex;
      Break;
    end;
  Check(TargetRow >= 0, 'model has no material morph');
  List := TListAccess(FMorphPreview.ListControl);
  for I := 0 to TargetIndex - 1 do
  begin
    Key := VK_DOWN;
    List.KeyDown(Key, []);
  end;
  Key := VK_RIGHT;
  List.KeyDown(Key, []);
  // MouseUpが呼ぶ編集終了通知から、保留プレビューと表情変更通知を通す。
  List.OnEditFinished(List);
  Check(EncodeExpression <> BeforeData, 'material morph did not turn on');
  Key := VK_LEFT;
  List.KeyDown(Key, []);
  List.OnEditFinished(List);
  Check(EncodeExpression = BeforeData, 'material morph did not turn off');
  Key := VK_RIGHT;
  List.KeyDown(Key, []);
  List.OnEditFinished(List);
  ExpectedFace := EncodeExpression;
  Check(Writes = 0, 'host was written before dialog completion');
  Edited := True;
end;

procedure TDriver.Tick(Sender: TObject);
var
  I: Integer;
  Form: TSettingsAccess;
begin
  Timer.Enabled := False;
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I] is TMmdModelSettingEditorForm then
    begin
      Form := TSettingsAccess(Screen.Forms[I]);
      try
        Check(InEditSection, 'button callback returned before dialog closed');
        Form.ExerciseMaterialMorph;
      except
        on E: Exception do Failure := E.Message;
      end;
      if CloseWithButton then TControlAccess(Form.SaveButton).Click else Form.Close;
      Exit;
    end;
  Failure := 'settings dialog missing';
end;

procedure Run(CloseWithButton: Boolean);
var
  Edit: TEDIT_SECTION;
  Driver: TDriver;
begin
  Writes := 0;
  Edited := False;
  PoseValue := '{"version":1,"bones":[]}';
  FaceValue := '{"version":1,"morphs":[]}';
  Edit := Default(TEDIT_SECTION);
  Edit.GetFocusObject := FocusObject;
  Edit.GetObjectItemValue := GetItem;
  Edit.SetObjectItemValue := SetItem;
  Driver := TDriver.Create;
  try
    Driver.CloseWithButton := CloseWithButton;
    Driver.Timer := TTimer.Create(nil);
    Driver.Timer.Interval := 300;
    Driver.Timer.OnTimer := Driver.Tick;
    InEditSection := True;
    try
      ModelSettingsButtonCallback(@Edit);
    finally
      InEditSection := False;
    end;
    Check(Driver.Failure = '', Driver.Failure);
    Check(Edited, 'modal edit was not completed');
    Check(Writes = 2, 'pose and expression were not both saved');
    Check(UTF8ToString(FaceValue) = ExpectedFace, 'saved expression mismatch');
    Writeln('PASS: material on/off/on, scoped writes, close button=', CloseWithButton);
  finally
    Driver.Timer.Free;
    Driver.Free;
  end;
end;

begin
  Application.Initialize;
  try
    Check(ParamCount = 1, 'Supply a PMX containing a material morph');
    ModelPath := UTF8String(ParamStr(1));
    Run(True);
    Run(False);
  except
    on E: Exception do
    begin
      Writeln('FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
