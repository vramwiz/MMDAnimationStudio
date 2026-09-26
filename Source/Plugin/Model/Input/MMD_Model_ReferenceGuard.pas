unit MMD_Model_ReferenceGuard;

// モデル表示からGetImageObjectする前に自己参照とモデル間循環を除外する。

interface

uses
  AviUtl2FilterTypes;

// DisplayLayerは画面上の1始まり。対象がモデル表示なら評価を許可しない。
function CanEvaluateMmdModelReference(Video: PFILTER_PROC_VIDEO;
  DisplayLayer: Integer): Boolean;

implementation

const
  ModelEffectName = #$30E2#$30C7#$30EB#$8868#$793A;

function CanEvaluateMmdModelReference(Video: PFILTER_PROC_VIDEO;
  DisplayLayer: Integer): Boolean;
var
  Candidate: OBJECT_HANDLE;
  Layer, TimelineFrame: Integer;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or
    (DisplayLayer <= 0) then Exit;
  Layer := DisplayLayer - 1;
  if Layer = Video^.Object_^.Layer then Exit;
  Result := True;
  if (Video^.Edit = nil) or not Assigned(Video^.Edit^.FindObject) or
    not Assigned(Video^.Edit^.CountObjectEffect) then Exit;
  try
    TimelineFrame := Video^.Object_^.FrameS + Video^.Object_^.Frame;
    Candidate := Video^.Edit^.FindObject(Layer, TimelineFrame);
    Result := (Candidate <> nil) and
      (Video^.Edit^.CountObjectEffect(Candidate, ModelEffectName) <= 0);
  except
    Result := False;
  end;
end;

end.
