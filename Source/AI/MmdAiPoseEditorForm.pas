unit MmdAiPoseEditorForm;

// モデル設定フォームへAI候補の反映と簡易ポーズ編集・ゲームパッド操作を接続する。

interface

uses
  Winapi.Messages,
  System.Classes,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  DarkLabel,
  DarkPanel,
  MmdAiPoseSession,
  MmdSimpleControllerPanel,
  MmdSimpleControllerSolver,
  MmdProControllerInput,
  MmdModelSettingEditor,
  MmdPoseEditorComboTheme,
  MmdPoseEditorButtonTheme,
  PmxModel,
  PmxPose;

type
  TMmdSimpleEditStage = (sesBegin, sesEnd);

  TMmdAiPoseEditorForm = class(TMmdModelSettingEditorForm)
  private
    FAiPanel: TDarkPanel;
    FCandidateLabel: TDarkLabel;
    FDisplayCombo: TMmdDarkComboBox;
    FModelFile: string;
    FPoseName: string;
    FSessionId: string;
    FSessionRegistered: Boolean;
    FSimpleBeforePoses: TPmxBonePoses;
    FSimpleChanged: Boolean;
    FSimpleEditing: Boolean;
    FTopToolbarPanel: TDarkPanel;
    FSimpleModeButton: TMmdDarkButton;
    FSimplePanel: TMmdSimpleControllerPanel;
    FSimpleVisible: Boolean;
    FGamepadInput: TMmdProControllerInput;
    FGamepadTimer: TTimer;
    FGamepadPending: Boolean;
    FGamepadAwaitNeutral: Boolean;
    FGamepadController: TMmdSimpleController;
    FGamepadPreviousButtons: Cardinal;
    FGamepadPreviousPOV: Cardinal;
    FGamepadLastTick: UInt64;
    FGamepadZoomDirection: Integer;
    FGamepadZoomStartTick: UInt64;
    FGamepadOverlayVisible: Boolean;
    FGamepadStatusPanel: TDarkPanel;
    FGamepadStatusLabel: TDarkLabel;
    FWindowCloseRequested: Boolean;
    FStatusLabel: TDarkLabel;
    procedure ApplyDisplayMode;
    procedure LayoutToolbarControls;
    procedure DisplayModeChanged(Sender: TObject);
    procedure SimpleControllerChanged(Sender: TObject;
      Controller: TMmdSimpleController);
    function SelectedViewportBone: Integer;
    procedure ApplySimpleEditStage(Controller: TMmdSimpleController;
      Stage: TMmdSimpleEditStage);
    procedure ApplyGamepadStep(X, Y, Z, Twist, Bend,
      TipPitch: Single);
    procedure GamepadTick(Sender: TObject);
    procedure GamepadActivated(Sender: TObject);
    procedure GamepadDeactivated(Sender: TObject);
    procedure StopGamepadInput;
    procedure SelectByDirection(POV: Cardinal);
    procedure CancelGamepadEdit;
    procedure FinishGamepadEdit;
    procedure SimpleCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure SimpleInitialStateCloseQuery(Sender: TObject;
      var CanClose: Boolean);
    procedure ResetSelectedController;
    procedure SimpleModeClick(Sender: TObject);
    procedure SetSimpleVisible(Value: Boolean);
    procedure WmAiPose(var Message: TMessage);
      message WM_MMD_AI_PREVIEW_SESSION_POSE;
    procedure WmClose(var Message: TMessage); message WM_CLOSE;
  protected
    procedure EnableSimpleControls;
    function ProControllerAvailable: Boolean; virtual;
    procedure DoShow; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure PoseStateChanged; override;
    procedure SettingPageChanged(Page: TMmdModelSettingPage); override;
  public
    // 共通設定フォームを生成し、Codexが識別するモデルとポーズ名を保持する。
    constructor CreateAiEditor(const ModelFileName, PoseData,
      EditorCaption, PoseName: string);
    destructor Destroy; override;
    property AiStatusLabel: TDarkLabel read FStatusLabel;
    property DisplayCombo: TMmdDarkComboBox read FDisplayCombo;
  end;

// 初期状態の全設定をAI対応フォームで編集し、確定時だけ呼出元へ返す。
function EditMmdAiInitialStateSettings(const ModelFileName, CurrentPoseData,
  CurrentExpressionData, CurrentEyeBlinkData, CurrentLipSyncData,
  EditorCaption, PoseName: string; out NewPoseData, NewExpressionData,
  NewEyeBlinkData, NewLipSyncData: string): Boolean;
// ポーズ専用のAI対応フォームを開き、確定時だけ姿勢を返す。
function EditMmdAiPoseOnlySettings(const ModelFileName, CurrentPoseData,
  EditorCaption, PoseName: string; out NewPoseData: string): Boolean;

implementation

uses
  Winapi.Windows,
  System.JSON,
  System.Math,
  System.SysUtils,
  Vcl.Controls,
  Vcl.Graphics,
  MmdMorphSettingCodec,
  MmdPoseEditorTheme;

function ReadString(const Root: TJSONObject; const Name,
  DefaultValue: string): string;
var
  Value: TJSONValue;
begin
  Result := DefaultValue;
  Value := Root.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function NewSessionId: string;
var
  Id: TGUID;
begin
  Result := '';
  if CreateGUID(Id) <> S_OK then
    Exit;
  Result := LowerCase(GUIDToString(Id));
  Result := Result.Replace('{', '').Replace('}', '').Replace('-', '');
end;

constructor TMmdAiPoseEditorForm.CreateAiEditor(const ModelFileName,
  PoseData, EditorCaption, PoseName: string);
var
  PPI: Integer;
begin
  inherited CreateEditor(ModelFileName, PoseData, EditorCaption);
  FModelFile := ModelFileName;
  FPoseName := PoseName;
  FSessionId := NewSessionId;
  PPI := CurrentPPI;
  if PPI <= 0 then
    PPI := 96;

  FAiPanel := TDarkPanel.Create(Self);
  FAiPanel.Parent := Self;
  FAiPanel.Align := alTop;
  FAiPanel.Height := MulDiv(42, PPI, 96);
  FAiPanel.BevelOuter := bvNone;
  FAiPanel.ParentBackground := False;
  FAiPanel.Color := MmdEditorPanel;

  FDisplayCombo := TMmdDarkComboBox.Create(Self);
  FDisplayCombo.Parent := FAiPanel;
  FDisplayCombo.Style := csOwnerDrawFixed;
  FDisplayCombo.ApplyDpi;
  FDisplayCombo.Items.Add('通常');
  FDisplayCombo.Items.Add('ボーンのみ');
  FDisplayCombo.Items.Add('通常＋ボーン');
  FDisplayCombo.ItemIndex := 2;
  FDisplayCombo.SetBounds(MulDiv(8, PPI, 96), MulDiv(7, PPI, 96),
    MulDiv(135, PPI, 96), MulDiv(28, PPI, 96));
  FDisplayCombo.OnChange := DisplayModeChanged;

  FCandidateLabel := TDarkLabel.Create(Self);
  FCandidateLabel.Parent := FAiPanel;
  FCandidateLabel.AutoSize := False;
  FCandidateLabel.ApplyDpi;
  FCandidateLabel.Caption := 'AI候補: 未受信';
  FCandidateLabel.SetBounds(MulDiv(155, PPI, 96), MulDiv(2, PPI, 96),
    MulDiv(600, PPI, 96), MulDiv(18, PPI, 96));
  FCandidateLabel.Anchors := [akLeft, akTop, akRight];

  FStatusLabel := TDarkLabel.Create(Self);
  FStatusLabel.Parent := FAiPanel;
  FStatusLabel.AutoSize := False;
  FStatusLabel.ApplyDpi;
  FStatusLabel.Caption := 'Codexからのポーズを待機中';
  FStatusLabel.SetBounds(MulDiv(155, PPI, 96), MulDiv(21, PPI, 96),
    MulDiv(600, PPI, 96), MulDiv(20, PPI, 96));
  FStatusLabel.Anchors := [akLeft, akTop, akRight];
  ApplyDisplayMode;
end;

destructor TMmdAiPoseEditorForm.Destroy;
begin
  if FGamepadTimer <> nil then FGamepadTimer.Enabled := False;
  FGamepadInput.Free;
  if FSessionRegistered and HandleAllocated then
    UnregisterMmdAiPoseSession(Handle);
  inherited Destroy;
end;

procedure TMmdAiPoseEditorForm.DoShow;
begin
  inherited DoShow;
  if FSimplePanel <> nil then
    SetSimpleVisible(FSimpleVisible);
  if FSessionRegistered then
    Exit;
  RegisterMmdAiPoseSession(Handle, FSessionId, FModelFile, FPoseName,
    EncodeCurrentPose);
  FSessionRegistered := True;
end;

procedure TMmdAiPoseEditorForm.PoseStateChanged;
begin
  inherited PoseStateChanged;
  if FSimpleVisible and (FSimplePanel <> nil) and
    (FViewport.SelectedBone <> SelectedViewportBone) then
    FViewport.SetScene(FModel, FPoses, SelectedViewportBone);
  if FSessionRegistered and HandleAllocated then
    UpdateMmdAiPoseSession(Handle, EncodeCurrentPose);
end;

procedure TMmdAiPoseEditorForm.SettingPageChanged(
  Page: TMmdModelSettingPage);
begin
  inherited SettingPageChanged(Page);
  if FSimplePanel <> nil then SetSimpleVisible(FSimpleVisible);
end;

procedure TMmdAiPoseEditorForm.ApplyDisplayMode;
begin
  if CurrentSettingPage <> mspPose then Exit;
  if FSimpleVisible then
  begin
    FViewport.SetDisplayVisibility(True, FGamepadOverlayVisible, True);
    Exit;
  end;
  case FDisplayCombo.ItemIndex of
    0: FViewport.SetDisplayVisibility(True, False);
    1: FViewport.SetDisplayVisibility(False, True);
  else
    FViewport.SetDisplayVisibility(True, True);
  end;
end;

procedure TMmdAiPoseEditorForm.DisplayModeChanged(Sender: TObject);
begin
  ApplyDisplayMode;
end;

function TMmdAiPoseEditorForm.ProControllerAvailable: Boolean;
begin
  Result := False;
  if FGamepadInput <> nil then
    Result := FGamepadInput.ProbeConnection;
end;

procedure TMmdAiPoseEditorForm.EnableSimpleControls;
var
  PPI: Integer;
begin
  if FSimplePanel <> nil then Exit;
  PPI := CurrentPPI;
  if PPI <= 0 then PPI := 96;
  // 動的に追加した簡易パネルはCreateNew時のフォーム拡大を受けない環境がある。
  // 実DPI相当の編集領域を確保してから子コントロールを並べる。
  if Width < MulDiv(980, PPI, 96) then
    Width := MulDiv(980, PPI, 96);
  if Height < MulDiv(680, PPI, 96) then
    Height := MulDiv(680, PPI, 96);
  if Constraints.MinWidth < MulDiv(850, PPI, 96) then
    Constraints.MinWidth := MulDiv(850, PPI, 96);
  if Constraints.MinHeight < MulDiv(630, PPI, 96) then
    Constraints.MinHeight := MulDiv(630, PPI, 96);
  if FLeftPanel.Width < MulDiv(245, PPI, 96) then
    FLeftPanel.Width := MulDiv(245, PPI, 96);
  FTopToolbarPanel := TDarkPanel.Create(Self);
  FTopToolbarPanel.Parent := Self;
  FTopToolbarPanel.Align := alTop;
  FTopToolbarPanel.Height := MulDiv(40, PPI, 96);
  FTopToolbarPanel.BevelOuter := bvNone;
  FTopToolbarPanel.ParentBackground := False;
  FTopToolbarPanel.Color := MmdEditorPanel;
  FCommandToolbar.Parent := FTopToolbarPanel;
  FCommandToolbar.Align := alClient;
  FCommandToolbar.ButtonHeight := MulDiv(40, PPI, 96);
  FDisplayCombo.Parent := FTopToolbarPanel;
  FSimpleModeButton := TMmdDarkButton.Create(Self);
  FSimpleModeButton.Parent := FTopToolbarPanel;
  FSimpleModeButton.ParentFont := False;
  FSimpleModeButton.Font.Assign(Font);
  FSimpleModeButton.OnClick := SimpleModeClick;
  FSimplePanel := TMmdSimpleControllerPanel.Create(Self);
  FSimplePanel.Parent := FLeftPanel;
  FSimplePanel.Align := alClient;
  FSimplePanel.ApplyLayout;
  FSimplePanel.SetModel(FModel);
  FSimplePanel.OnSelectionChanged := SimpleControllerChanged;
  FGamepadStatusPanel := TDarkPanel.Create(Self);
  FGamepadStatusPanel.Parent := FTopToolbarPanel;
  FGamepadStatusPanel.BevelOuter := bvNone;
  FGamepadStatusPanel.ParentBackground := False;
  FGamepadStatusPanel.Color := MmdEditorPanel;
  FGamepadStatusLabel := TDarkLabel.Create(Self);
  FGamepadStatusLabel.Parent := FGamepadStatusPanel;
  FGamepadStatusLabel.AutoSize := False;
  FGamepadStatusLabel.ApplyDpi;
  FGamepadStatusLabel.Caption := 'Pro: 未接続';
  FCommandToolbar.SendToBack;
  LayoutToolbarControls;
  FGamepadInput := TMmdProControllerInput.Create;
  OnActivate := GamepadActivated;
  OnDeactivate := GamepadDeactivated;
  FGamepadPreviousPOV := $FFFF;
  FGamepadTimer := TTimer.Create(Self);
  FGamepadTimer.Enabled := False;
  FGamepadTimer.Interval := 33;
  FGamepadTimer.OnTimer := GamepadTick;
  SetSimpleVisible(True);
end;

procedure TMmdAiPoseEditorForm.LayoutToolbarControls;
var
  PPI, ControlHeight, LeftEdge: Integer;
begin
  PPI := CurrentPPI;
  if PPI <= 0 then PPI := 96;
  ControlHeight := MulDiv(28, PPI, 96);
  LeftEdge := MulDiv(242, PPI, 96);
  FDisplayCombo.SetBounds(LeftEdge,
    (FTopToolbarPanel.ClientHeight - ControlHeight) div 2,
    MulDiv(136, PPI, 96), ControlHeight);
  if not FSimpleVisible then
    Inc(LeftEdge, MulDiv(144, PPI, 96));
  FSimpleModeButton.SetBounds(LeftEdge,
    (FTopToolbarPanel.ClientHeight - ControlHeight) div 2,
    MulDiv(156, PPI, 96), ControlHeight);
  Inc(LeftEdge, MulDiv(164, PPI, 96));
  FGamepadStatusPanel.SetBounds(LeftEdge,
    (FTopToolbarPanel.ClientHeight - ControlHeight) div 2,
    MulDiv(118, PPI, 96), ControlHeight);
  FGamepadStatusLabel.SetBounds(MulDiv(4, PPI, 96), 0,
    FGamepadStatusPanel.Width - MulDiv(4, PPI, 96), ControlHeight);
  Inc(LeftEdge, MulDiv(126, PPI, 96));
  if SaveButton.Parent = FTopToolbarPanel then
    SaveButton.SetBounds(LeftEdge,
      (FTopToolbarPanel.ClientHeight - ControlHeight) div 2,
      MulDiv(104, PPI, 96), ControlHeight);
end;

procedure TMmdAiPoseEditorForm.SetSimpleVisible(Value: Boolean);
var
  PosePage: Boolean;
  PPI: Integer;
begin
  if FSimplePanel = nil then Exit;
  PosePage := CurrentSettingPage = mspPose;
  if Value and PosePage and not ProControllerAvailable then
  begin
    Value := False;
    FGamepadStatusLabel.Caption := 'Pro: 未接続';
  end;
  if FGamepadPending then FinishGamepadEdit;
  FSimpleVisible := Value;
  if not (Value and PosePage) then StopGamepadInput;
  FGamepadLastTick := 0;
  FGamepadZoomDirection := 0;
  if FGamepadTimer <> nil then FGamepadTimer.Enabled := Value and PosePage;
  FSimplePanel.Visible := Value and PosePage;
  FTopToolbarPanel.Visible := PosePage;
  FDisplayCombo.Visible := PosePage and not Value;
  FSimpleModeButton.Visible := PosePage;
  FGamepadStatusPanel.Visible := Value and PosePage;
  FAiPanel.Visible := not (Value and PosePage);
  if Value and PosePage then
  begin
    SaveButton.Parent := FTopToolbarPanel;
    SaveButton.Anchors := [akLeft, akTop];
    CommitPanel.Visible := False;
  end
  else
  begin
    CommitPanel.Visible := True;
    if SaveButton.Parent <> CommitPanel then
    begin
      PPI := CurrentPPI;
      if PPI <= 0 then PPI := 96;
      SaveButton.Parent := CommitPanel;
      SaveButton.SetBounds(CommitPanel.ClientWidth - MulDiv(127, PPI, 96),
        MulDiv(10, PPI, 96), MulDiv(111, PPI, 96), MulDiv(32, PPI, 96));
      SaveButton.Anchors := [akTop, akRight];
    end;
  end;
  LayoutToolbarControls;
  FBoneList.Visible := (not Value) and PosePage;
  FResetBoneButton.Visible := (not Value) and PosePage;
  FResetBranchButton.Visible := (not Value) and PosePage;
  FSymmetryButton.Visible := (not Value) and PosePage;
  FAutoFitButton.Visible := (not Value) and PosePage;
  if PosePage then
  begin
    FViewport.ReadOnly := Value;
    ApplyDisplayMode;
    FViewport.SetScene(FModel, FPoses, SelectedViewportBone);
  end;
  if Value then
    FSimpleModeButton.Caption := '詳細ボーン編集へ'
  else
    FSimpleModeButton.Caption := '簡易操作へ';
end;

procedure TMmdAiPoseEditorForm.StopGamepadInput;
begin
  if FGamepadTimer <> nil then FGamepadTimer.Enabled := False;
  if FGamepadInput <> nil then FGamepadInput.Disconnect;
  FGamepadPreviousButtons := 0;
  FGamepadPreviousPOV := $FFFF;
  FGamepadLastTick := 0;
  FGamepadZoomDirection := 0;
end;

procedure TMmdAiPoseEditorForm.GamepadActivated(Sender: TObject);
begin
  if FSimpleVisible and (CurrentSettingPage = mspPose) then
    SetSimpleVisible(True);
end;

procedure TMmdAiPoseEditorForm.GamepadDeactivated(Sender: TObject);
begin
  if FGamepadPending then FinishGamepadEdit;
  StopGamepadInput;
end;

procedure TMmdAiPoseEditorForm.SelectByDirection(POV: Cardinal);
begin
  if (POV <> 0) and (POV <> 18000) then Exit;
  if not FSimpleVisible or (FSimplePanel = nil) then Exit;
  // 部位を変える入力は、現在のプレビュー操作を確定してから選択を移す。
  if FGamepadPending then
  begin
    ApplySimpleEditStage(FGamepadController, sesEnd);
    FGamepadPending := False;
    FGamepadAwaitNeutral := True;
  end;
  if not FSimpleEditing then FSimplePanel.Navigate(POV);
end;

procedure TMmdAiPoseEditorForm.KeyDown(var Key: Word; Shift: TShiftState);
var
  POV: Cardinal;
begin
  if FSimpleVisible and (CurrentSettingPage = mspPose) and
    (Shift = []) and
    (ActiveControl <> FDisplayCombo) and
    not (ActiveControl is TCustomEdit) then
  begin
    POV := $FFFF;
    case Key of
      VK_UP: POV := 0;
      VK_DOWN: POV := 18000;
    end;
    if POV <> $FFFF then
    begin
      SelectByDirection(POV);
      Key := 0;
      Exit;
    end;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure TMmdAiPoseEditorForm.SimpleModeClick(Sender: TObject);
begin
  SetSimpleVisible(not FSimpleVisible);
end;

function TMmdAiPoseEditorForm.SelectedViewportBone: Integer;
begin
  if FSimpleVisible and (FSimplePanel <> nil) and
    (CurrentSettingPage = mspPose) then
    Result := SimpleControllerTargetBone(FModel,
      FSimplePanel.SelectedController)
  else
    Result := FBoneList.ItemIndex;
end;

procedure TMmdAiPoseEditorForm.SimpleControllerChanged(Sender: TObject;
  Controller: TMmdSimpleController);
begin
  if FSimpleVisible and (CurrentSettingPage = mspPose) then
    FViewport.SetScene(FModel, FPoses, SelectedViewportBone);
end;

procedure TMmdAiPoseEditorForm.ApplySimpleEditStage(
  Controller: TMmdSimpleController; Stage: TMmdSimpleEditStage);
begin
  if FModel = nil then Exit;
  if Stage = sesBegin then
  begin
    FSimpleBeforePoses := Copy(FPoses);
    FSimpleChanged := False;
    FSimpleEditing := CanUseSimpleController(FModel, Controller);
    Exit;
  end;
  if not FSimpleEditing then
  begin
    if Stage = sesEnd then FSimpleBeforePoses := nil;
    Exit;
  end;
  if Stage = sesEnd then
  begin
    if FSimpleChanged then
    begin
      FHistory.RecordBeforeEdit(FSimpleBeforePoses);
      FUndoButton.Enabled := FHistory.CanUndo;
      FRedoButton.Enabled := FHistory.CanRedo;
      PoseStateChanged;
    end;
    FSimpleEditing := False;
    FSimpleBeforePoses := nil;
  end;
end;

procedure TMmdAiPoseEditorForm.CancelGamepadEdit;
begin
  if not FGamepadPending then Exit;
  FPoses := Copy(FSimpleBeforePoses);
  FViewport.SetScene(FModel, FPoses, SelectedViewportBone);
  FSimpleEditing := False;
  FSimpleChanged := False;
  FSimpleBeforePoses := nil;
  FGamepadPending := False;
  FGamepadAwaitNeutral := True;
end;

procedure TMmdAiPoseEditorForm.FinishGamepadEdit;
begin
  if not FGamepadPending then Exit;
  ApplySimpleEditStage(FGamepadController, sesEnd);
  FGamepadPending := False;
  FGamepadAwaitNeutral := True;
end;

procedure TMmdAiPoseEditorForm.WmClose(var Message: TMessage);
begin
  FWindowCloseRequested := True;
  inherited;
end;

procedure TMmdAiPoseEditorForm.SimpleCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  if FWindowCloseRequested or (ModalResult = mrNone) then
    ModalResult := mrOk;
  FWindowCloseRequested := False;
  if FGamepadPending then
    if ModalResult = mrCancel then CancelGamepadEdit
    else FinishGamepadEdit;
  StopGamepadInput;
  CanClose := True;
end;

procedure TMmdAiPoseEditorForm.ApplyGamepadStep(X, Y, Z,
  Twist, Bend, TipPitch: Single);
var
  NewPoses: TPmxBonePoses;
  WorldMove, WorldTurn: TPmxVector3;
begin
  if not FGamepadPending or not FSimpleEditing then Exit;
  if (Abs(X) + Abs(Y) + Abs(Z) + Abs(Twist) +
    Abs(Bend) + Abs(TipPitch)) < 0.000001 then Exit;
  WorldMove := Default(TPmxVector3);
  WorldTurn := Default(TPmxVector3);
  AccumulateSimpleControllerViewInput(FGamepadController, X, Y, Z,
    FViewport.Camera.Yaw, FViewport.Camera.Pitch, WorldMove, WorldTurn);
  // 現在の姿勢を次の一歩の基準にし、可動限界で入力が溜まらないようにする。
  if not ApplySimpleControllerWorldWithExtras(FModel, FPoses,
    FGamepadController, WorldMove, WorldTurn, Twist, Bend,
    TipPitch, FViewport.Camera.Yaw, FViewport.Camera.Pitch,
    NewPoses) then Exit;
  FPoses := NewPoses;
  FViewport.SetScene(FModel, FPoses, SelectedViewportBone);
  FSimpleChanged := True;
end;

procedure TMmdAiPoseEditorForm.SimpleInitialStateCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  if FWindowCloseRequested or (ModalResult = mrNone) then
    ModalResult := mrOk;
  FWindowCloseRequested := False;
  if FGamepadPending then
    if ModalResult = mrCancel then CancelGamepadEdit
    else FinishGamepadEdit;
  StopGamepadInput;
  CanClose := True;
end;

procedure TMmdAiPoseEditorForm.ResetSelectedController;
var
  BeforePoses, NewPoses: TPmxBonePoses;
begin
  BeforePoses := Copy(FPoses);
  if not ResetSimpleController(FModel, BeforePoses,
    FSimplePanel.SelectedController, NewPoses) then Exit;
  FPoses := NewPoses;
  FHistory.RecordBeforeEdit(BeforePoses);
  FUndoButton.Enabled := FHistory.CanUndo;
  FRedoButton.Enabled := FHistory.CanRedo;
  FViewport.SetScene(FModel, FPoses, SelectedViewportBone);
  PoseStateChanged;
end;

procedure TMmdAiPoseEditorForm.GamepadTick(Sender: TObject);
var
  State: TMmdProPadState;
  Rate, FrameFactor, ZoomStep: Single;
  DeltaX, DeltaY, DeltaZ, DeltaTwist, DeltaBend,
    DeltaTipPitch: Single;
  NowTick: UInt64;
  ZoomDirection: Integer;

  function Pressed(ButtonNumber: Integer): Boolean;
  begin
    Result := State.Down(ButtonNumber) and
      ((FGamepadPreviousButtons and
        (Cardinal(1) shl (ButtonNumber - 1))) = 0);
  end;

begin
  if not FSimpleVisible or (CurrentSettingPage <> mspPose) then Exit;
  if not FGamepadInput.Poll(State) then
  begin
    if not FGamepadInput.Connected then
    begin
      FGamepadStatusLabel.Caption := 'Pro: 未接続';
      SetSimpleVisible(False);
    end;
    FGamepadPreviousButtons := 0;
    FGamepadPreviousPOV := $FFFF;
    FGamepadLastTick := 0;
    FGamepadZoomDirection := 0;
    Exit;
  end;
  NowTick := GetTickCount64;
  if FGamepadLastTick = 0 then
    FrameFactor := 1.0
  else
    FrameFactor := EnsureRange((NowTick - FGamepadLastTick) / 33.0,
      0.5, 3.0);
  FGamepadLastTick := NowTick;
  if FGamepadPending then
  begin
    if FGamepadController = scEyes then
    begin
      if FGamepadStatusLabel.Caption <> '視線: A確定' then
        FGamepadStatusLabel.Caption := '視線: A確定';
    end
    else if ((State.POV = 9000) or (State.POV = 27000)) and
      (FGamepadController in [scLeftHand, scRightHand,
        scLeftFoot, scRightFoot]) then
    begin
      if FGamepadStatusLabel.Caption <> '←→: 肘・膝 / A確定' then
        FGamepadStatusLabel.Caption := '←→: 肘・膝 / A確定';
    end
    else if State.Down(ProButtonX) then
    begin
      if FGamepadController in [scLeftHand, scRightHand,
        scLeftFoot, scRightFoot] then
      begin
        if FGamepadStatusLabel.Caption <> 'X: 左右軸・上下手足' then
          FGamepadStatusLabel.Caption := 'X: 左右軸・上下手足';
      end
      else if FGamepadStatusLabel.Caption <> 'Pro: 軸回転 / A確定' then
        FGamepadStatusLabel.Caption := 'Pro: 軸回転 / A確定';
    end
    else if FGamepadStatusLabel.Caption <> 'Pro: A確定 / B取消' then
      FGamepadStatusLabel.Caption := 'Pro: A確定 / B取消';
  end
  else if FGamepadStatusLabel.Caption <> 'Pro: 接続中' then
    FGamepadStatusLabel.Caption := 'Pro: 接続中';
  if Pressed(ProButtonRightStick) then FViewport.ResetPreviewCamera;
  if Pressed(ProButtonMinus) then
  begin
    FGamepadOverlayVisible := not FGamepadOverlayVisible;
    ApplyDisplayMode;
  end;
  // ZL/ZRは単押しで一段、押し続けると緩やかに連続拡縮する。
  ZoomDirection := Ord(State.Down(ProButtonZR)) -
    Ord(State.Down(ProButtonZL));
  ZoomStep := 0;
  if ZoomDirection <> FGamepadZoomDirection then
  begin
    FGamepadZoomDirection := ZoomDirection;
    FGamepadZoomStartTick := NowTick;
    if ZoomDirection <> 0 then ZoomStep := 0.7;
  end
  else if (ZoomDirection <> 0) and
    (NowTick - FGamepadZoomStartTick >= 250) then
    ZoomStep := 0.22 * FrameFactor;
  if ZoomStep <> 0 then
    FViewport.AdjustCameraByGamepad(0, ZoomDirection * ZoomStep,
      False, True);
  if (Abs(State.RightX) > 0.005) or (Abs(State.RightY) > 0.005) then
    FViewport.AdjustCameraByGamepad(State.RightX * FrameFactor,
      State.RightY * FrameFactor, State.Down(ProButtonR), False);
  if (State.POV <> FGamepadPreviousPOV) and
    (State.POV <> $FFFF) then SelectByDirection(State.POV);
  if ((State.POV = 9000) or (State.POV = 27000)) and
    (State.POV <> FGamepadPreviousPOV) and
    (FSimplePanel.SelectedController in [scLeftHand, scRightHand,
      scLeftFoot, scRightFoot]) and
    not FGamepadPending and not FSimpleEditing then
  begin
    FGamepadController := FSimplePanel.SelectedController;
    FGamepadPending := True;
    ApplySimpleEditStage(FGamepadController, sesBegin);
    if not FSimpleEditing then FGamepadPending := False;
  end;
  if FGamepadPending then
  begin
    if Pressed(ProButtonB) then
      CancelGamepadEdit
    else if Pressed(ProButtonA) then
      FinishGamepadEdit
    else
    begin
      Rate := 0.10 * FrameFactor;
      if State.Down(ProButtonL) then Rate := Rate * 0.2;
      DeltaX := 0;
      DeltaY := 0;
      DeltaZ := 0;
      DeltaTwist := 0;
      DeltaBend := 0;
      DeltaTipPitch := 0;
      if State.Down(ProButtonX) and (FGamepadController <> scEyes) then
      begin
        DeltaTwist := State.LeftX * Rate;
        if FGamepadController in [scLeftHand, scRightHand,
          scLeftFoot, scRightFoot] then
          DeltaTipPitch := State.LeftY * Rate;
      end
      else
      begin
        DeltaX := State.LeftX * Rate;
        if State.Down(ProButtonR) and (FGamepadController <> scEyes) then
          DeltaZ := State.LeftY * Rate
        else
          DeltaY := State.LeftY * Rate;
      end;
      if (State.POV = 9000) or (State.POV = 27000) then
        if FGamepadController in [scLeftHand, scRightHand,
          scLeftFoot, scRightFoot] then
        begin
          if State.POV = 9000 then DeltaBend := Rate
          else DeltaBend := -Rate;
          DeltaBend := DeltaBend *
            SimpleControllerBendViewSign(FModel, FPoses,
              FGamepadController, FViewport.Camera.Yaw,
              FViewport.Camera.Pitch);
        end;
      ApplyGamepadStep(DeltaX, DeltaY, DeltaZ, DeltaTwist,
        DeltaBend, DeltaTipPitch);
    end;
  end
  else if not FSimpleEditing then
  begin
    if (Abs(State.LeftX) <= 0.005) and
      (Abs(State.LeftY) <= 0.005) then FGamepadAwaitNeutral := False;
    if Pressed(ProButtonB) then
    begin
      ModalResult := mrCancel;
      Exit;
    end;
    if Pressed(ProButtonY) then ResetSelectedController;
    if not FGamepadAwaitNeutral and
      ((Abs(State.LeftX) > 0.005) or (Abs(State.LeftY) > 0.005)) then
    begin
      FGamepadController := FSimplePanel.SelectedController;
      FGamepadPending := True;
      ApplySimpleEditStage(FGamepadController, sesBegin);
      if not FSimpleEditing then FGamepadPending := False;
    end;
  end;
  FGamepadPreviousButtons := State.Buttons;
  FGamepadPreviousPOV := State.POV;
end;

procedure TMmdAiPoseEditorForm.WmAiPose(var Message: TMessage);
var
  CandidateId, ErrorText, PoseData, PoseName, SessionId, Text: string;
  Root: TJSONObject;
  Value: TJSONValue;
begin
  ErrorText := '';
  try
    if not TakePendingMmdAiSessionPose(Text) then
      ErrorText := 'AI候補データがありません。'
    else
    begin
      Value := TJSONObject.ParseJSONValue(Text);
      try
        if not (Value is TJSONObject) then
          raise EArgumentException.Create('AI候補がJSON objectではありません。');
        Root := TJSONObject(Value);
        SessionId := ReadString(Root, 'session_id', '');
        if not SameText(SessionId, FSessionId) then
          raise EInvalidOperation.Create('ポーズ編集セッションが変更されました。');
        PoseData := ReadString(Root, 'pose_data', '');
        if not ApplyExternalPose(PoseData) then
          raise EArgumentException.Create('AI候補のポーズデータが不正です。');
        PoseName := ReadString(Root, 'pose_name', FPoseName);
        CandidateId := ReadString(Root, 'candidate_id', '');
        FCandidateLabel.Caption := 'AI候補: ' + PoseName;
        if CandidateId <> '' then
          FStatusLabel.Caption := '反映済み: ' + CandidateId
        else
          FStatusLabel.Caption := 'AI候補を反映しました。';
        FStatusLabel.TextColor := MmdEditorText;
        ApplyDisplayMode;
      finally
        Value.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      ErrorText := E.Message;
      FStatusLabel.Caption := 'AI候補の反映エラー: ' + ErrorText;
      FStatusLabel.TextColor := clRed;
    end;
  end;
  CompleteMmdAiSessionPose(ErrorText);
  Message.Result := Ord(ErrorText = '');
end;

function EditMmdAiInitialStateSettings(const ModelFileName, CurrentPoseData,
  CurrentExpressionData, CurrentEyeBlinkData, CurrentLipSyncData,
  EditorCaption, PoseName: string; out NewPoseData, NewExpressionData,
  NewEyeBlinkData, NewLipSyncData: string): Boolean;
var
  Form: TMmdAiPoseEditorForm;
  PoseData: string;
begin
  Result := False;
  NewPoseData := CurrentPoseData;
  NewExpressionData := CurrentExpressionData;
  NewEyeBlinkData := CurrentEyeBlinkData;
  NewLipSyncData := CurrentLipSyncData;
  PoseData := CurrentPoseData;
  if PoseData = '' then
    PoseData := '{"version":1,"bones":[]}';
  Form := TMmdAiPoseEditorForm.CreateAiEditor(ModelFileName, PoseData,
    EditorCaption, PoseName);
  try
    Form.ConfigureSettingControls(True);
    Form.EnableSimpleControls;
    Form.OnCloseQuery := Form.SimpleInitialStateCloseQuery;
    Form.InitializeExpression(CurrentExpressionData);
    Form.InitializeEyeBlink(CurrentEyeBlinkData);
    Form.InitializeLipSync(CurrentLipSyncData);
    if Form.ShowModal <> mrOk then
      Exit;
    NewPoseData := Form.EncodeCurrentPose;
    NewExpressionData := Form.EncodeExpression;
    NewEyeBlinkData := Form.EncodeEyeBlink;
    NewLipSyncData := Form.EncodeLipSync;
    Result := True;
  finally
    Form.Free;
  end;
end;

function EditMmdAiPoseOnlySettings(const ModelFileName, CurrentPoseData,
  EditorCaption, PoseName: string; out NewPoseData: string): Boolean;
var
  Form: TMmdAiPoseEditorForm;
  PoseData: string;
begin
  Result := False;
  NewPoseData := CurrentPoseData;
  PoseData := CurrentPoseData;
  if PoseData = '' then
    PoseData := '{"version":1,"bones":[]}';
  Form := TMmdAiPoseEditorForm.CreateAiEditor(ModelFileName, PoseData,
    EditorCaption, PoseName);
  try
    Form.ConfigureSettingControls(False, True);
    Form.EnableSimpleControls;
    Form.OnCloseQuery := Form.SimpleCloseQuery;
    if Form.ShowModal <> mrOk then
      Exit;
    NewPoseData := Form.EncodeCurrentPose;
    Result := True;
  finally
    Form.Free;
  end;
end;

end.
