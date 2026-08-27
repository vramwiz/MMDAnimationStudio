library MMDAnimationStudio;

uses
  Winapi.Windows,
  System.SysUtils,
  MMDAnimationStudioExtension in 'Source\Plugin\Extension\MMDAnimationStudioExtension.pas',
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
