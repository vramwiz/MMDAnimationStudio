unit MMDAnimationStudioExtension;

interface

uses
  Winapi.Windows;

type
  TMMDSetPluginInformation = procedure(Information: PWideChar); cdecl;
  TMMDRegisterWindowClient = procedure(Name: PWideChar; WindowHandle: HWND); cdecl;

  PMMDHostAppTable = ^TMMDHostAppTable;
  TMMDHostAppTable = record
    SetPluginInformation: TMMDSetPluginInformation;
    RegisterInputPlugin: Pointer;
    RegisterOutputPlugin: Pointer;
    RegisterFilterPlugin: Pointer;
    RegisterScriptModule: Pointer;
    RegisterImportMenu: Pointer;
    RegisterExportMenu: Pointer;
    RegisterWindowClient: TMMDRegisterWindowClient;
  end;

const
  MMDPluginDisplayName: PWideChar =
    #$004D#$004D#$0044#$30A2#$30CB#$30E1#$30FC#$30B7#$30E7#$30F3#$30B9#$30BF#$30B8#$30AA;

procedure RegisterMMDAnimationStudioWindow(Host: PMMDHostAppTable);
procedure UnregisterMMDAnimationStudioWindow;

implementation

uses
  Winapi.Messages,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  DropFile,
  MMDAnimationStudioForm,
  MMDAnimationStudioFrame;

const
  MMDWindowClassName: PWideChar = 'MMDAnimationStudio.ExtensionWindow';

var
  ClientWindow: HWND;
  WindowForm: TFormMMDAnimationStudio;
  RootPanel: TPanel;
  WindowFrame: TFrameMMDAnimationStudio;
  WindowDropFile: TDropFile;
  WindowBrush: HBRUSH;

function ExtensionWindowProc(WindowHandle: HWND; MessageId: UINT;
  WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
begin
  case MessageId of
    WM_SIZE:
      begin
        if Assigned(RootPanel) then
          RootPanel.SetBounds(0, 0, LOWORD(LParam), HIWORD(LParam));
        if Assigned(WindowForm) then
          WindowForm.SetBounds(0, 0, LOWORD(LParam), HIWORD(LParam));
        Exit(0);
      end;
  end;

  Result := DefWindowProc(WindowHandle, MessageId, WParam, LParam);
end;

function RegisterExtensionWindowClass: Boolean;
var
  WindowClass: WNDCLASSEXW;
  ClassAtom: ATOM;
begin
  FillChar(WindowClass, SizeOf(WindowClass), 0);
  WindowClass.cbSize := SizeOf(WindowClass);
  WindowClass.lpszClassName := MMDWindowClassName;
  WindowClass.lpfnWndProc := @ExtensionWindowProc;
  WindowClass.hInstance := HInstance;
  WindowClass.hbrBackground := WindowBrush;
  WindowClass.hCursor := LoadCursor(0, IDC_ARROW);

  ClassAtom := RegisterClassExW(WindowClass);
  Result := (ClassAtom <> 0) or
    (GetLastError = ERROR_CLASS_ALREADY_EXISTS);
end;

procedure RegisterMMDAnimationStudioWindow(Host: PMMDHostAppTable);
var
  ClientRect: TRect;
begin
  if (Host = nil) or Assigned(WindowForm) then
    Exit;

  WindowBrush := CreateSolidBrush(RGB(36, 36, 36));
  if not RegisterExtensionWindowClass then
    Exit;

  ClientWindow := CreateWindowExW(0, MMDWindowClassName, MMDPluginDisplayName,
    WS_POPUP, 0, 0, 640, 480, 0, 0, HInstance, nil);
  if ClientWindow = 0 then
    Exit;

  Host^.RegisterWindowClient(MMDPluginDisplayName, ClientWindow);

  WindowForm := TFormMMDAnimationStudio.Create(nil);
  WindowForm.ParentWindow := ClientWindow;

  RootPanel := TPanel.Create(WindowForm);
  RootPanel.Parent := WindowForm;
  RootPanel.Align := alClient;
  RootPanel.BevelOuter := bvNone;
  RootPanel.Caption := '';
  RootPanel.ParentBackground := False;
  RootPanel.TabStop := True;

  WindowFrame := TFrameMMDAnimationStudio.Create(WindowForm);
  WindowFrame.Parent := RootPanel;
  WindowFrame.Align := alClient;
  WindowFrame.Visible := True;
  WindowFrame.Show;

  WindowDropFile := TDropFile.Create;
  WindowDropFile.Attach(RootPanel, WindowFrame.DropFiles);

  if GetClientRect(ClientWindow, ClientRect) then
    WindowForm.SetBounds(0, 0, ClientRect.Width, ClientRect.Height)
  else
    WindowForm.SetBounds(0, 0, 640, 480);
  WindowForm.Show;
end;

procedure UnregisterMMDAnimationStudioWindow;
begin
  FreeAndNil(WindowDropFile);
  FreeAndNil(WindowFrame);
  RootPanel := nil;
  FreeAndNil(WindowForm);

  if ClientWindow <> 0 then
  begin
    DestroyWindow(ClientWindow);
    ClientWindow := 0;
  end;

  UnregisterClassW(MMDWindowClassName, HInstance);

  if WindowBrush <> 0 then
  begin
    DeleteObject(WindowBrush);
    WindowBrush := 0;
  end;
end;

end.
