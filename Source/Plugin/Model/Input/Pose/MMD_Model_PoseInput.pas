unit MMD_Model_PoseInput;

// 現在フレームのポーズレイヤーを評価し、共有メモリから姿勢JSONを取得する。

interface

uses
  AviUtl2FilterTypes;

// 1始まりの参照レイヤーを現在位置で評価し、存在する同一PMXの姿勢JSONだけを返す。
function TryGetReferencedPoseData(Video: PFILTER_PROC_VIDEO; PoseLayer: Integer;
  const ModelFileName: string; out PoseData: string): Boolean;

implementation

uses
  System.SysUtils,
  MmdPoseSharedMemory,
  MmdPoseSharedTrace;

function TryGetReferencedPoseData(Video: PFILTER_PROC_VIDEO; PoseLayer: Integer;
  const ModelFileName: string; out PoseData: string): Boolean;
var
  DataLength: Integer;
  ModelHash: UInt64;
  PoseObject: OBJECT_HANDLE;
  Snapshot: TMmdPoseSharedSnapshot;
  TimelineFrame: Integer;
begin
  Result := False;
  PoseData := '';
  if (Video = nil) or not Assigned(Video^.GetImageObject) or
    (Video^.Object_ = nil) or (PoseLayer <= 0) then
    Exit;
  TimelineFrame := GetTimelineFrame(Video^.Object_);
  ModelHash := HashModelPath(ModelFileName);
  TraceMmdPoseShared('MODEL', 'evaluate_request', PoseLayer - 1,
    TimelineFrame, Video^.Object_^.ID, Video^.Object_^.EffectID,
    ModelHash, 0, 'display_layer=' + IntToStr(PoseLayer));
  try
    // AviUtl2の画面表示は1始まりだが、SDKのレイヤー番号は0始まり。
    PoseObject := Video^.GetImageObject(PoseLayer - 1, 0.0);
    if PoseObject = nil then
    begin
      TraceMmdPoseShared('MODEL', 'layer_empty', PoseLayer - 1,
        TimelineFrame, Video^.Object_^.ID, Video^.Object_^.EffectID,
        ModelHash, 0);
      Exit;
    end;
    Result := TryReadPoseSnapshot(PoseLayer - 1, ModelHash, Snapshot);
    if Result then
    begin
      PoseData := Snapshot.PoseData;
      DataLength := TEncoding.UTF8.GetByteCount(PoseData);
      TraceMmdPoseShared('MODEL', 'receive_ok', PoseLayer - 1,
        TimelineFrame, Snapshot.WriterObjectID, Snapshot.WriterEffectID,
        Snapshot.ModelPathHash, DataLength,
        'published_frame=' + IntToStr(Snapshot.TimelineFrame));
    end
    else
      TraceMmdPoseShared('MODEL', 'receive_miss', PoseLayer - 1,
        TimelineFrame, Video^.Object_^.ID, Video^.Object_^.EffectID,
        ModelHash, 0);
  except
    on E: Exception do
    begin
      TraceMmdPoseShared('MODEL', 'receive_exception', PoseLayer - 1,
        TimelineFrame, Video^.Object_^.ID, Video^.Object_^.EffectID,
        ModelHash, 0, E.ClassName + ': ' + E.Message);
      Result := False;
      PoseData := '';
    end;
  end;
end;

end.
