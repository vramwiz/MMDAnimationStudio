unit MMD_Model_PoseInput;

// 現在フレームのポーズレイヤーを評価し、共有メモリから姿勢JSONを取得する。

interface

uses
  AviUtl2FilterTypes;

// 1始まりの参照レイヤーを現在位置で評価し、同一PMXの姿勢JSONと配置範囲を返す。
function TryGetReferencedPoseData(Video: PFILTER_PROC_VIDEO; PoseLayer: Integer;
  const ModelFileName: string; out PoseData: string;
  out PoseStartFrame, PoseEndFrame: Integer): Boolean;

implementation

uses
  System.SysUtils,
  MMD_Model_ReferenceGuard,
  MmdPoseSharedMemory,
  MmdPoseSharedTrace;

function TryGetReferencedPoseData(Video: PFILTER_PROC_VIDEO; PoseLayer: Integer;
  const ModelFileName: string; out PoseData: string;
  out PoseStartFrame, PoseEndFrame: Integer): Boolean;
var
  DataLength: Integer;
  ModelHash: UInt64;
  PoseObject: OBJECT_HANDLE;
  PosePosition: TOBJECT_LAYER_FRAME;
  Snapshot: TMmdPoseSharedSnapshot;
  TimelineFrame: Integer;
begin
  Result := False;
  PoseData := '';
  PoseStartFrame := -1;
  PoseEndFrame := -1;
  if (Video = nil) or not Assigned(Video^.GetImageObject) or
    not CanEvaluateMmdModelReference(Video, PoseLayer) then
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
      // GetImageObjectが返すのは不透明な編集オブジェクトハンドル。
      // POBJECT_INFOへキャストせず、編集セクション経由で配置位置を取得する。
      if (Video^.Edit <> nil) and
        Assigned(Video^.Edit^.GetObjectLayerFrame) then
      begin
        PosePosition := Video^.Edit^.GetObjectLayerFrame(PoseObject);
        if PosePosition.StartFrame >= 0 then
        begin
          PoseStartFrame := PosePosition.StartFrame;
          PoseEndFrame := PosePosition.EndFrame;
        end;
      end;
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
      PoseStartFrame := -1;
      PoseEndFrame := -1;
    end;
  end;
end;

end.
