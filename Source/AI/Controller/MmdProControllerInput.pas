unit MmdProControllerInput;

// Switch Pro Controller の HID 入力を非同期に読み取る。

interface

uses System.SysUtils, Winapi.Windows;

const
  ProButtonB = 1; ProButtonA = 2; ProButtonY = 3; ProButtonX = 4;
  ProButtonL = 5; ProButtonR = 6; ProButtonZL = 7; ProButtonZR = 8;
  ProButtonMinus = 9; ProButtonPlus = 10;
  ProButtonLeftStick = 11; ProButtonRightStick = 12;

type
  TMmdProPadState = record
    LeftX, LeftY, RightX, RightY: Single;
    Buttons: Cardinal;
    POV: Cardinal;
    function Down(ButtonNumber: Integer): Boolean;
  end;

  TMmdProControllerInput = class
  private
    FHandle, FEvent: THandle;
    FOverlapped: TOverlapped;
    FPending, FHaveReport: Boolean;
    FReportLength: Cardinal;
    FBuffer: TBytes;
    FState: TMmdProPadState;
    FPressedButtons, FPressedPOV: Cardinal;
    FLastSearch: UInt64;
    FDevicePath: string;
    FOutputReportLength: Word;
    FFullModeEnabled: Boolean;
    procedure CloseDevice;
    function OpenDevice: Boolean;
    function StartRead: Boolean;
    function SetReportMode(const Path: string; OutputLength: Word;
      Mode: Byte): Boolean;
    procedure DecodeReport(Count: Cardinal);
    function GetConnected: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Poll(out State: TMmdProPadState): Boolean;
    function ProbeConnection: Boolean;
    procedure Disconnect;
    property Connected: Boolean read GetConnected;
  end;

implementation

uses System.Math;

const
  HidInterfaceGuid: TGUID = '{4D1E55B2-F16F-11CF-88CB-001111000030}';
  DigcfPresent = $02;
  DigcfDeviceInterface = $10;

type
  THidAttributes = record
    Size: Cardinal;
    VendorID, ProductID, VersionNumber: Word;
  end;
  THidCaps = record
    Usage, UsagePage, InputReportByteLength, OutputReportByteLength,
      FeatureReportByteLength: Word;
    Reserved: array[0..16] of Word;
    Remaining: array[0..9] of Word;
  end;
  TDeviceInterfaceData = record
    cbSize: Cardinal;
    InterfaceClassGuid: TGUID;
    Flags: Cardinal;
    Reserved: NativeUInt;
  end;

function SetupDiGetClassDevsW(ClassGuid: PGUID; Enumerator: PWideChar;
  hwndParent: HWND; Flags: Cardinal): THandle; stdcall; external 'setupapi.dll';
function SetupDiEnumDeviceInterfaces(DeviceInfoSet: THandle; DeviceInfoData: Pointer;
  InterfaceClassGuid: PGUID; MemberIndex: Cardinal;
  var DeviceInterfaceData: TDeviceInterfaceData): BOOL; stdcall; external 'setupapi.dll';
function SetupDiGetDeviceInterfaceDetailW(DeviceInfoSet: THandle;
  var DeviceInterfaceData: TDeviceInterfaceData; DeviceInterfaceDetailData: Pointer;
  DeviceInterfaceDetailDataSize: Cardinal; RequiredSize: PCardinal;
  DeviceInfoData: Pointer): BOOL; stdcall; external 'setupapi.dll';
function SetupDiDestroyDeviceInfoList(DeviceInfoSet: THandle): BOOL;
  stdcall; external 'setupapi.dll';
function HidD_GetAttributes(HidDeviceObject: THandle;
  var Attributes: THidAttributes): BOOL; stdcall; external 'hid.dll';
function HidD_GetPreparsedData(HidDeviceObject: THandle;
  var PreparsedData: Pointer): BOOL; stdcall; external 'hid.dll';
function HidD_FreePreparsedData(PreparsedData: Pointer): BOOL;
  stdcall; external 'hid.dll';
function HidP_GetCaps(PreparsedData: Pointer; var Capabilities: THidCaps): Longint;
  stdcall; external 'hid.dll';

function TMmdProPadState.Down(ButtonNumber: Integer): Boolean;
begin
  Result := (ButtonNumber >= 1) and (ButtonNumber <= 32) and
    ((Buttons and (Cardinal(1) shl (ButtonNumber - 1))) <> 0);
end;

constructor TMmdProControllerInput.Create;
begin
  inherited Create;
  FHandle := INVALID_HANDLE_VALUE;
  FState.POV := $FFFF;
  FPressedPOV := $FFFF;
end;

destructor TMmdProControllerInput.Destroy;
begin
  CloseDevice;
  inherited;
end;

procedure TMmdProControllerInput.CloseDevice;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    if FPending then
    begin
      CancelIoEx(FHandle, @FOverlapped);
      WaitForSingleObject(FEvent, 1000);
    end;
    // 自分で変更した入力方式だけを、Windowsの通常HID方式へ戻す。
    if FFullModeEnabled then
      SetReportMode(FDevicePath, FOutputReportLength, $3F);
    CloseHandle(FHandle);
  end;
  if FEvent <> 0 then CloseHandle(FEvent);
  FHandle := INVALID_HANDLE_VALUE;
  FEvent := 0;
  FPending := False;
  FHaveReport := False;
  FState := Default(TMmdProPadState);
  FState.POV := $FFFF;
  FPressedButtons := 0;
  FPressedPOV := $FFFF;
  FBuffer := nil;
  FDevicePath := '';
  FOutputReportLength := 0;
  FFullModeEnabled := False;
end;

function TMmdProControllerInput.SetReportMode(const Path: string;
  OutputLength: Word; Mode: Byte): Boolean;
var
  WriteHandle: THandle;
  Output: TBytes;
  Written: Cardinal;
begin
  Result := False;
  if (Path = '') or (OutputLength < 12) or (OutputLength > 4096) then Exit;
  WriteHandle := CreateFileW(PWideChar(Path), GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  if WriteHandle = INVALID_HANDLE_VALUE then Exit;
  try
    SetLength(Output, OutputLength);
    FillChar(Output[0], OutputLength, 0);
    Output[0] := $01;
    // 無振動のペイロードを付けて、入力レポート方式を変更する。
    Output[3] := $01; Output[4] := $40; Output[5] := $40;
    Output[7] := $01; Output[8] := $40; Output[9] := $40;
    Output[10] := $03;
    Output[11] := Mode;
    Written := 0;
    Result := WriteFile(WriteHandle, Output[0], OutputLength, Written, nil) and
      (Written = OutputLength);
  finally
    CloseHandle(WriteHandle);
  end;
end;

function TMmdProControllerInput.OpenDevice: Boolean;
var
  DeviceSet, Candidate: THandle;
  Data: TDeviceInterfaceData;
  Detail: TBytes;
  Attr: THidAttributes;
  Caps: THidCaps;
  Prep: Pointer;
  Needed, Index: Cardinal;
begin
  Result := False;
  DeviceSet := SetupDiGetClassDevsW(@HidInterfaceGuid, nil, 0,
    DigcfPresent or DigcfDeviceInterface);
  if DeviceSet = INVALID_HANDLE_VALUE then Exit;
  try
    Index := 0;
    while True do
    begin
      FillChar(Data, SizeOf(Data), 0);
      Data.cbSize := SizeOf(Data);
      if not SetupDiEnumDeviceInterfaces(DeviceSet, nil, @HidInterfaceGuid,
        Index, Data) then Break;
      Inc(Index);
      Needed := 0;
      SetupDiGetDeviceInterfaceDetailW(DeviceSet, Data, nil, 0, @Needed, nil);
      if Needed < 8 then Continue;
      SetLength(Detail, Needed);
      PCardinal(@Detail[0])^ := 8; // Win64 の detail.cbSize
      if not SetupDiGetDeviceInterfaceDetailW(DeviceSet, Data, @Detail[0],
        Needed, nil, nil) then Continue;
      Candidate := CreateFileW(PWideChar(@Detail[4]), GENERIC_READ,
        FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING,
        FILE_FLAG_OVERLAPPED, 0);
      if Candidate = INVALID_HANDLE_VALUE then Continue;
      FillChar(Attr, SizeOf(Attr), 0);
      Attr.Size := SizeOf(Attr);
      if not HidD_GetAttributes(Candidate, Attr) or
        (Attr.VendorID <> $057E) or (Attr.ProductID <> $2009) then
      begin
        CloseHandle(Candidate);
        Continue;
      end;
      Prep := nil;
      FillChar(Caps, SizeOf(Caps), 0);
      if not HidD_GetPreparsedData(Candidate, Prep) then
      begin
        CloseHandle(Candidate);
        Continue;
      end;
      try
        if HidP_GetCaps(Prep, Caps) < 0 then
        begin
          CloseHandle(Candidate);
          Continue;
        end;
      finally
        HidD_FreePreparsedData(Prep);
      end;
      if (Caps.InputReportByteLength < 12) or
        (Caps.InputReportByteLength > 4096) then
      begin
        CloseHandle(Candidate);
        Continue;
      end;
      FEvent := CreateEvent(nil, True, False, nil);
      if FEvent = 0 then
      begin
        CloseHandle(Candidate);
        Continue;
      end;
      FHandle := Candidate;
      FReportLength := Caps.InputReportByteLength;
      SetLength(FBuffer, FReportLength);
      FDevicePath := PWideChar(@Detail[4]);
      FOutputReportLength := Caps.OutputReportByteLength;
      FFullModeEnabled := SetReportMode(FDevicePath,
        FOutputReportLength, $30);
      if StartRead then Exit(True);
      CloseDevice;
    end;
  finally
    SetupDiDestroyDeviceInfoList(DeviceSet);
  end;
end;

function TMmdProControllerInput.StartRead: Boolean;
var Count: Cardinal;
begin
  FillChar(FOverlapped, SizeOf(FOverlapped), 0);
  FOverlapped.hEvent := FEvent;
  ResetEvent(FEvent);
  Count := 0;
  Result := ReadFile(FHandle, FBuffer[0], FReportLength, Count, @FOverlapped);
  if Result then
  begin
    FPending := False;
    DecodeReport(Count);
  end
  else
  begin
    FPending := GetLastError = ERROR_IO_PENDING;
    Result := FPending;
  end;
end;

function NormalizeStick(Value: Integer): Single;
begin
  Result := EnsureRange((Value - 2048) / 2048.0, -1.0, 1.0);
  if Abs(Result) < 0.18 then Exit(0);
  Result := Sign(Result) * (Abs(Result) - 0.18) / 0.82;
end;

function NormalizeSimpleStick(Value: Integer): Single;
begin
  Result := EnsureRange((Value - 32768) / 32768.0, -1.0, 1.0);
  if Abs(Result) < 0.18 then Exit(0);
  Result := Sign(Result) * (Abs(Result) - 0.18) / 0.82;
end;

procedure SetButton(var Buttons: Cardinal; Number: Integer; IsDown: Boolean);
begin
  if IsDown then Buttons := Buttons or (Cardinal(1) shl (Number - 1));
end;

procedure TMmdProControllerInput.DecodeReport(Count: Cardinal);
var Buttons, OldPOV: Cardinal; X, Y: Integer; Hat: Byte;
begin
  if Count < 12 then Exit;
  Buttons := 0;
  OldPOV := FState.POV;
  if FBuffer[0] in [$21, $30, $31] then
  begin
    SetButton(Buttons, ProButtonA, (FBuffer[3] and $08) <> 0);
    SetButton(Buttons, ProButtonB, (FBuffer[3] and $04) <> 0);
    SetButton(Buttons, ProButtonX, (FBuffer[3] and $02) <> 0);
    SetButton(Buttons, ProButtonY, (FBuffer[3] and $01) <> 0);
    SetButton(Buttons, ProButtonR, (FBuffer[3] and $40) <> 0);
    SetButton(Buttons, ProButtonZR, (FBuffer[3] and $80) <> 0);
    SetButton(Buttons, ProButtonL, (FBuffer[5] and $40) <> 0);
    SetButton(Buttons, ProButtonZL, (FBuffer[5] and $80) <> 0);
    SetButton(Buttons, ProButtonMinus, (FBuffer[4] and $01) <> 0);
    SetButton(Buttons, ProButtonPlus, (FBuffer[4] and $02) <> 0);
    SetButton(Buttons, ProButtonRightStick, (FBuffer[4] and $04) <> 0);
    SetButton(Buttons, ProButtonLeftStick, (FBuffer[4] and $08) <> 0);
    FState.POV := $FFFF;
    if (FBuffer[5] and $02) <> 0 then FState.POV := 0;
    if (FBuffer[5] and $01) <> 0 then FState.POV := 18000;
    if FState.POV = $FFFF then
    begin
      if (FBuffer[5] and $04) <> 0 then FState.POV := 9000;
      if (FBuffer[5] and $08) <> 0 then FState.POV := 27000;
    end;
    X := FBuffer[6] or ((FBuffer[7] and $0F) shl 8);
    Y := (FBuffer[7] shr 4) or (FBuffer[8] shl 4);
    FState.LeftX := NormalizeStick(X);
    FState.LeftY := NormalizeStick(Y);
    X := FBuffer[9] or ((FBuffer[10] and $0F) shl 8);
    Y := (FBuffer[10] shr 4) or (FBuffer[11] shl 4);
    FState.RightX := NormalizeStick(X);
    FState.RightY := NormalizeStick(Y);
  end
  else if FBuffer[0] = $3F then
  begin
    SetButton(Buttons, ProButtonB, (FBuffer[1] and $01) <> 0);
    SetButton(Buttons, ProButtonA, (FBuffer[1] and $02) <> 0);
    SetButton(Buttons, ProButtonY, (FBuffer[1] and $04) <> 0);
    SetButton(Buttons, ProButtonX, (FBuffer[1] and $08) <> 0);
    SetButton(Buttons, ProButtonMinus, (FBuffer[2] and $01) <> 0);
    SetButton(Buttons, ProButtonPlus, (FBuffer[2] and $02) <> 0);
    SetButton(Buttons, ProButtonLeftStick, (FBuffer[2] and $04) <> 0);
    SetButton(Buttons, ProButtonRightStick, (FBuffer[2] and $08) <> 0);
    Hat := FBuffer[3] and $0F;
    FState.POV := $FFFF;
    case Hat of
      0, 1, 7: FState.POV := 0;
      2: FState.POV := 9000;
      3, 4, 5: FState.POV := 18000;
      6: FState.POV := 27000;
    end;
    X := FBuffer[4] or (FBuffer[5] shl 8);
    Y := FBuffer[6] or (FBuffer[7] shl 8);
    FState.LeftX := NormalizeSimpleStick(X);
    FState.LeftY := -NormalizeSimpleStick(Y);
    X := FBuffer[8] or (FBuffer[9] shl 8);
    Y := FBuffer[10] or (FBuffer[11] shl 8);
    FState.RightX := NormalizeSimpleStick(X);
    FState.RightY := -NormalizeSimpleStick(Y);
  end
  else Exit;
  FPressedButtons := FPressedButtons or (Buttons and not FState.Buttons);
  if (FState.POV <> $FFFF) and (FState.POV <> OldPOV) then
    FPressedPOV := FState.POV;
  FState.Buttons := Buttons;
  FHaveReport := True;
end;

function TMmdProControllerInput.Poll(out State: TMmdProPadState): Boolean;
var Count: Cardinal; Index: Integer;
begin
  State := Default(TMmdProPadState);
  State.POV := $FFFF;
  if FHandle = INVALID_HANDLE_VALUE then
  begin
    if GetTickCount64 - FLastSearch < 1000 then Exit(False);
    FLastSearch := GetTickCount64;
    if not OpenDevice then Exit(False);
  end;
  for Index := 0 to 63 do
  begin
    if FPending then
    begin
      Count := 0;
      if not GetOverlappedResult(FHandle, FOverlapped, Count, False) then
      begin
        if GetLastError = ERROR_IO_INCOMPLETE then Break;
        CloseDevice;
        Exit(False);
      end;
      FPending := False;
      DecodeReport(Count);
    end;
    if not StartRead then
    begin
      CloseDevice;
      Exit(False);
    end;
    if FPending then Break;
  end;
  Result := FHaveReport;
  if Result then
  begin
    State := FState;
    State.Buttons := State.Buttons or FPressedButtons;
    if State.POV = $FFFF then State.POV := FPressedPOV;
  end;
  FPressedButtons := 0;
  FPressedPOV := $FFFF;
end;

function TMmdProControllerInput.GetConnected: Boolean;
begin
  Result := (FHandle <> INVALID_HANDLE_VALUE) and (FEvent <> 0);
end;

function TMmdProControllerInput.ProbeConnection: Boolean;
var
  State: TMmdProPadState;
begin
  // 明示的な画面切替では、定期探索の1秒待ちを飛ばして再接続を試す。
  if not Connected then FLastSearch := 0;
  Poll(State);
  Result := Connected;
end;

procedure TMmdProControllerInput.Disconnect;
begin
  CloseDevice;
  FLastSearch := 0;
end;

end.
