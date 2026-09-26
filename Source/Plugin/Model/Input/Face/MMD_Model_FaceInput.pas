unit MMD_Model_FaceInput;

// 現在フレームの表情レイヤーを評価し、共有メモリからモーフJSONを取得する。

interface

uses
  AviUtl2FilterTypes;

function TryGetReferencedFaceData(Video: PFILTER_PROC_VIDEO;
  FaceLayer: Integer; const ModelFileName: string;
  out FaceData: string): Boolean;

implementation

uses
  MMD_Model_ReferenceGuard,
  MmdFaceSharedMemory;

function TryGetReferencedFaceData(Video: PFILTER_PROC_VIDEO;
  FaceLayer: Integer; const ModelFileName: string;
  out FaceData: string): Boolean;
var
  FaceObject: OBJECT_HANDLE;
  Snapshot: TMmdFaceSharedSnapshot;
begin
  Result := False;
  FaceData := '';
  if (Video = nil) or not Assigned(Video^.GetImageObject) or
    not CanEvaluateMmdModelReference(Video, FaceLayer) then Exit;
  try
    FaceObject := Video^.GetImageObject(FaceLayer - 1, 0.0);
    if FaceObject = nil then Exit;
    Result := TryReadFaceSnapshot(FaceLayer - 1,
      HashFaceModelPath(ModelFileName), Snapshot);
    if Result then FaceData := Snapshot.FaceData;
  except
    Result := False;
    FaceData := '';
  end;
end;

end.
