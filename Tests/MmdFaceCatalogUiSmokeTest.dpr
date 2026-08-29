program MmdFaceCatalogUiSmokeTest;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  MmdModelSettingEditor,
  PmxFaceCatalogStorage,
  PmxCatalogGroupShortcut in
    '..\Source\Plugin\Extension\PMX\Catalog\Group\PmxCatalogGroupShortcut.pas',
  PmxFaceCatalogSelection in
    '..\Source\Plugin\Extension\PMX\Catalog\Face\View\PmxFaceCatalogSelection.pas',
  MmdFaceCatalogFrame in
    'Source\Plugin\Extension\Face\Catalog\MmdFaceCatalogFrame.pas',
  PmxCatalogStorage in
    'Source\Plugin\Extension\PMX\Catalog\PmxCatalogStorage.pas';

type
  TTestFaceSettingForm = class(TMmdModelSettingEditorForm)
  public
    function FaceModeActive: Boolean;
    function MorphListFillsClient: Boolean;
  end;

  TTestFaceEditor = class
  public
    Accept: Boolean;
    CallCount: Integer;
    NewFaceData: string;
    function EditFace(Sender: TObject; Model: TPmxCatalogItem;
      Item: TPmxFaceCatalogItem): Boolean;
  end;

function TTestFaceSettingForm.FaceModeActive: Boolean;
begin
  Result := not FBoneList.Visible and not FCommandToolbar.Visible and
    FMorphPreview.Visible and FViewport.ReadOnly;
end;

function TTestFaceSettingForm.MorphListFillsClient: Boolean;
begin
  Result := (FMorphPreview.Align = alClient) and
    (FMorphPreview.Top = 0) and
    (FMorphPreview.Height = FLeftPanel.ClientHeight);
end;

function TTestFaceEditor.EditFace(Sender: TObject; Model: TPmxCatalogItem;
  Item: TPmxFaceCatalogItem): Boolean;
begin
  Inc(CallCount);
  Result := Accept and Assigned(Model) and Assigned(Item);
  if Result then Item.FaceData := NewFaceData;
end;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
end;

procedure Run;
var
  Catalog: TPmxCatalogStorage;
  CatalogFile, ModelFolder, Root: string;
  FaceId: string;
  Frame: TFrameMmdFaceCatalog;
  FaceOnlyForm: TTestFaceSettingForm;
  Host: TForm;
  TestEditor: TTestFaceEditor;
begin
  Root := TPath.Combine(TPath.GetTempPath,
    'MmdFaceCatalogUi-' + TPath.GetRandomFileName);
  CatalogFile := TPath.Combine(Root, 'Catalog.json');
  try
    TDirectory.CreateDirectory(Root);
    Catalog := TPmxCatalogStorage.Create(CatalogFile);
    Host := TForm.Create(nil);
    try
      FaceOnlyForm := TTestFaceSettingForm.Create(nil);
      try
        FaceOnlyForm.ConfigureSettingControls(False, False, True);
        FaceOnlyForm.Show;
        FaceOnlyForm.ClientHeight := 900;
        Application.ProcessMessages;
        Check(not Assigned(FaceOnlyForm.ModeToolbar),
          'face-only page toolbar was created');
        Check(FaceOnlyForm.FaceModeActive,
          'face-only state was not restored after window creation');
        Check(FaceOnlyForm.MorphListFillsClient,
          'face morph list did not fill the left client area');
      finally
        FaceOnlyForm.Free;
      end;
      Check(Catalog.LoadFromFile, 'PMX catalog did not initialize');
      Check(Catalog.Add('C:\Temp\face-test.pmx') and Catalog.SaveToFile,
        'test PMX was not created');
      Frame := TFrameMmdFaceCatalog.Create(Host);
      Frame.Parent := Host;
      Frame.Align := alClient;
      Frame.SetCatalog(Catalog);
      Frame.SelectPmxId(Catalog.Items[0].Id);
      Frame.Show;
      Application.ProcessMessages;
      Check(Assigned(Frame.FaceCatalog) and
        (Frame.FaceCatalog.Count = 1) and Frame.FaceCatalog.IsInitial(0),
        'initial face was not loaded by the page');
      Check((Frame.FaceCatalog[0].Name = #$521D#$671F#$72B6#$614B) and
        (Frame.FaceListView.DisplayCount = 1),
        'initial face was not displayed');
      Check(Assigned(Frame.FaceToolbar) and
        (Frame.FaceToolbar.Items.Count = 5) and
        Assigned(Frame.FaceGroupBar) and
        (Frame.FaceGroupBar.Combo.Items.Count = 1) and
        (Frame.FaceGroupBar.Combo.Items[0] = #$3059#$3079#$3066),
        'face management controls were not attached');
      Check(Assigned(Frame.FaceListView.PopupMenu) and
        (Frame.FaceListView.PopupMenu.Items.Count = 10),
        'face context menu was not attached');
      Check(Assigned(Frame.FaceListView.OnDblClick),
        'face editor was not connected');
      TestEditor := TTestFaceEditor.Create;
      try
        TestEditor.NewFaceData := '{"version":1,"morphs":[' +
          '{"name":"smile","weight":0.75}]}';
        Frame.OnEditFace := TestEditor.EditFace;
        TestEditor.Accept := False;
        Frame.FaceListView.OnDblClick(Frame.FaceListView);
        Check((TestEditor.CallCount = 1) and
          (Frame.FaceCatalog[0].FaceData =
            '{"version":1,"morphs":[]}'),
          'cancelled face edit was applied');
        TestEditor.Accept := True;
        Frame.FaceListView.OnDblClick(Frame.FaceListView);
        Check((TestEditor.CallCount = 2) and
          (Frame.FaceCatalog[0].FaceData = TestEditor.NewFaceData),
          'confirmed face edit was not applied');
        Check(Frame.FaceCatalog.LoadOrCreateDefault and
          (Frame.FaceCatalog[0].FaceData = TestEditor.NewFaceData),
          'confirmed face edit was not persisted');
      finally
        Frame.OnEditFace := nil;
        TestEditor.Free;
      end;
      Frame.FaceToolbar.AddFace;
      Check(Frame.FaceCatalog.Count = 2,
        'face toolbar did not add an item');
      FaceId := Frame.FaceCatalog[1].Id;
      Frame.FaceToolbar.CopyFace;
      Check(Frame.FaceCatalog.Count = 3,
        'face toolbar did not duplicate an item');
      Check(Assigned(Frame.FaceGroups.Add('basic')),
        'face group was not added');
      Frame.FaceGroups.AssignFaceToGroup(FaceId, 0);
      Check(Frame.FaceGroups.SaveToFile, 'face group was not saved');
      Frame.FaceGroupBar.Rebuild(Frame.FaceGroups[0].Id);
      Check((Frame.FaceListView.GroupIndex = 0) and
        (Frame.FaceListView.DisplayCount = 1),
        'face group filter was not applied');
      ModelFolder := Catalog.ModelFolder(Catalog.Items[0].Id);
      Check(TFile.Exists(TPath.Combine(TPath.Combine(ModelFolder, 'Faces'),
        'Index.json')), 'face index was not saved below the PMX');
    finally
      Host.Free;
      Catalog.Free;
    end;
  finally
    if TDirectory.Exists(Root) then TDirectory.Delete(Root, True);
  end;
end;

begin
  try
    Application.Initialize;
    Run;
    Writeln('MmdFaceCatalogUiSmokeTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdFaceCatalogUiSmokeTest: FAIL: ' + E.Message);
      Halt(1);
    end;
  end;
end.
