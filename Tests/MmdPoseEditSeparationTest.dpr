program MmdPoseEditSeparationTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Vcl.Controls,
  Vcl.Forms,
  MmdD3DViewport,
  MmdPoseEditSession,
  MmdPoseEditorTools,
  MmdPoseHistory,
  MmdSimpleControllerPanel,
  MmdSimplePoseEditSession,
  MmdSimpleControllerSolver,
  PmxModel,
  PmxPose,
  PmxReader;

procedure CheckToolsWithoutPreview;
var
  Form: TForm;
  SimplePanel: TMmdSimpleControllerPanel;
  Tools: TMmdPoseEditorTools;
  Index: Integer;
begin
  Form := TForm.CreateNew(nil);
  try
    Tools := TMmdPoseEditorTools.CreateForParents(Form, Form, Form,
      alClient, False);
    Tools.UpdateDpi(96);
    if (Tools.CommandToolbar.Parent <> Form) or
      (Tools.LeftPanel.Parent <> Form) or
      (Tools.LeftPanel.Align <> alClient) or
      (Tools.BoneList.Parent <> Tools.LeftPanel) or
      (Tools.CommandImages.Count <> 7) or
      Tools.AutoFitButton.Visible then
      raise Exception.Create('preview-free editing tools are incomplete');
    SimplePanel := TMmdSimpleControllerPanel.Create(Form);
    SimplePanel.Parent := Tools.LeftPanel;
    SimplePanel.Align := alClient;
    SimplePanel.ApplyLayout;
    if SimplePanel.SelectedController <> scUpperBody then
      raise Exception.Create('preview-free controller list is incomplete');
    for Index := 0 to Form.ComponentCount - 1 do
      if Form.Components[Index] is TMmdD3DViewport then
        raise Exception.Create('editing tools created a D3D viewport');
  finally
    Form.Free;
  end;
end;

procedure CheckSessionWithoutPreview;
var
  Model: TPmxModel;
  Session: TMmdPoseEditSession;
  Poses, Loaded: TPmxBonePoses;
  Encoded: string;
begin
  Model := TPmxModel.Create;
  Session := TMmdPoseEditSession.Create;
  try
    SetLength(Model.Bones, 2);
    Model.Bones[0].Name := 'root';
    Model.Bones[0].ParentIndex := -1;
    Model.Bones[1].Name := 'child';
    Model.Bones[1].ParentIndex := 0;
    Session.Load(Model, '', Poses);
    if (Length(Poses) <> 2) or Session.History.CanUndo then
      raise Exception.Create('session initialization failed');
    Poses[1].Translation.X := 3;
    Encoded := Session.Encode(Model, Poses);
    Session.Load(Model, Encoded, Loaded);
    if (Length(Loaded) <> 2) or (Abs(Loaded[1].Translation.X - 3) > 0.0001) then
      raise Exception.Create('pose JSON round trip failed');
    Session.ResetBone(Model, 1, False, Loaded);
    if (Abs(Loaded[1].Translation.X) > 0.0001) or
      not Session.History.CanUndo then
      raise Exception.Create('bone reset failed');
    if not Session.Undo(Loaded) or
      (Abs(Loaded[1].Translation.X - 3) > 0.0001) then
      raise Exception.Create('undo failed');
    if not Session.Redo(Loaded) or
      (Abs(Loaded[1].Translation.X) > 0.0001) then
      raise Exception.Create('redo failed');
    if Session.ApplyExternal(Model, '{invalid', Loaded) then
      raise Exception.Create('invalid external pose was accepted');
    if not Session.ApplyExternal(Model, Encoded, Loaded) or
      (Abs(Loaded[1].Translation.X - 3) > 0.0001) then
      raise Exception.Create('external pose application failed');
    Session.ResetBranch(Model, 0, False, Loaded);
    if Abs(Loaded[1].Translation.X) > 0.0001 then
      raise Exception.Create('branch reset failed');
  finally
    Session.Free;
    Model.Free;
  end;
end;

procedure CheckSimpleSessionWithoutPreview(const ModelPath: string);
var
  History: TMmdPoseHistory;
  Index: Integer;
  Model: TPmxModel;
  Poses, Original, Restored: TPmxBonePoses;
  Session: TMmdSimplePoseEditSession;
begin
  Model := LoadPmxModel(ModelPath);
  History := TMmdPoseHistory.Create;
  Session := TMmdSimplePoseEditSession.Create;
  try
    InitializeBonePoses(Model, Poses);
    Original := Copy(Poses);
    if not Session.BeginEdit(Model, scCenter, Poses) then
      raise Exception.Create('center controller cannot start');
    if not Session.ApplyViewStep(Model, scCenter, Poses,
      0.25, 0, 0, 0, 0, 0, 0, 0) then
      raise Exception.Create('preview-free controller step failed');
    if not Session.Commit(History) or not History.CanUndo then
      raise Exception.Create('controller edit was not committed');
    if not History.Undo(Poses, Restored) then
      raise Exception.Create('controller undo failed');
    for Index := 0 to High(Restored) do
      if (Abs(Restored[Index].Translation.X -
        Original[Index].Translation.X) > 0.0001) or
        (Abs(Restored[Index].Translation.Y -
        Original[Index].Translation.Y) > 0.0001) or
        (Abs(Restored[Index].Translation.Z -
        Original[Index].Translation.Z) > 0.0001) then
        raise Exception.Create('controller undo restored the wrong pose');
    Original := Copy(Poses);
    if not Session.BeginEdit(Model, scCenter, Poses) then
      raise Exception.Create('second controller edit cannot start');
    Session.ApplyViewStep(Model, scCenter, Poses,
      0.25, 0, 0, 0, 0, 0, 0, 0);
    Session.Cancel(Poses);
    if Session.Editing or Session.Commit(History) then
      raise Exception.Create('controller cancel failed');
    for Index := 0 to High(Poses) do
      if (Abs(Poses[Index].Translation.X -
        Original[Index].Translation.X) > 0.0001) or
        (Abs(Poses[Index].Translation.Y -
        Original[Index].Translation.Y) > 0.0001) or
        (Abs(Poses[Index].Translation.Z -
        Original[Index].Translation.Z) > 0.0001) then
        raise Exception.Create('controller cancel restored the wrong pose');
  finally
    Session.Free;
    History.Free;
    Model.Free;
  end;
end;

begin
  Application.Initialize;
  try
    CheckToolsWithoutPreview;
    CheckSessionWithoutPreview;
    if ParamCount > 0 then CheckSimpleSessionWithoutPreview(ParamStr(1));
    Writeln('MmdPoseEditSeparationTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
