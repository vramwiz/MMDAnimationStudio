program MmdProControllerOutputTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  MmdProControllerOutput;

var
  Report: TBytes;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
end;

begin
  try
    Report := BuildProSubcommandReport(64, 17, $30, $01);
    Check(Length(Report) = 64, 'report length');
    Check((Report[0] = $01) and (Report[1] = $01),
      'report ID or packet counter');
    Check((Report[3] = $01) and (Report[4] = $40) and
      (Report[5] = $40) and (Report[7] = $01) and
      (Report[8] = $40) and (Report[9] = $40),
      'neutral rumble payload');
    Check((Report[10] = $30) and (Report[11] = $01),
      'player 1 LED command');
    Check(Length(BuildProSubcommandReport(11, 0, $30, $01)) = 0,
      'short report was accepted');
    Writeln('MmdProControllerOutputTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
