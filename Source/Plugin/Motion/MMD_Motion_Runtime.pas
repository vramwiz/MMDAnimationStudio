unit MMD_Motion_Runtime;

// FilterのEffectIDまたはScriptオブジェクト由来IDごとに解析済みモーションを保持し、
// 同じ設定値を毎フレーム再デシリアライズせず現在状態を評価する。

interface

uses
  MmdMorphSettingCodec,
  MmdMotionDocument,
  PmxPose;

type
  TMmdMotionRuntime = class
  private
    FDocument: TMmdMotionDocument;
    FEffectID: Int64;
    FObjectID: Int64;
    FSourceData: string;
    FValid: Boolean;
    procedure UpdateMotionData(const Value: string);
  public
    constructor Create(AEffectID: Int64);
    destructor Destroy; override;
    // 設定値が変化した場合だけ再解析し、指定モーションフレームを評価する。
    function Evaluate(AObjectID: Int64; const MotionData: string;
      Frame: Single; out Poses: TPmxNamedBonePoses;
      out Morphs: TMmdNamedMorphWeights): Boolean;
    property EffectID: Int64 read FEffectID;
    property ObjectID: Int64 read FObjectID;
  end;

// 指定IDの解析キャッシュを用意する。Filterからは生成通知のEffectIDを渡す。
function CreateMotionRuntime(EffectID: Int64): Pointer; cdecl;
// 指定IDの解析キャッシュを排他的に取得し、未登録なら作成する。
function AcquireMotionRuntime(EffectID: Int64): TMmdMotionRuntime;
// Acquireしたキャッシュの排他所有を解放する。
procedure ReleaseMotionRuntime(Runtime: TMmdMotionRuntime);
// 指定IDの進行中評価を待ってキャッシュを破棄する。Filterからは破棄通知後に呼ぶ。
procedure DestroyMotionRuntime(EffectID: Int64; UserData: Pointer); cdecl;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  MmdMotionDocumentCodec,
  MmdMotionDocumentEvaluator;

var
  RuntimeLock: TObject;
  Runtimes: TObjectDictionary<Int64, TMmdMotionRuntime>;

constructor TMmdMotionRuntime.Create(AEffectID: Int64);
begin
  inherited Create;
  FEffectID := AEffectID;
end;

destructor TMmdMotionRuntime.Destroy;
begin
  FDocument.Free;
  inherited;
end;

procedure TMmdMotionRuntime.UpdateMotionData(const Value: string);
var
  Document: TMmdMotionDocument;
begin
  if FSourceData = Value then Exit;
  FSourceData := Value;
  FreeAndNil(FDocument);
  FValid := False;
  Document := nil;
  if TryDecodeMmdMotionDocument(Value, Document) then
  begin
    FDocument := Document;
    FValid := True;
  end;
end;

function TMmdMotionRuntime.Evaluate(AObjectID: Int64;
  const MotionData: string; Frame: Single; out Poses: TPmxNamedBonePoses;
  out Morphs: TMmdNamedMorphWeights): Boolean;
begin
  FObjectID := AObjectID;
  UpdateMotionData(MotionData);
  Result := FValid and EvaluateMmdMotionDocument(FDocument, Frame,
    Poses, Morphs);
  if not Result then
  begin
    Poses := nil;
    Morphs := nil;
  end;
end;

function CreateMotionRuntime(EffectID: Int64): Pointer; cdecl;
var
  Existing, Runtime: TMmdMotionRuntime;
begin
  Result := nil;
  try
    Runtime := TMmdMotionRuntime.Create(EffectID);
    TMonitor.Enter(RuntimeLock);
    try
      if Runtimes.TryGetValue(EffectID, Existing) then
      begin
        Runtime.Free;
        Runtime := Existing;
      end
      else
        Runtimes.Add(EffectID, Runtime);
    finally
      TMonitor.Exit(RuntimeLock);
    end;
    Result := Runtime;
  except
  end;
end;

function AcquireMotionRuntime(EffectID: Int64): TMmdMotionRuntime;
begin
  Result := nil;
  TMonitor.Enter(RuntimeLock);
  try
    if not Runtimes.TryGetValue(EffectID, Result) then
    begin
      Result := TMmdMotionRuntime.Create(EffectID);
      Runtimes.Add(EffectID, Result);
    end;
    TMonitor.Enter(Result);
  finally
    TMonitor.Exit(RuntimeLock);
  end;
end;

procedure ReleaseMotionRuntime(Runtime: TMmdMotionRuntime);
begin
  if Runtime <> nil then TMonitor.Exit(Runtime);
end;

procedure DestroyMotionRuntime(EffectID: Int64; UserData: Pointer); cdecl;
var
  Runtime: TMmdMotionRuntime;
begin
  try
    Runtime := nil;
    TMonitor.Enter(RuntimeLock);
    try
      if Runtimes.TryGetValue(EffectID, Runtime) then
        Runtimes.ExtractPair(EffectID);
    finally
      TMonitor.Exit(RuntimeLock);
    end;
    if Runtime = nil then Runtime := TMmdMotionRuntime(UserData);
    if Runtime <> nil then
    begin
      TMonitor.Enter(Runtime);
      TMonitor.Exit(Runtime);
      Runtime.Free;
    end;
  except
  end;
end;

initialization
  RuntimeLock := TObject.Create;
  Runtimes := TObjectDictionary<Int64, TMmdMotionRuntime>.Create(
    [doOwnsValues]);

finalization
  Runtimes.Free;
  RuntimeLock.Free;

end.
