unit MmdProControllerReportDecoder;

// Switch Pro Controllerの標準/フルHID報告を、共通パッド状態へ復号する。

interface

uses
  System.SysUtils,
  MmdProControllerInput;

// HID報告から現在状態を更新し、短い押下を次回Pollまで保持する。
procedure DecodeProReport(const Buffer: TBytes; Count: Cardinal;
  var State: TMmdProPadState; var PressedButtons, PressedPOV: Cardinal;
  var HaveReport: Boolean);

implementation

uses System.Math;
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

procedure DecodeProReport(const Buffer: TBytes; Count: Cardinal;
  var State: TMmdProPadState; var PressedButtons, PressedPOV: Cardinal;
  var HaveReport: Boolean);
var Buttons, OldPOV: Cardinal; X, Y: Integer; Hat: Byte;
begin
  if Count < 12 then Exit;
  Buttons := 0;
  OldPOV := State.POV;
  if Buffer[0] in [$21, $30, $31] then
  begin
    SetButton(Buttons, ProButtonA, (Buffer[3] and $08) <> 0);
    SetButton(Buttons, ProButtonB, (Buffer[3] and $04) <> 0);
    SetButton(Buttons, ProButtonX, (Buffer[3] and $02) <> 0);
    SetButton(Buttons, ProButtonY, (Buffer[3] and $01) <> 0);
    SetButton(Buttons, ProButtonR, (Buffer[3] and $40) <> 0);
    SetButton(Buttons, ProButtonZR, (Buffer[3] and $80) <> 0);
    SetButton(Buttons, ProButtonL, (Buffer[5] and $40) <> 0);
    SetButton(Buttons, ProButtonZL, (Buffer[5] and $80) <> 0);
    SetButton(Buttons, ProButtonMinus, (Buffer[4] and $01) <> 0);
    SetButton(Buttons, ProButtonPlus, (Buffer[4] and $02) <> 0);
    SetButton(Buttons, ProButtonRightStick, (Buffer[4] and $04) <> 0);
    SetButton(Buttons, ProButtonLeftStick, (Buffer[4] and $08) <> 0);
    State.POV := $FFFF;
    if (Buffer[5] and $02) <> 0 then State.POV := 0;
    if (Buffer[5] and $01) <> 0 then State.POV := 18000;
    if State.POV = $FFFF then
    begin
      if (Buffer[5] and $04) <> 0 then State.POV := 9000;
      if (Buffer[5] and $08) <> 0 then State.POV := 27000;
    end;
    X := Buffer[6] or ((Buffer[7] and $0F) shl 8);
    Y := (Buffer[7] shr 4) or (Buffer[8] shl 4);
    State.LeftX := NormalizeStick(X);
    State.LeftY := NormalizeStick(Y);
    X := Buffer[9] or ((Buffer[10] and $0F) shl 8);
    Y := (Buffer[10] shr 4) or (Buffer[11] shl 4);
    State.RightX := NormalizeStick(X);
    State.RightY := NormalizeStick(Y);
  end
  else if Buffer[0] = $3F then
  begin
    SetButton(Buttons, ProButtonB, (Buffer[1] and $01) <> 0);
    SetButton(Buttons, ProButtonA, (Buffer[1] and $02) <> 0);
    SetButton(Buttons, ProButtonY, (Buffer[1] and $04) <> 0);
    SetButton(Buttons, ProButtonX, (Buffer[1] and $08) <> 0);
    SetButton(Buttons, ProButtonMinus, (Buffer[2] and $01) <> 0);
    SetButton(Buttons, ProButtonPlus, (Buffer[2] and $02) <> 0);
    SetButton(Buttons, ProButtonLeftStick, (Buffer[2] and $04) <> 0);
    SetButton(Buttons, ProButtonRightStick, (Buffer[2] and $08) <> 0);
    Hat := Buffer[3] and $0F;
    State.POV := $FFFF;
    case Hat of
      0, 1, 7: State.POV := 0;
      2: State.POV := 9000;
      3, 4, 5: State.POV := 18000;
      6: State.POV := 27000;
    end;
    X := Buffer[4] or (Buffer[5] shl 8);
    Y := Buffer[6] or (Buffer[7] shl 8);
    State.LeftX := NormalizeSimpleStick(X);
    State.LeftY := -NormalizeSimpleStick(Y);
    X := Buffer[8] or (Buffer[9] shl 8);
    Y := Buffer[10] or (Buffer[11] shl 8);
    State.RightX := NormalizeSimpleStick(X);
    State.RightY := -NormalizeSimpleStick(Y);
  end
  else Exit;
  PressedButtons := PressedButtons or (Buttons and not State.Buttons);
  if (State.POV <> $FFFF) and (State.POV <> OldPOV) then
    PressedPOV := State.POV;
  State.Buttons := Buttons;
  HaveReport := True;
end;

end.
