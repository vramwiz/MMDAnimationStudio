program MMDAIPreview;

{$APPTYPE GUI}

{$R *.res}

uses
  System.SysUtils,
  Winapi.Windows,
  Vcl.Forms,
  MmdAiPreviewHost in 'Source\AI\MmdAiPreviewHost.pas',
  MmdVpdDirectory in '..\AviUtl2PluginLib\MMD\VPD\IO\MmdVpdDirectory.pas',
  HorizontalTrackBarRenderer in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarRenderer.pas',
  HorizontalTrackBarControl in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas',
  MmdAiPreviewMainForm in 'Source\AI\MmdAiPreviewMainForm.pas' {MainForm};

procedure AttachHostConsole;
var
  InputHandle, OutputHandle: THandle;
  ConsoleAttached: Boolean;
begin
  InputHandle := GetStdHandle(STD_INPUT_HANDLE);
  OutputHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  ConsoleAttached := False;
  if ((InputHandle = 0) or (InputHandle = INVALID_HANDLE_VALUE)) and
     ((OutputHandle = 0) or (OutputHandle = INVALID_HANDLE_VALUE)) then
  begin
    if not AttachConsole(ATTACH_PARENT_PROCESS) then
      AllocConsole;
    ConsoleAttached := True;
  end;
  if ConsoleAttached then
  begin
    AssignFile(Input, 'CONIN$');
    Reset(Input);
    AssignFile(Output, 'CONOUT$');
    Rewrite(Output);
    AssignFile(ErrOutput, 'CONOUT$');
    Rewrite(ErrOutput);
  end;
  SetConsoleCP(CP_UTF8);
  SetConsoleOutputCP(CP_UTF8);
end;

begin
  try
    if ParamCount = 0 then
    begin
      Application.Initialize;
      Application.Title := 'MMD AI Preview';
      Application.MainFormOnTaskbar := True;
      Application.CreateForm(TMmdAiPreviewMainForm, MainForm);
      Application.Run;
    end
    else
    begin
      AttachHostConsole;
      RunMmdAiPreviewHost;
    end;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
