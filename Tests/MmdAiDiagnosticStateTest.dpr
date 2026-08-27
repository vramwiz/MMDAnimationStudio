program MmdAiDiagnosticStateTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  MmdAiDiagnosticState in '..\AviUtl2PluginLib\MMD\AI\MmdAiDiagnosticState.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure RunTests;
var
  ErrorCode, ErrorMessage, Normalized, Token, TokenAgain: string;
  Mode: TMmdAiDiagnosticMode;
begin
  Check(BeginMmdAiDiagnosticView('D:\test\model.pmx', 'finger_id', Token,
    Normalized, ErrorCode, ErrorMessage), 'first begin failed');
  Check((Token <> '') and (Normalized = 'finger_id'),
    'begin response is incomplete');
  Check(BeginMmdAiDiagnosticView('D:\test\model.pmx', 'finger_id', TokenAgain,
    Normalized, ErrorCode, ErrorMessage), 'idempotent begin failed');
  Check(TokenAgain = Token, 'idempotent begin returned a different token');
  Check(not BeginMmdAiDiagnosticView('D:\test\model.pmx', 'bones', TokenAgain,
    Normalized, ErrorCode, ErrorMessage), 'different pass was not rejected');
  Check(ErrorCode = 'diagnostic_view_busy', 'busy error code changed');
  Check(TryGetMmdAiDiagnosticMode('D:\test\model.pmx', Mode) and
    (Mode = madFingerId), 'active mode was not visible');
  Check(EndMmdAiDiagnosticView(Token, ErrorCode, ErrorMessage),
    'first end failed');
  Check(EndMmdAiDiagnosticView(Token, ErrorCode, ErrorMessage),
    'idempotent end failed');
  Check(not TryGetMmdAiDiagnosticMode('D:\test\model.pmx', Mode),
    'ended mode remained active');
  Check(not BeginMmdAiDiagnosticView('D:\test\model.pmx', 'unknown', Token,
    Normalized, ErrorCode, ErrorMessage), 'unknown pass was accepted');
  Check(ErrorCode = 'unsupported_diagnostic_pass',
    'unknown pass error code changed');
end;

begin
  try
    RunTests;
    Writeln('MmdAiDiagnosticStateTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
