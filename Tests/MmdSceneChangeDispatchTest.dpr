program MmdSceneChangeDispatchTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  AviUtl2PluginCore,
  AviUtl2PluginScene,
  AviUtl2PluginTypes,
  MMDAnimationStudioFrame;

var
  Edit: TEditSection;
  Info: TEditInfo;
  Handle: TEditHandle;
  InsideSceneCallback: Boolean;
  ReentrantReads: Integer;

function FakeCallEditSection(Func: TProcEditSection): LongBool; cdecl;
begin
  if InsideSceneCallback then Inc(ReentrantReads);
  Func(@Edit);
  Result := True;
end;

function FakeGetFocusObject: TObjectHandle; cdecl;
begin
  Result := nil;
end;

function FakeGetSelectedObjectNum: Integer; cdecl;
begin
  Result := 0;
end;

var
  Frame: TFrameMMDAnimationStudio;
  Host: TForm;
  Panel: TPanel;
begin
  try
    Application.Initialize;
    Info := Default(TEditInfo);
    Info.SceneID := 1;
    Edit := Default(TEditSection);
    Edit.Info := @Info;
    Edit.GetFocusObject := FakeGetFocusObject;
    Edit.GetSelectedObjectNum := FakeGetSelectedObjectNum;
    Handle := Default(TEditHandle);
    Handle.CallEditSection := FakeCallEditSection;
    EditHandle := @Handle;
    Host := TForm.Create(nil);
    try
      Panel := TPanel.Create(Host);
      Panel.Parent := Host;
      Panel.Align := alClient;
      Frame := TFrameMMDAnimationStudio.Create(Host);
      Frame.Parent := Panel;
      Frame.Align := alClient;
      Host.Show;
      Frame.Show;
      Frame.ButtonPoseSync.Visible := True;
      Frame.ButtonPoseSync.Click;
      if not Frame.PanelPoseSync.Visible then
        raise Exception.Create('Pose sync page did not open');
      ReentrantReads := 0;
      InsideSceneCallback := True;
      try
        SceneChangeHandler(@Edit);
      finally
        InsideSceneCallback := False;
      end;
      if ReentrantReads <> 0 then
        raise Exception.Create('Scene callback reentered CallEditSection');
      Application.ProcessMessages;
      if not Frame.PanelPoseSync.Visible then
        raise Exception.Create('Scene change lost the pose page');
    finally
      Host.Free;
      EditHandle := nil;
    end;
    Writeln('MmdSceneChangeDispatchTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
