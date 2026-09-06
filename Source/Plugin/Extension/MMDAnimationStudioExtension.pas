unit MMDAnimationStudioExtension;

// AviUtl2拡張ウィンドウの登録、VCLホスト生成、ファイルドロップ境界を所有する。

interface

uses
  Winapi.Windows,
  AviUtl2PluginTypes;

type
  // AviUtl2 SDKの登録テーブルを部分再定義せず、プロジェクト／シーン通知を
  // 含む共通定義をそのまま利用する。
  PMMDHostAppTable = PHostAppTable;

const
  MMDPluginDisplayName: PWideChar =
    #$004D#$004D#$0044#$30A2#$30CB#$30E1#$30FC#$30B7#$30E7#$30F3#$30B9#$30BF#$30B8#$30AA;

// Hostへ拡張ウィンドウを1件登録し、MMDAnimationStudioのルート画面を生成する。
procedure RegisterMMDAnimationStudioWindow(Host: PMMDHostAppTable);
// 登録済み画面とWin32資源を破棄する。未登録の場合は何もしない。
procedure UnregisterMMDAnimationStudioWindow;

implementation

uses
  Winapi.Messages,
  System.JSON,
  System.SysUtils,
  Vcl.Controls,
  DarkPanel,
  DropFile,
  MmdAiPoseCatalogBridge,
  MmdAiPreviewPipeServer,
  MMDAnimationStudioForm,
  MMDAnimationStudioFrame;

const
  MMDWindowClassName: PWideChar = 'MMDAnimationStudio.ExtensionWindow';

var
  ClientWindow: HWND;
  WindowForm: TFormMMDAnimationStudio;
  RootPanel: TDarkPanel;
  WindowFrame: TFrameMMDAnimationStudio;
  WindowDropFile: TDropFile;
  WindowBrush: HBRUSH;
  AiPipeServer: TMmdAiPreviewPipeServer;

function ReadJsonString(const Root: TJSONObject; const Name: string): string;
var
  Value: TJSONValue;
begin
  Result := '';
  Value := Root.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

procedure HandleAiCreatePose;
var
  ErrorText, ModelFile, PmxId, PoseData, PoseFile, PoseId, PoseName,
    RegisteredPmxId, RequestText, ResponseText: string;
  Response: TJSONObject;
  Root: TJSONObject;
  Value: TJSONValue;
begin
  ErrorText := '';
  ResponseText := '';
  try
    if not TakePendingMmdAiPoseFile(RequestText) then
      ErrorText := 'AIポーズ登録要求がありません。'
    else if not Assigned(WindowFrame) then
      ErrorText := 'MMDAnimationStudioの画面が初期化されていません。'
    else
    begin
      Value := TJSONObject.ParseJSONValue(RequestText);
      try
        if not (Value is TJSONObject) then
          raise EArgumentException.Create('ポーズ登録要求がJSON objectではありません。');
        Root := TJSONObject(Value);
        PmxId := ReadJsonString(Root, 'pmx_id');
        ModelFile := ReadJsonString(Root, 'model_file');
        PoseName := ReadJsonString(Root, 'pose_name');
        PoseData := ReadJsonString(Root, 'pose_data');
        if WindowFrame.RegisterAiPose(PmxId, ModelFile, PoseName,
          PoseData, RegisteredPmxId, PoseFile, PoseId, ErrorText) then
        begin
          Response := TJSONObject.Create;
          try
            Response.AddPair('status', 'ok');
            Response.AddPair('operation', 'create_pose_file');
            Response.AddPair('pmx_id', RegisteredPmxId);
            Response.AddPair('pose_id', PoseId);
            Response.AddPair('pose_file', PoseFile);
            Response.AddPair('pose_name', PoseName);
            ResponseText := Response.ToJSON;
          finally
            Response.Free;
          end;
        end;
      finally
        Value.Free;
      end;
    end;
  except
    on E: Exception do
      ErrorText := E.Message;
  end;
  CompleteMmdAiPoseFile(ResponseText, ErrorText);
end;

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
    WM_MMD_AI_CREATE_POSE_FILE:
      begin
        HandleAiCreatePose;
        Exit(1);
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

  RootPanel := TDarkPanel.Create(WindowForm);
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
  RegisterMmdAiPoseCatalogWindow(ClientWindow);
  AiPipeServer := TMmdAiPreviewPipeServer.Create;
  AiPipeServer.Start;
end;

procedure UnregisterMMDAnimationStudioWindow;
begin
  if Assigned(AiPipeServer) then
  begin
    AiPipeServer.Stop;
    FreeAndNil(AiPipeServer);
  end;
  UnregisterMmdAiPoseCatalogWindow(ClientWindow);
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
