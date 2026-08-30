program MmdExtensionUiSmokeTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.JSON,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.Menus,
  System.IOUtils,
  DarkPanel in
    '..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkPanel.pas',
  DarkLabel in
    '..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkLabel.pas',
  DarkButton in
    '..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkButton.pas',
  DarkComboBox in
    '..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Input\DarkComboBox.pas',
  DarkEdit in
    '..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Input\DarkEdit.pas',
  ItemListView in
    '..\AviUtl2PluginLib\Lib\ItemListView\ItemListView.pas',
  ShortcutAction in
    '..\AviUtl2PluginLib\Lib\ShortcutAction\ShortcutAction.pas',
  ConfirmDialogForm in
    '..\AviUtl2PluginLib\Lib\ConfirmDialog\ConfirmDialogForm.pas' {FormConfirmDialog},
  MmdMorphSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdEyeBlinkSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdEyeBlinkSettingCodec.pas',
  MmdLipSyncSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  MmdModelSettingEditor in
    '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdModelSettingEditor.pas',
  MMDAnimationStudioFrame in '..\Source\Plugin\Extension\MMDAnimationStudioFrame.pas' {FrameMMDAnimationStudio: TFrame},
  PmxCatalogFrame in '..\Source\Plugin\Extension\PMX\Catalog\PmxCatalogFrame.pas' {FramePmxCatalog: TFrame},
  PmxCatalogStorage in '..\Source\Plugin\Extension\PMX\Catalog\PmxCatalogStorage.pas',
  PmxCatalogItem in '..\Source\Plugin\Extension\PMX\Catalog\Storage\PmxCatalogItem.pas',
  PmxCatalogModelCodec in
    '..\Source\Plugin\Extension\PMX\Catalog\Storage\PmxCatalogModelCodec.pas',
  PmxCatalogCharacterFilter in
    '..\Source\Plugin\Extension\PMX\Catalog\Filter\PmxCatalogCharacterFilter.pas',
  PmxCatalogSelector in
    '..\Source\Plugin\Extension\PMX\Catalog\Selector\PmxCatalogSelector.pas',
  PmxCatalogContextMenu in
    '..\Source\Plugin\Extension\PMX\Catalog\Menu\PmxCatalogContextMenu.pas',
  PmxCatalogListView in '..\Source\Plugin\Extension\PMX\Catalog\View\PmxCatalogListView.pas',
  PmxPoseCatalogStorage in '..\Source\Plugin\Extension\PMX\Catalog\Pose\PmxPoseCatalogStorage.pas',
  PmxPoseCatalogDataValidation in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogDataValidation.pas',
  PmxPoseCatalogItem in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogItem.pas',
  PmxPoseCatalogIndexCodec in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogIndexCodec.pas',
  PmxPoseCatalogItemCodec in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogItemCodec.pas',
  PmxPoseCatalogListView in '..\Source\Plugin\Extension\PMX\Catalog\Pose\View\PmxPoseCatalogListView.pas',
  PmxCatalogGroupShortcut in '..\Source\Plugin\Extension\PMX\Catalog\Group\PmxCatalogGroupShortcut.pas',
  PmxPoseCatalogToolbar in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Toolbar\PmxPoseCatalogToolbar.pas',
  PmxPoseCatalogToolbarIcons in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Toolbar\PmxPoseCatalogToolbarIcons.pas',
  PmxPoseCatalogContextMenu in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Menu\PmxPoseCatalogContextMenu.pas',
  PmxPoseCatalogGroups in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Group\PmxPoseCatalogGroups.pas',
  PmxPoseCatalogGroupBar in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Group\PmxPoseCatalogGroupBar.pas',
  PmxPoseCatalogDragController in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Drag\PmxPoseCatalogDragController.pas',
  MmdPoseCatalogFrame in
    '..\Source\Plugin\Extension\Pose\Catalog\MmdPoseCatalogFrame.pas',
  MmdPoseObjectDragAlias in
    '..\Source\Plugin\Extension\Pose\Catalog\Drag\MmdPoseObjectDragAlias.pas',
  MmdPoseObjectDragController in
    '..\Source\Plugin\Extension\Pose\Catalog\Drag\MmdPoseObjectDragController.pas',
  PmxCatalogThumbnailCache in '..\Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailCache.pas',
  PmxCatalogThumbnailRenderer in '..\Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailRenderer.pas',
  MMDAnimationStudioToolbarIcons in '..\Source\Plugin\Extension\MMDAnimationStudioToolbarIcons.pas';

type
  TTestPoseEditor = class
  public
    Accept: Boolean;
    CallCount: Integer;
    NewPoseData: string;
    function EditPose(Sender: TObject; Model: TPmxCatalogItem;
      Item: TPmxPoseCatalogItem): Boolean;
  end;

var
  HostForm: TForm;
  HostPanel: TPanel;
  Frame: TFrameMMDAnimationStudio;
  DroppedFiles: TArray<string>;
  CatalogFileName: string;
  ActualCatalogFileName: string;
  Bitmap: TBitmap;
  CacheFolder: string;
  CatalogLines: TStringList;
  LoadedBitmap: TBitmap;
  PmxFileName: string;
  ThumbnailCache: TPmxCatalogThumbnailCache;
  ThumbnailRenderer: TPmxCatalogThumbnailRenderer;
  TestCatalogRoot: string;
  EditedEyeBlinkData, EditedLipSyncData: string;
  LipSyncSetting: TMmdLipSyncSetting;
  EditedExpressionData: string;
  EditedPoseData: string;
  PoseFileName: string;
  PoseJson: TJSONValue;
  PoseIndex: Integer;
  PoseToolbar: TPmxPoseCatalogToolbar;
  ComponentIndex: Integer;
  ConfirmDialog: TFormConfirmDialog;
  PoseOnlyForm: TMmdModelSettingEditorForm;
  CanClose: Boolean;
  DarkOkButton: TDarkButton;
  ShortcutKey: Word;
  SecondPmxId: string;
  VisibleDarkButtonCount: Integer;
  TestPoseEditor: TTestPoseEditor;
  PoseGroup: TPmxPoseCatalogGroup;
  ReloadedPoseGroups: TPmxPoseCatalogGroups;

function TTestPoseEditor.EditPose(Sender: TObject; Model: TPmxCatalogItem;
  Item: TPmxPoseCatalogItem): Boolean;
begin
  Inc(CallCount);
  Result := Accept and Assigned(Model) and Assigned(Item);
  if Result then Item.PoseData := NewPoseData;
end;

begin
  try
    Application.Initialize;
    HostForm := TForm.Create(nil);
    try
      ConfirmDialog := TFormConfirmDialog.Create(HostForm);
      try
        ConfirmDialog.ApplyDpi(192);
        if (ConfirmDialog.ClientWidth <> 398) or
           (ConfirmDialog.ClientHeight <> 112) or
           (ConfirmDialog.PanelCaption.Height <> 70) or
           (ConfirmDialog.Font.Height <> -28) then
          raise Exception.Create('confirm dialog 200% DPI scaling failed');
        VisibleDarkButtonCount := 0;
        DarkOkButton := nil;
        for ComponentIndex := 0 to ConfirmDialog.Panel1.ControlCount - 1 do
          if ConfirmDialog.Panel1.Controls[ComponentIndex].Visible and
            (ConfirmDialog.Panel1.Controls[ComponentIndex] is
              TDarkButton) then
          begin
            Inc(VisibleDarkButtonCount);
            if TDarkButton(
              ConfirmDialog.Panel1.Controls[ComponentIndex]).Caption = 'OK' then
              DarkOkButton := TDarkButton(
                ConfirmDialog.Panel1.Controls[ComponentIndex]);
          end;
        if ConfirmDialog.btnOk.Visible or ConfirmDialog.btnCancel.Visible or
          (VisibleDarkButtonCount <> 2) or not Assigned(DarkOkButton) then
          raise Exception.Create('confirm dialog dark buttons were not applied');
        ConfirmDialog.ModalResult := mrNone;
        DarkOkButton.Perform(WM_LBUTTONDOWN, MK_LBUTTON, 1 or (1 shl 16));
        DarkOkButton.Perform(WM_LBUTTONUP, 0, 1 or (1 shl 16));
        if ConfirmDialog.ModalResult <> mrOk then
          raise Exception.Create('confirm dialog dark OK button did not execute');
      finally
        ConfirmDialog.Free;
      end;
      PoseOnlyForm := TMmdModelSettingEditorForm.Create(nil);
      try
        PoseOnlyForm.ConfigureSettingControls(False, True);
        if Assigned(PoseOnlyForm.ModeToolbar) then
          raise Exception.Create('pose-only page toolbar was created');
        CanClose := False;
        PoseOnlyForm.ModalResult := mrNone;
        PoseOnlyForm.OnCloseQuery(PoseOnlyForm, CanClose);
        if not CanClose or (PoseOnlyForm.ModalResult <> mrOk) then
          raise Exception.Create('pose-only close did not confirm settings');
      finally
        PoseOnlyForm.Free;
      end;
      HostPanel := TPanel.Create(HostForm);
      HostPanel.Parent := HostForm;
      HostPanel.Align := alClient;
      Frame := TFrameMMDAnimationStudio.Create(HostForm);
      Frame.Parent := HostPanel;
      Frame.Align := alClient;
      Frame.Show;
      if not (Frame.PanelToolbar is TDarkPanel) or
         not (Frame.PanelPmx is TDarkPanel) or
         not (Frame.PanelPoseMotion is TDarkPanel) or
         not (Frame.PanelExpression is TDarkPanel) or
         not (Frame.PanelSerif is TDarkPanel) or
         not (Frame.PanelExplorer is TDarkPanel) or
         not (Frame.PanelMusic is TDarkPanel) or
         not (Frame.PanelLaunch is TDarkPanel) then
        raise Exception.Create('extension page panels are not dark panels');
      if not (Frame.PmxCatalogFrame.PanelHeader is TDarkPanel) or
         not (Frame.PmxCatalogFrame.LabelTitle is TDarkLabel) or
         not (Frame.PmxCatalogFrame.LabelDropHint is TDarkLabel) or
         not (Frame.PmxCatalogFrame.LabelDropStatus is TDarkLabel) then
        raise Exception.Create('PMX empty header did not use dark controls');
      HostForm.ClientWidth := 100;
      Application.ProcessMessages;
      if Frame.ToolbarPages.Height <= Frame.ToolbarPages.ButtonHeight then
        raise Exception.Create('toolbar did not expand for wrapped buttons');
      SetLength(DroppedFiles, 1);
      TestCatalogRoot := TPath.Combine(TPath.GetTempPath,
        'MMDAnimationStudio-' + TPath.GetRandomFileName);
      TDirectory.CreateDirectory(TestCatalogRoot);
      CatalogFileName := TPath.Combine(TestCatalogRoot, 'Catalog.json');
      Frame.PmxCatalogFrame.OpenCatalog(CatalogFileName);
      DroppedFiles[0] := 'C:\Temp\sample.pmx';
      Frame.DropFiles(HostPanel, DroppedFiles);
      if not Assigned(Frame.PmxCatalogFrame) then
        raise Exception.Create('PMX catalog frame was not created');
      if (Frame.PmxCatalogFrame.CatalogListView.SelectionStyle <> ilssRow) or
         (Frame.PmxCatalogFrame.PoseCatalogListView.SelectionStyle <>
           ilssRow) then
        raise Exception.Create('PMX row selection style was not applied');
      if Frame.PmxCatalogFrame.DropEventCount <> 1 then
        raise Exception.Create('PMX drop event did not fire');
      if not SameText(Frame.PmxCatalogFrame.LastDroppedFile, 'sample.pmx') then
        raise Exception.Create('PMX drop file was not displayed');
      Frame.DropFiles(HostPanel, DroppedFiles);
      if Frame.PmxCatalogFrame.Catalog.Count <> 1 then
        raise Exception.Create('duplicate PMX path was registered');
      if not Assigned(Frame.PmxCatalogFrame.CatalogListView.PopupMenu) or
         (Frame.PmxCatalogFrame.CatalogListView.PopupMenu.Items.Count <> 3) or
         (Frame.PmxCatalogFrame.CatalogListView.PopupMenu.Items[0].Caption <>
           #$767B#$9332#$89E3#$9664) or
         (Frame.PmxCatalogFrame.CatalogListView.PopupMenu.Items[2].Caption <>
           #$6700#$65B0#$306E#$72B6#$614B#$306B#$66F4#$65B0) then
        raise Exception.Create('PMX context menu was not attached');
      if Frame.PmxCatalogFrame.Catalog.Items[0].Id = '' then
        raise Exception.Create('PMX UID was not created');
      if not TFile.Exists(TPath.Combine(
        Frame.PmxCatalogFrame.Catalog.ModelFolder(
          Frame.PmxCatalogFrame.Catalog.Items[0].Id), 'Model.json')) then
        raise Exception.Create('PMX model data was not saved');
      if not Assigned(Frame.PmxCatalogFrame.PoseCatalog) or
         (Frame.PmxCatalogFrame.PoseCatalog.Count <> 1) or
         (Frame.PmxCatalogFrame.PoseCatalog[0].Id = '') or
         (Frame.PmxCatalogFrame.PoseCatalog[0].PoseData <>
           '{"version":1,"bones":[]}') or
         (Frame.PmxCatalogFrame.PoseCatalog[0].InitialExpressionData <>
           EmptyMmdMorphSettingData) or
         (Frame.PmxCatalogFrame.PoseCatalog[0].InitialEyeBlinkData <>
           EmptyMmdEyeBlinkSettingData) or
         (Frame.PmxCatalogFrame.PoseCatalog[0].InitialLipSyncData <>
           EmptyMmdLipSyncSettingData) or
         (Frame.PmxCatalogFrame.PoseCatalog[0].Kind <> 'initial') or
         not SameText(Frame.PmxCatalogFrame.PoseCatalog[0].PmxName,
           'sample') or
         (Frame.PmxCatalogFrame.PoseCatalogListView.DisplayCount <> 1) then
        raise Exception.Create('initial pose was not created');
      if not Frame.PmxCatalogFrame.Catalog.Add('C:\Temp\sample-second.pmx') or
         not Frame.PmxCatalogFrame.Catalog.SaveToFile then
        raise Exception.Create('second PMX was not added for selection test');
      SecondPmxId := Frame.PmxCatalogFrame.Catalog.Items[1].Id;
      Frame.PmxCatalogFrame.Show;
      Frame.PmxCatalogFrame.CatalogListView.ItemIndex := 1;
      Application.ProcessMessages;
      if not SameText(Frame.PmxCatalogFrame.SelectedPmxId, SecondPmxId) then
        raise Exception.Create('second PMX was not selected');
      Frame.ButtonPoseMotion.Click;
      Application.ProcessMessages;
      if not Assigned(Frame.PoseCatalogFrame) or
         not Frame.PanelPoseMotion.Visible or
         (Frame.PoseCatalogFrame.PmxSelector.ListView.SelectionStyle <>
           ilssRow) or
         not SameText(Frame.PoseCatalogFrame.PmxSelector.SelectedPmxId,
           SecondPmxId) then
        raise Exception.Create('pose page PMX selection was not synchronized');
      if not Assigned(Frame.PoseCatalogFrame.PoseCatalog) or
         (Frame.PoseCatalogFrame.PoseCatalog.Count <> 1) or
         not Frame.PoseCatalogFrame.PoseCatalog.IsInitial(0) or
         (Frame.PoseCatalogFrame.PoseListView.DisplayCount <> 1) then
        raise Exception.Create('pose page initial pose was not loaded');
      if not Assigned(Frame.PoseCatalogFrame.PoseToolbar) or
         (Frame.PoseCatalogFrame.PoseToolbar.Items.Count <> 5) or
         (Frame.PoseCatalogFrame.PoseToolbar.Align <> alTop) or
         (Frame.PoseCatalogFrame.PoseListView.Top <>
           Frame.PoseCatalogFrame.PoseToolbar.Height +
           Frame.PoseCatalogFrame.PoseGroupBar.Bar.Height) then
        raise Exception.Create('pose page toolbar was not attached');
      if not Assigned(Frame.PoseCatalogFrame.PoseGroups) or
         not Assigned(Frame.PoseCatalogFrame.PoseGroupBar) or
         not (Frame.PoseCatalogFrame.PoseGroupBar.Bar is TDarkPanel) or
         not (Frame.PoseCatalogFrame.PoseGroupBar.Combo is TDarkComboBox) or
         not (Frame.PoseCatalogFrame.PoseGroupBar.Edit is TDarkEdit) or
         (Frame.PoseCatalogFrame.PoseGroupBar.Combo.Items.Count <> 1) or
         (Frame.PoseCatalogFrame.PoseGroupBar.Combo.Items[0] <>
           #$3059#$3079#$3066) then
        raise Exception.Create('pose group bar was not attached');
      if not Assigned(Frame.PoseCatalogFrame.PoseListView.PopupMenu) or
         (Frame.PoseCatalogFrame.PoseListView.PopupMenu.Items.Count <> 11) or
         (Frame.PoseCatalogFrame.PoseListView.PopupMenu.Items[0].Caption <>
           #$65B0#$898F#$8FFD#$52A0 + '(&R)') or
         (Frame.PoseCatalogFrame.PoseListView.PopupMenu.Items[2].Caption <>
           #$767B#$9332#$6E08#$307F + 'VPD' + #$304B#$3089 +
           #$8FFD#$52A0 + '...') or
         (Frame.PoseCatalogFrame.PoseListView.PopupMenu.Items[4].Caption <>
           #$540D#$79F0#$5909#$66F4 + '(&V)') or
         (Frame.PoseCatalogFrame.PoseListView.PopupMenu.Items[5].Caption <>
           #$30B0#$30EB#$30FC#$30D7#$306B#$767B#$9332) or
         (Frame.PoseCatalogFrame.PoseListView.PopupMenu.Items[10].Caption <>
           #$6700#$65B0#$306E#$60C5#$5831 + '(&Z)') or
         (Frame.PoseCatalogFrame.PoseListView.PopupMenu.Items[1].ShortCut <>
           ShortCut(Ord('C'), [ssCtrl])) then
        raise Exception.Create('pose page context menu was not attached');
      PoseGroup := Frame.PoseCatalogFrame.PoseGroups.Add(
        #$57FA#$672C#$30DD#$30FC#$30BA);
      if not Assigned(PoseGroup) then
        raise Exception.Create('pose group was not added');
      Frame.PoseCatalogFrame.PoseGroups.AssignPoseToGroup(
        Frame.PoseCatalogFrame.PoseCatalog[0].Id, 0);
      if not Frame.PoseCatalogFrame.PoseGroups.SaveToFile then
        raise Exception.Create('pose group was not saved');
      Frame.PoseCatalogFrame.PoseGroupBar.Rebuild(PoseGroup.Id);
      if (Frame.PoseCatalogFrame.PoseGroupBar.Combo.ItemIndex <> 1) or
         (Frame.PoseCatalogFrame.PoseListView.GroupIndex <> 0) or
         (Frame.PoseCatalogFrame.PoseListView.DisplayCount <> 1) or
         (Frame.PoseCatalogFrame.PoseListView.SelectedSourceIndex <> 0) then
        raise Exception.Create('pose group filter was not applied');
      ReloadedPoseGroups := TPmxPoseCatalogGroups.Create(
        Frame.PmxCatalogFrame.Catalog.ModelFolder(SecondPmxId));
      try
        if not ReloadedPoseGroups.LoadFromFile or
           (ReloadedPoseGroups.Count <> 1) or
           (ReloadedPoseGroups[0].IndexOfPoseId(
             Frame.PoseCatalogFrame.PoseCatalog[0].Id) <> 0) then
          raise Exception.Create('pose group persistence failed');
      finally
        ReloadedPoseGroups.Free;
      end;
      if not Assigned(Frame.PoseCatalogFrame.PoseListView.OnKeyDown) then
        raise Exception.Create('pose page shortcuts were not attached');
      ShortcutKey := VK_F2;
      Frame.PoseCatalogFrame.PoseListView.OnKeyDown(
        Frame.PoseCatalogFrame.PoseListView, ShortcutKey, []);
      if (ShortcutKey <> 0) or
         not Frame.PoseCatalogFrame.PoseListView.CaptionEditing then
        raise Exception.Create('pose page F2 shortcut did not execute');
      Frame.PoseCatalogFrame.PoseListView.EndEdit(False);
      if not Assigned(Frame.PoseCatalogFrame.PoseListView.OnDblClick) then
        raise Exception.Create('pose page editor was not connected');
      TestPoseEditor := TTestPoseEditor.Create;
      try
        TestPoseEditor.NewPoseData := '{"version":1,"bones":[' +
          '{"name":"center","translation":[4,5,6],' +
          '"rotation":[0,0,0,1]}]}';
        Frame.PoseCatalogFrame.OnEditPose := TestPoseEditor.EditPose;
        TestPoseEditor.Accept := False;
        Frame.PoseCatalogFrame.PoseListView.OnDblClick(
          Frame.PoseCatalogFrame.PoseListView);
        if (TestPoseEditor.CallCount <> 1) or
           (Frame.PoseCatalogFrame.PoseCatalog[0].PoseData <>
             EmptyPmxPoseData) then
          raise Exception.Create('cancelled pose edit was applied');
        TestPoseEditor.Accept := True;
        Frame.PoseCatalogFrame.PoseListView.OnDblClick(
          Frame.PoseCatalogFrame.PoseListView);
        if (TestPoseEditor.CallCount <> 2) or
           (Frame.PoseCatalogFrame.PoseCatalog[0].PoseData <>
             TestPoseEditor.NewPoseData) then
          raise Exception.Create('confirmed pose edit was not applied');
        if not Frame.PoseCatalogFrame.PoseCatalog.LoadOrCreateDefault or
           (Frame.PoseCatalogFrame.PoseCatalog[0].PoseData <>
             TestPoseEditor.NewPoseData) then
          raise Exception.Create('confirmed pose edit was not persisted');
        Frame.PoseCatalogFrame.PoseCatalog[0].PoseData := EmptyPmxPoseData;
        if not Frame.PoseCatalogFrame.PoseCatalog.SaveToFile then
          raise Exception.Create('pose edit test state was not restored');
      finally
        Frame.PoseCatalogFrame.OnEditPose := nil;
        TestPoseEditor.Free;
      end;
      Frame.ButtonPmx.Click;
      Application.ProcessMessages;
      if not Frame.PanelPmx.Visible or
         not SameText(Frame.PmxCatalogFrame.SelectedPmxId,
           Frame.PoseCatalogFrame.PmxSelector.SelectedPmxId) then
        raise Exception.Create('PMX selection was not kept across pages');
      if not Assigned(Frame.PmxCatalogFrame.PoseGroups) or
         not Assigned(Frame.PmxCatalogFrame.PoseGroupBar) or
         (Frame.PmxCatalogFrame.PoseGroups.Count <> 1) or
         (Frame.PmxCatalogFrame.PoseGroupBar.Combo.Items.Count <> 2) or
         (Frame.PmxCatalogFrame.PoseGroups[0].Name <>
           #$57FA#$672C#$30DD#$30FC#$30BA) then
        raise Exception.Create('pose groups were not shared with PMX page');
      Frame.PmxCatalogFrame.PoseGroups.Delete(0);
      Frame.PmxCatalogFrame.PoseGroups.SaveToFile;
      Frame.PmxCatalogFrame.PoseGroupBar.Rebuild;
      if not Frame.PmxCatalogFrame.Catalog.RemoveAt(1) then
        raise Exception.Create('selection test PMX was not removed');
      Frame.PmxCatalogFrame.Show;
      PoseToolbar := nil;
      for ComponentIndex := 0 to Frame.PmxCatalogFrame.ComponentCount - 1 do
        if Frame.PmxCatalogFrame.Components[ComponentIndex] is
          TPmxPoseCatalogToolbar then
          PoseToolbar := TPmxPoseCatalogToolbar(
            Frame.PmxCatalogFrame.Components[ComponentIndex]);
      if not Assigned(PoseToolbar) or (PoseToolbar.Items.Count <> 5) or
         (PoseToolbar.Align <> alTop) or
         not Assigned(Frame.PmxCatalogFrame.PoseGroupBar) or
         (Frame.PmxCatalogFrame.PoseCatalogListView.Top <>
           PoseToolbar.Height +
           Frame.PmxCatalogFrame.PoseGroupBar.Bar.Height) then
        raise Exception.Create('pose catalog toolbar was not attached');
      if not Assigned(Frame.PmxCatalogFrame.PoseCatalogListView.PopupMenu) or
         (Frame.PmxCatalogFrame.PoseCatalogListView.PopupMenu.Items.Count <> 11) or
         (Frame.PmxCatalogFrame.PoseCatalogListView.PopupMenu.Items[0].Caption <>
           #$65B0#$898F#$8FFD#$52A0 + '(&R)') or
         (Frame.PmxCatalogFrame.PoseCatalogListView.PopupMenu.Items[2].Caption <>
           #$767B#$9332#$6E08#$307F + 'VPD' + #$304B#$3089 +
           #$8FFD#$52A0 + '...') or
         (Frame.PmxCatalogFrame.PoseCatalogListView.PopupMenu.Items[4].Caption <>
           #$540D#$79F0#$5909#$66F4 + '(&V)') or
         (Frame.PmxCatalogFrame.PoseCatalogListView.PopupMenu.Items[10].Caption <>
           #$6700#$65B0#$306E#$60C5#$5831 + '(&Z)') or
         (Frame.PmxCatalogFrame.PoseCatalogListView.PopupMenu.Items[1].ShortCut <>
           ShortCut(Ord('C'), [ssCtrl])) then
        raise Exception.Create('pose catalog context menu was not attached');
      if not Assigned(Frame.PmxCatalogFrame.PoseCatalogListView.OnKeyDown) then
        raise Exception.Create('pose catalog shortcuts were not attached');
      ShortcutKey := VK_F2;
      Frame.PmxCatalogFrame.PoseCatalogListView.OnKeyDown(
        Frame.PmxCatalogFrame.PoseCatalogListView, ShortcutKey, []);
      if (ShortcutKey <> 0) or
         not Frame.PmxCatalogFrame.PoseCatalogListView.CaptionEditing then
        raise Exception.Create('pose catalog F2 shortcut did not execute');
      Frame.PmxCatalogFrame.PoseCatalogListView.EndEdit(False);
      EditedPoseData := '{"version":1,"bones":[' +
        '{"name":"center","translation":[1,2,3],' +
        '"rotation":[0,0,0,1]}]}';
      EditedExpressionData := '{"version":1,"morphs":[' +
        '{"name":"smile","weight":0.75}]}';
      EditedEyeBlinkData :=
        '{"version":1,"morph":"blink","closedWeight":0.8}';
      LipSyncSetting := DefaultMmdLipSyncSetting;
      LipSyncSetting.Initialized := True;
      LipSyncSetting.OpenClose.MorphName := 'open';
      LipSyncSetting.OpenClose.Weight := 1.0;
      EditedLipSyncData := EncodeMmdLipSyncSettingData(LipSyncSetting);
      Frame.PmxCatalogFrame.PoseCatalog[0].PoseData := EditedPoseData;
      Frame.PmxCatalogFrame.PoseCatalog[0].InitialExpressionData :=
        EditedExpressionData;
      Frame.PmxCatalogFrame.PoseCatalog[0].InitialEyeBlinkData :=
        EditedEyeBlinkData;
      Frame.PmxCatalogFrame.PoseCatalog[0].InitialLipSyncData :=
        EditedLipSyncData;
      if not Frame.PmxCatalogFrame.PoseCatalog.SaveToFile then
        raise Exception.Create('edited pose was not saved');
      PoseFileName := TPath.Combine(TPath.Combine(TPath.Combine(
        Frame.PmxCatalogFrame.Catalog.ModelFolder(
          Frame.PmxCatalogFrame.Catalog.Items[0].Id), 'Poses'), 'Items'),
        Frame.PmxCatalogFrame.PoseCatalog[0].Id + '.json');
      PoseJson := TJSONObject.ParseJSONValue(TFile.ReadAllText(PoseFileName,
        TEncoding.UTF8));
      try
        if not (PoseJson is TJSONObject) or
          not (TJSONObject(PoseJson).GetValue('poseData') is TJSONObject) or
          not (TJSONObject(PoseJson).GetValue('initialExpressionData') is
            TJSONObject) or
          not (TJSONObject(PoseJson).GetValue('initialEyeBlinkData') is
            TJSONObject) or
          not (TJSONObject(PoseJson).GetValue('initialLipSyncData') is
            TJSONObject) then
          raise Exception.Create('poseData was not saved as a JSON object');
      finally
        PoseJson.Free;
      end;
      Frame.PmxCatalogFrame.OpenCatalog(CatalogFileName);
      if (Frame.PmxCatalogFrame.Catalog.Count <> 1) or
         (Frame.PmxCatalogFrame.CatalogListView.DisplayCount <> 1) or
         not SameText(Frame.PmxCatalogFrame.CatalogListView.DisplayName(0),
           'sample') then
        raise Exception.Create('PMX catalog was not restored');
      if not Assigned(Frame.PmxCatalogFrame.PoseCatalog) or
         (Frame.PmxCatalogFrame.PoseCatalog.Count <> 1) or
         (Frame.PmxCatalogFrame.PoseCatalogListView.DisplayCount <> 1) or
         (Frame.PmxCatalogFrame.PoseCatalogListView.DisplayName(0) <>
           #$521D#$671F#$72B6#$614B) or
         (Frame.PmxCatalogFrame.PoseCatalog[0].PoseData <> EditedPoseData) or
         (Frame.PmxCatalogFrame.PoseCatalog[0].InitialExpressionData <>
           EditedExpressionData) or
         (Frame.PmxCatalogFrame.PoseCatalog[0].InitialEyeBlinkData <>
           EditedEyeBlinkData) or
         (Frame.PmxCatalogFrame.PoseCatalog[0].InitialLipSyncData <>
           EditedLipSyncData) then
        raise Exception.Create('initial pose was not restored');
      PoseIndex := Frame.PmxCatalogFrame.PoseCatalog.Add;
      if (PoseIndex <> 1) or
         (Frame.PmxCatalogFrame.PoseCatalog.Count <> 2) then
        raise Exception.Create('pose catalog add failed');
      if not Frame.PmxCatalogFrame.PoseCatalog.Rename(PoseIndex,
           'renamed pose') or
         (Frame.PmxCatalogFrame.PoseCatalog[PoseIndex].Name <> 'renamed pose') then
        raise Exception.Create('pose catalog rename failed');
      PoseIndex := Frame.PmxCatalogFrame.PoseCatalog.Duplicate(PoseIndex);
      if (PoseIndex <> 2) or
         (Frame.PmxCatalogFrame.PoseCatalog.Count <> 3) then
        raise Exception.Create('pose catalog duplicate failed');
      PoseIndex := Frame.PmxCatalogFrame.PoseCatalog.Move(PoseIndex, -1);
      if (PoseIndex <> 1) or
         not Frame.PmxCatalogFrame.PoseCatalog.Remove(PoseIndex) or
         not Frame.PmxCatalogFrame.PoseCatalog.Remove(1) or
         (Frame.PmxCatalogFrame.PoseCatalog.Count <> 1) or
         not Frame.PmxCatalogFrame.PoseCatalog.IsInitial(0) or
         Frame.PmxCatalogFrame.PoseCatalog.Remove(0) then
        raise Exception.Create('pose catalog reorder/delete failed');

      ActualCatalogFileName := TPath.Combine(TPath.GetDocumentsPath,
        'MMDAnimationStudio\PMX\PmxCatalog.txt');
      if TFile.Exists(ActualCatalogFileName) then
      begin
        CatalogLines := TStringList.Create;
        try
          CatalogLines.LoadFromFile(ActualCatalogFileName, TEncoding.UTF8);
          PmxFileName := '';
          for CatalogFileName in CatalogLines do
            if TFile.Exists(CatalogFileName) then
            begin
              PmxFileName := CatalogFileName;
              Break;
            end;
          if PmxFileName <> '' then
          begin
            ThumbnailRenderer := TPmxCatalogThumbnailRenderer.Create(HostForm);
            Bitmap := TBitmap.Create;
            try
              ThumbnailRenderer.Parent := HostForm;
              if not ThumbnailRenderer.RenderPmx(PmxFileName, 128, 128,
                Bitmap) then
                raise Exception.Create('PMX thumbnail rendering failed');
              if (Bitmap.Width <> 128) or (Bitmap.Height <> 128) then
                raise Exception.Create('PMX thumbnail has an invalid size');
              CacheFolder := TPath.Combine(TPath.GetTempPath,
                'MMDAnimationStudio-' + TPath.GetRandomFileName);
              TDirectory.CreateDirectory(CacheFolder);
              ThumbnailCache := TPmxCatalogThumbnailCache.Create(CacheFolder);
              LoadedBitmap := TBitmap.Create;
              try
                if not ThumbnailCache.Save(PmxFileName, 128, 128, Bitmap) then
                  raise Exception.Create('PMX thumbnail cache save failed');
                if not ThumbnailCache.Load(PmxFileName, 128, 128,
                  LoadedBitmap) then
                  raise Exception.Create('PMX thumbnail cache load failed');
                if not ThumbnailCache.Clear then
                  raise Exception.Create('PMX thumbnail cache clear failed');
                if ThumbnailCache.Load(PmxFileName, 128, 128,
                  LoadedBitmap) then
                  raise Exception.Create('PMX thumbnail cache was not cleared');
              finally
                LoadedBitmap.Free;
                ThumbnailCache.Free;
                TDirectory.Delete(CacheFolder, True);
              end;
              Bitmap.SaveToFile(TPath.Combine(TPath.GetTempPath,
                'MMDAnimationStudio-PmxThumbnail-SmokeTest.bmp'));
            finally
              Bitmap.Free;
              ThumbnailRenderer.Free;
            end;
          end;
        finally
          CatalogLines.Free;
        end;
      end;
      if not Frame.PmxCatalogFrame.Catalog.RemoveAt(0) or
         (Frame.PmxCatalogFrame.Catalog.Count <> 0) then
        raise Exception.Create('PMX registration was not removed');
      if not TFile.Exists(PoseFileName) then
        raise Exception.Create('registration removal deleted model data');
      if not Frame.PmxCatalogFrame.Catalog.LoadFromFile or
         (Frame.PmxCatalogFrame.Catalog.Count <> 0) then
        raise Exception.Create('removed PMX registration was restored');
      TDirectory.Delete(TestCatalogRoot, True);
      Writeln('frame-shown');
    finally
      HostForm.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
