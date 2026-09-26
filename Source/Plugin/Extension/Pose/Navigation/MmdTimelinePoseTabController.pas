unit MmdTimelinePoseTabController;

// 拡張画面へマウスが入った際、選択中ポーズ用の編集タブを表示する。

interface

uses
  System.Classes,
  System.Types,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  MMDAnimationStudioToolbarController;

type
  TMmdTimelinePoseTabController = class(TComponent)
  private
    FHoverSurface: TWinControl;
    FButton: TToolButton;
    FToolbar: TMmdStudioToolbarController;
    FTimer: TTimer;
    FActive: Boolean;
    FWasHovered: Boolean;
    FHasTarget: Boolean;
    FLastObjectId: NativeUInt;
    FLastLayer, FLastStartFrame, FLastEndFrame: Integer;
    FLastModelFile: string;
    FCatalogIndex, FSyncIndex: Integer;
    FMissingReads: Integer;
    function Hovered: Boolean;
    procedure TimerTick(Sender: TObject);
  public
    // ホバー面とツールバーの同期タブを結び、選択監視の待機状態を作る。
    constructor CreateForToolbar(AOwner: TComponent; HoverSurface: TWinControl;
      Button: TToolButton; Toolbar: TMmdStudioToolbarController;
      CatalogIndex, SyncIndex: Integer);
    // ホバー中の選択監視を開始し、対象が見つかれば専用タブを表示する。
    procedure Start;
    // 選択監視を止め、専用タブを隠す。
    procedure Stop;
  end;

implementation

uses
  Winapi.Windows,
  MmdTimelinePoseBinding;

constructor TMmdTimelinePoseTabController.CreateForToolbar(
  AOwner: TComponent; HoverSurface: TWinControl; Button: TToolButton;
  Toolbar: TMmdStudioToolbarController; CatalogIndex, SyncIndex: Integer);
begin
  inherited Create(AOwner);
  FHoverSurface := HoverSurface;
  FButton := Button;
  FToolbar := Toolbar;
  FCatalogIndex := CatalogIndex;
  FSyncIndex := SyncIndex;
  FButton.Visible := False;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 250;
  FTimer.OnTimer := TimerTick;
end;

function TMmdTimelinePoseTabController.Hovered: Boolean;
var
  Cursor: TPoint;
  WindowAtCursor: HWND;
begin
  Result := False;
  if not FHoverSurface.Visible or not FHoverSurface.HandleAllocated or
    not GetCursorPos(Cursor) then Exit;
  WindowAtCursor := WindowFromPoint(Cursor);
  Result := (WindowAtCursor = FHoverSurface.Handle) or
    IsChild(FHoverSurface.Handle, WindowAtCursor);
end;

procedure TMmdTimelinePoseTabController.TimerTick(Sender: TObject);
var
  Snapshot: TMmdTimelinePoseSnapshot;
  Changed: Boolean;
begin
  FTimer.Enabled := False;
  try
    if not FActive then Exit;
    if not Hovered then
    begin
      FWasHovered := False;
      Exit;
    end;
    if FWasHovered and (FMissingReads = 0) then Exit;
    FWasHovered := True;
    try
      if TryReadSelectedMmdPose(Snapshot) then
      begin
        FMissingReads := 0;
        Changed := not FHasTarget or
          (FLastObjectId <> Snapshot.ObjectId) or
          (FLastLayer <> Snapshot.Layer) or
          (FLastStartFrame <> Snapshot.StartFrame) or
          (FLastEndFrame <> Snapshot.EndFrame) or
          (FLastModelFile <> Snapshot.ModelFile);
        FHasTarget := True;
        FLastObjectId := Snapshot.ObjectId;
        FLastLayer := Snapshot.Layer;
        FLastStartFrame := Snapshot.StartFrame;
        FLastEndFrame := Snapshot.EndFrame;
        FLastModelFile := Snapshot.ModelFile;
        if not FButton.Visible then
        begin
          FButton.Visible := True;
          FToolbar.UpdateHeight(FHoverSurface.CurrentPPI);
        end;
        if Changed and (FToolbar.ActiveIndex <> FSyncIndex) then
          FToolbar.Activate(FSyncIndex);
      end
      else
      begin
        Inc(FMissingReads);
        if FMissingReads < 2 then Exit;
        FMissingReads := 0;
        FHasTarget := False;
        FLastObjectId := 0;
        if FButton.Visible then
        begin
          FButton.Visible := False;
          FToolbar.UpdateHeight(FHoverSurface.CurrentPPI);
        end;
        if FToolbar.ActiveIndex = FSyncIndex then
          FToolbar.Activate(FCatalogIndex);
      end;
    except
      // SDK読取の一時失敗をページ切替タイマーの境界から漏らさない。
    end;
  finally
    FTimer.Enabled := FActive;
  end;
end;

procedure TMmdTimelinePoseTabController.Start;
begin
  FActive := True;
  FWasHovered := False;
  TimerTick(Self);
end;

procedure TMmdTimelinePoseTabController.Stop;
begin
  FActive := False;
  FWasHovered := False;
  FTimer.Enabled := False;
end;

end.
