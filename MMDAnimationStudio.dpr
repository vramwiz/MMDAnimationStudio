library MMDAnimationStudio;

uses
  Winapi.Windows,
  System.SysUtils,
  AppFolderUtils in '..\AviUtl2PluginLib\Lib\AppFolderUtils\AppFolderUtils.pas',
  MMDAnimationStudioExtension in 'Source\Plugin\Extension\MMDAnimationStudioExtension.pas',
  MMDAnimationStudioToolbarIcons in 'Source\Plugin\Extension\MMDAnimationStudioToolbarIcons.pas',
  MMDAnimationStudioFrame in 'Source\Plugin\Extension\MMDAnimationStudioFrame.pas' {FrameMMDAnimationStudio: TFrame},
  PmxCatalogFrame in 'Source\Plugin\Extension\PMX\Catalog\PmxCatalogFrame.pas' {FramePmxCatalog: TFrame},
  PmxCatalogStorage in 'Source\Plugin\Extension\PMX\Catalog\PmxCatalogStorage.pas',
  PmxCatalogListView in 'Source\Plugin\Extension\PMX\Catalog\View\PmxCatalogListView.pas',
  PmxPoseCatalogStorage in 'Source\Plugin\Extension\PMX\Catalog\Pose\PmxPoseCatalogStorage.pas',
  PmxPoseCatalogListView in 'Source\Plugin\Extension\PMX\Catalog\Pose\View\PmxPoseCatalogListView.pas',
  PmxPoseCatalogEditor in 'Source\Plugin\Extension\PMX\Catalog\Pose\Editor\PmxPoseCatalogEditor.pas',
  PmxCatalogThumbnailCache in 'Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailCache.pas',
  PmxCatalogThumbnailRenderer in 'Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailRenderer.pas',
  MMDAnimationStudioForm in 'Source\Plugin\Extension\MMDAnimationStudioForm.pas' {FormMMDAnimationStudio};

{$R *.res}

function InitializePlugin(Version: DWORD): BOOL; cdecl;
begin
  try
    Result := True;
  except
    Result := False;
  end;
end;

procedure UninitializePlugin; cdecl;
begin
  try
    UnregisterMMDAnimationStudioWindow;
  except
    { DLL境界から例外を漏らさない。 }
  end;
end;

procedure RegisterPlugin(Host: PMMDHostAppTable); cdecl;
begin
  try
    SetAppFolderRoot('MMDAnimationStudio');
    if Host = nil then
      Exit;

    Host^.SetPluginInformation(MMDPluginDisplayName);
    RegisterMMDAnimationStudioWindow(Host);
  except
    { DLL境界から例外を漏らさない。 }
  end;
end;

procedure InitializeLogger(Logger: Pointer); cdecl;
begin
end;

exports
  InitializeLogger,
  InitializePlugin,
  UninitializePlugin,
  RegisterPlugin;

begin
end.
