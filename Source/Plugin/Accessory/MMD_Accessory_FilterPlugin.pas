unit MMD_Accessory_FilterPlugin;

// PMX／OBJアクセサリを人物用入力なしで既存モデル描画経路へ渡す。

interface

uses
  AviUtl2FilterTypes;

// 初回呼出時にアクセサリ専用設定を登録し、DLL有効期間中のFilterテーブルを返す。
function GetAccessoryFilterTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  System.IOUtils,
  System.Math,
  System.SysUtils,
  PluginFilterTable,
  MmdAiDiagnosticState,
  ObjReader,
  PmxModel,
  PmxPose,
  PmxReader,
  MMD_Model_Renderer;

var
  AccessoryFileItem: TFILTER_ITEM_FILE;
  AccessoryScaleItem: TFILTER_ITEM_TRACK;
  PluginTableInitialized: Boolean;

function LoadAccessoryModel(const FileName: string): TPmxModel;
begin
  if SameText(TPath.GetExtension(FileName), '.obj') then
    Result := GetCachedObjModel(FileName)
  else if SameText(TPath.GetExtension(FileName), '.pmx') then
    Result := GetCachedPmxModel(FileName)
  else
    raise EConvertError.Create('Unsupported accessory format');
end;

function AccessoryProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  EmptySkinned: TPmxSkinnedVertices;
  EmptyTransforms: TPmxBoneTransforms;
  FileName: string;
  Model: TPmxModel;
begin
  Result := 1;
  try
    if (Video = nil) or not Assigned(Video^.DrawPoly) or
      (AccessoryFileItem.Value = nil) then Exit;
    FileName := string(AccessoryFileItem.Value);
    if (FileName = '') or not TFile.Exists(FileName) then Exit;
    Model := LoadAccessoryModel(FileName);
    SetLength(EmptyTransforms, 0);
    SetLength(EmptySkinned, 0);
    RenderPmxModel(Video, Model, EmptyTransforms, EmptySkinned, False,
      DISPLAY_MODE_MODEL, Default(TMmdAiDiagnosticMode), False,
      EnsureRange(AccessoryScaleItem.Value, 0.1, 100.0), 0.0);
    if Assigned(Video^.SetDefaultAnchor) then Video^.SetDefaultAnchor(640, 640);
    Result := 0;
  except
    // ファイル破損や描画失敗をAviUtl2のコールバック境界より外へ漏らさない。
  end;
end;

function GetAccessoryFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if not PluginTableInitialized then
  begin
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT,
      'アクセサリ', 'MMD', 'PMX／OBJアクセサリを3D空間へ表示するフィルター',
      AccessoryProcVideo, nil);
    AddFile(AccessoryFileItem, 'モデルファイル', '',
      'アクセサリ (*.pmx;*.obj)'#0'*.pmx;*.obj'#0 +
      'PMXモデル (*.pmx)'#0'*.pmx'#0'Wavefront OBJ (*.obj)'#0'*.obj'#0 +
      'すべてのファイル (*.*)'#0'*.*'#0#0);
    AddTrack(AccessoryScaleItem, 'MMD倍率', 15.0, 0.1, 100.0, 0.1);
    PluginTableInitialized := True;
  end;
  Result := GetPluginTable;
end;

end.
