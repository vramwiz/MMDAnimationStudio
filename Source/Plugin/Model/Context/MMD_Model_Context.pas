unit MMD_Model_Context;

// 表示モデルの可変状態をEffectID単位に分離し、生成・描画・破棄の寿命を管理する。

interface

uses
  PmxPose;

type
  TMmdModelContext = class
  private
    FEffectID: Int64;
    FObjectID: Int64;
    FExternalPoseText: string;
    FExternalPoses: TPmxNamedBonePoses;
    FExternalPoseValid: Boolean;
    FStandardPoseText: string;
    FStandardPoses: TPmxNamedBonePoses;
    FStandardPoseValid: Boolean;
  public
    // AviUtl2が割り当てたEffectIDに対応する空の状態を生成する。
    constructor Create(AEffectID: Int64);
    // 最新の描画通知に含まれるObjectIDを診断・対応確認用に記録する。
    procedure SetObjectID(AObjectID: Int64);
    // 入力文字列が変化した場合だけ外部姿勢JSONを再解析する。
    procedure UpdateExternalPose(const Text: string);
    // 入力文字列が変化した場合だけ標準姿勢JSONを再解析する。
    procedure UpdateStandardPose(const Text: string);
    property EffectID: Int64 read FEffectID;
    property ObjectID: Int64 read FObjectID;
    property ExternalPoses: TPmxNamedBonePoses read FExternalPoses;
    property ExternalPoseValid: Boolean read FExternalPoseValid;
    property StandardPoses: TPmxNamedBonePoses read FStandardPoses;
    property StandardPoseValid: Boolean read FStandardPoseValid;
  end;

// AviUtl2のFunc_Createから呼び、EffectIDに対応するコンテキストを登録して返す。
function CreateModelContext(EffectID: Int64): Pointer; cdecl;
// 描画中にEffectIDのコンテキストを取得する。戻り値はReleaseまで呼出側が排他的に所有する。
function AcquireModelContext(EffectID, ObjectID: Int64): TMmdModelContext;
// AcquireModelContextで得た排他所有を解放する。nilは何もしない。
procedure ReleaseModelContext(Context: TMmdModelContext);
// AviUtl2のFunc_Destroyから呼び、進行中の描画完了を待って対応Contextを破棄する。
procedure DestroyModelContext(EffectID: Int64; UserData: Pointer); cdecl;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  PmxPoseCodec;

var
  Contexts: TObjectDictionary<Int64, TMmdModelContext>;
  ContextsLock: TObject;

constructor TMmdModelContext.Create(AEffectID: Int64);
begin
  inherited Create;
  FEffectID := AEffectID;
end;

procedure TMmdModelContext.SetObjectID(AObjectID: Int64);
begin
  FObjectID := AObjectID;
end;

procedure DecodePoseText(const Text: string; var CachedText: string;
  var CachedPoses: TPmxNamedBonePoses; var CachedValid: Boolean);
begin
  if CachedText = Text then
    Exit;
  CachedText := Text;
  CachedPoses := nil;
  CachedValid := False;
  try
    CachedValid := TryDecodePoseData(Text, CachedPoses);
  except
    CachedPoses := nil;
  end;
end;

procedure TMmdModelContext.UpdateExternalPose(const Text: string);
begin
  DecodePoseText(Text, FExternalPoseText, FExternalPoses, FExternalPoseValid);
end;

procedure TMmdModelContext.UpdateStandardPose(const Text: string);
begin
  DecodePoseText(Text, FStandardPoseText, FStandardPoses, FStandardPoseValid);
end;

function CreateModelContext(EffectID: Int64): Pointer; cdecl;
var
  Context: TMmdModelContext;
  Existing: TMmdModelContext;
begin
  Result := nil;
  try
    Context := TMmdModelContext.Create(EffectID);
    TMonitor.Enter(ContextsLock);
    try
      if Contexts.TryGetValue(EffectID, Existing) then
      begin
        Context.Free;
        Context := Existing;
      end
      else
        Contexts.Add(EffectID, Context);
    finally
      TMonitor.Exit(ContextsLock);
    end;
    Result := Context;
  except
  end;
end;

function AcquireModelContext(EffectID, ObjectID: Int64): TMmdModelContext;
begin
  Result := nil;
  // Registry→Contextの順で固定し、同一Effectの並列描画と破棄の順序を一意にする。
  TMonitor.Enter(ContextsLock);
  try
    if not Contexts.TryGetValue(EffectID, Result) then
    begin
      Result := TMmdModelContext.Create(EffectID);
      Contexts.Add(EffectID, Result);
    end;
    TMonitor.Enter(Result);
  finally
    TMonitor.Exit(ContextsLock);
  end;
  Result.SetObjectID(ObjectID);
end;

procedure ReleaseModelContext(Context: TMmdModelContext);
begin
  if Context <> nil then
    TMonitor.Exit(Context);
end;

procedure DestroyModelContext(EffectID: Int64; UserData: Pointer); cdecl;
var
  Context: TMmdModelContext;
begin
  try
    Context := nil;
    TMonitor.Enter(ContextsLock);
    try
      if Contexts.TryGetValue(EffectID, Context) then
        Contexts.ExtractPair(EffectID);
    finally
      TMonitor.Exit(ContextsLock);
    end;
    if Context = nil then
      Context := TMmdModelContext(UserData);
    if Context <> nil then
    begin
      // 進行中の描画が終わるまで待ってから解放する。
      TMonitor.Enter(Context);
      TMonitor.Exit(Context);
      Context.Free;
    end;
  except
  end;
end;

initialization
  ContextsLock := TObject.Create;
  Contexts := TObjectDictionary<Int64, TMmdModelContext>.Create([doOwnsValues]);

finalization
  Contexts.Free;
  ContextsLock.Free;

end.
