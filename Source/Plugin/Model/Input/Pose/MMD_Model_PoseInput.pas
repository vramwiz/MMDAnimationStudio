unit MMD_Model_PoseInput;

// 現在フレームのポーズレイヤーを評価し、共有メモリから姿勢JSONを取得する。

interface

uses
  AviUtl2FilterTypes;

// 1始まりの参照レイヤーを現在フレームで評価し、PMXが一致する姿勢JSONだけを返す。
function TryGetReferencedPoseData(Video: PFILTER_PROC_VIDEO; PoseLayer: Integer;
  const ModelFileName: string; out PoseData: string): Boolean;

implementation

uses
  MmdPoseSharedMemory;

function TryGetReferencedPoseData(Video: PFILTER_PROC_VIDEO; PoseLayer: Integer;
  const ModelFileName: string; out PoseData: string): Boolean;
var
  PoseObject: OBJECT_HANDLE;
  Snapshot: TMmdPoseSharedSnapshot;
begin
  Result := False;
  PoseData := '';
  if (Video = nil) or not Assigned(Video^.GetImageObject) or
    (PoseLayer <= 0) then
    Exit;
  // AviUtl2の画面表示は1始まりだが、SDKのレイヤー番号は0始まり。
  PoseObject := Video^.GetImageObject(PoseLayer - 1, 0.0);
  if PoseObject = nil then
    Exit;
  Result := TryReadPoseSnapshot(PoseLayer - 1,
    GetTimelineFrame(Video^.Object_), HashModelPath(ModelFileName), Snapshot);
  if Result then
    PoseData := Snapshot.PoseData;
end;

end.
