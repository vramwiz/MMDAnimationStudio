program MmdExtensionUiSmokeTest;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.JSON,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  System.IOUtils,
  MmdMorphSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdEyeBlinkSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdEyeBlinkSettingCodec.pas',
  MmdLipSyncSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  MMDAnimationStudioFrame in '..\Source\Plugin\Extension\MMDAnimationStudioFrame.pas' {FrameMMDAnimationStudio: TFrame},
  PmxCatalogFrame in '..\Source\Plugin\Extension\PMX\Catalog\PmxCatalogFrame.pas' {FramePmxCatalog: TFrame},
  PmxCatalogStorage in '..\Source\Plugin\Extension\PMX\Catalog\PmxCatalogStorage.pas',
  PmxCatalogListView in '..\Source\Plugin\Extension\PMX\Catalog\View\PmxCatalogListView.pas',
  PmxPoseCatalogStorage in '..\Source\Plugin\Extension\PMX\Catalog\Pose\PmxPoseCatalogStorage.pas',
  PmxPoseCatalogDataValidation in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogDataValidation.pas',
  PmxPoseCatalogListView in '..\Source\Plugin\Extension\PMX\Catalog\Pose\View\PmxPoseCatalogListView.pas',
  PmxCatalogThumbnailCache in '..\Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailCache.pas',
  PmxCatalogThumbnailRenderer in '..\Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailRenderer.pas',
  MMDAnimationStudioToolbarIcons in '..\Source\Plugin\Extension\MMDAnimationStudioToolbarIcons.pas';

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

begin
  try
    Application.Initialize;
    HostForm := TForm.Create(nil);
    try
      HostPanel := TPanel.Create(HostForm);
      HostPanel.Parent := HostForm;
      HostPanel.Align := alClient;
      Frame := TFrameMMDAnimationStudio.Create(HostForm);
      Frame.Parent := HostPanel;
      Frame.Align := alClient;
      Frame.Show;
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
      if Frame.PmxCatalogFrame.DropEventCount <> 1 then
        raise Exception.Create('PMX drop event did not fire');
      if not SameText(Frame.PmxCatalogFrame.LastDroppedFile, 'sample.pmx') then
        raise Exception.Create('PMX drop file was not displayed');
      Frame.DropFiles(HostPanel, DroppedFiles);
      if Frame.PmxCatalogFrame.Catalog.Count <> 1 then
        raise Exception.Create('duplicate PMX path was registered');
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
