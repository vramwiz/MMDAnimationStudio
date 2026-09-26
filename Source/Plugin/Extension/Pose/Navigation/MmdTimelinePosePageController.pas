unit MmdTimelinePosePageController;

// ポーズページでカタログと選択中Script編集画面を切り替える。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  MmdTimelinePoseEditorFrame;

type
  TMmdTimelinePosePageController = class(TComponent)
  private
    FActive: Boolean;
    FMissingReads: Integer;
    FWasHovered: Boolean;
    FCatalog: TControl;
    FEditor: TFrameMmdTimelinePoseEditor;
    FParentPanel: TWinControl;
    FTimer: TTimer;
    procedure EnsureEditor;
    function Hovered: Boolean;
    procedure TimerTick(Sender: TObject);
  public
    // 同期タブの表示先と未選択時の案内表示を保持する。
    constructor CreateForPage(AOwner: TComponent; ParentPanel: TWinControl;
      Catalog: TControl);
    // 選択監視と編集画面を破棄する。
    destructor Destroy; override;
    // ページ表示中に選択対象を監視する。シーン変更直後は再取得を遅延できる。
    procedure Activate(RefreshNow: Boolean = True);
    // ページを離れる際に入力デバイスを解放し、カタログ表示へ戻す。
    procedure Deactivate;
    // 現在の選択を読み、対象の変更に応じて編集画面を再接続する。
    procedure UpdateSelection;
    property Editor: TFrameMmdTimelinePoseEditor read FEditor;
  end;

implementation

uses
  Winapi.Windows,
  MmdTimelinePoseBinding,
  MmdTimelinePoseDebugLog,
  System.SysUtils;

constructor TMmdTimelinePosePageController.CreateForPage(
  AOwner: TComponent; ParentPanel: TWinControl; Catalog: TControl);
begin
  inherited Create(AOwner);
  FParentPanel := ParentPanel;
  FCatalog := Catalog;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 250;
  FTimer.OnTimer := TimerTick;
end;

destructor TMmdTimelinePosePageController.Destroy;
begin
  Deactivate;
  inherited;
end;

procedure TMmdTimelinePosePageController.EnsureEditor;
begin
  if FEditor <> nil then Exit;
  FEditor := TFrameMmdTimelinePoseEditor.Create(Self);
  FEditor.Parent := FParentPanel;
  FEditor.Align := alClient;
  FEditor.InitializeControls;
  FEditor.Visible := False;
end;

function TMmdTimelinePosePageController.Hovered: Boolean;
var
  Cursor: TPoint;
  WindowAtCursor: HWND;
begin
  Result := False;
  if not FParentPanel.Visible or not FParentPanel.HandleAllocated or
    not GetCursorPos(Cursor) then Exit;
  WindowAtCursor := WindowFromPoint(Cursor);
  Result := (WindowAtCursor = FParentPanel.Handle) or
    IsChild(FParentPanel.Handle, WindowAtCursor);
end;

procedure TMmdTimelinePosePageController.Activate(RefreshNow: Boolean);
begin
  FActive := True;
  if RefreshNow then
  begin
    try
      UpdateSelection;
    except
      Deactivate;
    end;
  end;
  FWasHovered := RefreshNow and Hovered;
  FTimer.Enabled := FActive;
end;

procedure TMmdTimelinePosePageController.Deactivate;
begin
  FActive := False;
  FMissingReads := 0;
  FWasHovered := False;
  FTimer.Enabled := False;
  if FEditor <> nil then
  begin
    FEditor.ClearTarget;
    FEditor.Visible := False;
  end;
  if FCatalog <> nil then FCatalog.Visible := True;
end;

procedure TMmdTimelinePosePageController.UpdateSelection;
var
  Snapshot: TMmdTimelinePoseSnapshot;
begin
  if TryReadSelectedMmdPose(Snapshot) then
  begin
    {$IFDEF DEBUG}
    if FMissingReads <> 0 then
      PoseDebugLog('page.selection_restored',
        'misses=' + IntToStr(FMissingReads));
    {$ENDIF}
    FMissingReads := 0;
    EnsureEditor;
    FEditor.BindSnapshot(Snapshot);
    FCatalog.Visible := False;
    FEditor.Visible := True;
  end
  else
  begin
    {$IFDEF DEBUG}
    PoseDebugLog('page.selection_missing',
      'bound=' + BoolToStr((FEditor <> nil) and FEditor.Bound, True) +
      ' misses=' + IntToStr(FMissingReads + 1));
    {$ENDIF}
    if (FEditor <> nil) and FEditor.Bound then
    begin
      Inc(FMissingReads);
      if FMissingReads < 2 then Exit;
      FMissingReads := 0;
    end;
    if (FEditor <> nil) and (FEditor.Bound or FEditor.Visible) then
    begin
      FEditor.ClearTarget;
      FEditor.Visible := False;
    end;
    FCatalog.Visible := True;
  end;
end;

procedure TMmdTimelinePosePageController.TimerTick(Sender: TObject);
var
  IsHovered: Boolean;
begin
  FTimer.Enabled := False;
  try
    try
      IsHovered := Hovered;
      if not IsHovered then
      begin
        FWasHovered := False;
        Exit;
      end;
      if FWasHovered and (FMissingReads = 0) then Exit;
      FWasHovered := True;
      {$IFDEF DEBUG}PoseDebugLog('page.selection_refresh', 'hover_enter');{$ENDIF}
      UpdateSelection;
    except
      on E: Exception do
      begin
        {$IFDEF DEBUG}
        PoseDebugLog('page.timer_exception', E.ClassName + ': ' + E.Message);
        {$ENDIF}
        // ホストSDK呼出しの失敗をVCLタイマー境界から漏らさない。
      end;
    end;
  finally
    FTimer.Enabled := FActive;
  end;
end;

end.
