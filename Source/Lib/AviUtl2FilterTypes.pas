unit AviUtl2FilterTypes;

// AviUtl2 Filterプラグイン登録に必要な最小ABI定義を共有する。

{$ALIGN 8}

interface

type
  LPCWSTR = PWideChar;
  OBJECT_HANDLE = Pointer;

  PEDIT_SECTION = ^TEDIT_SECTION;
  TFilterItemButtonCallback = procedure(Edit: PEDIT_SECTION); cdecl;
  TCountObjectEffectFunc = function(Obj: OBJECT_HANDLE; Effect: LPCWSTR): Integer; cdecl;
  TOBJECT_LAYER_FRAME = record
    Layer: Integer;
    StartFrame: Integer;
    EndFrame: Integer;
  end;
  TGetObjectLayerFrameFunc = function(Obj: OBJECT_HANDLE): TOBJECT_LAYER_FRAME; cdecl;
  TSetObjectItemValueFunc = function(Obj: OBJECT_HANDLE; Effect: LPCWSTR;
    Item: LPCWSTR; Value: PAnsiChar): LongBool; cdecl;
  TGetObjectItemValueFunc = function(Obj: OBJECT_HANDLE; Effect: LPCWSTR;
    Item: LPCWSTR): PAnsiChar; cdecl;
  TGetFocusObjectFunc = function: OBJECT_HANDLE; cdecl;
  TSetObjectNameFunc = procedure(Obj: OBJECT_HANDLE; Name: LPCWSTR); cdecl;

  TEDIT_SECTION = record
    Info: Pointer;
    CreateObjectFromAlias: Pointer;
    FindObject: Pointer;
    CountObjectEffect: TCountObjectEffectFunc;
    GetObjectLayerFrame: TGetObjectLayerFrameFunc;
    GetObjectAlias: Pointer;
    GetObjectItemValue: TGetObjectItemValueFunc;
    SetObjectItemValue: TSetObjectItemValueFunc;
    MoveObject: Pointer;
    DeleteObject: Pointer;
    GetFocusObject: TGetFocusObjectFunc;
    SetFocusObject: Pointer;
    GetProjectFile: Pointer;
    GetSelectedObject: Pointer;
    GetSelectedObjectNum: Pointer;
    GetMouseLayerFrame: Pointer;
    PosToLayerFrame: Pointer;
    IsSupportMediaFile: Pointer;
    GetMediaInfo: Pointer;
    CreateObjectFromMediaFile: Pointer;
    CreateObject: Pointer;
    SetCursorLayerFrame: Pointer;
    SetDisplayLayerFrame: Pointer;
    SetSelectRange: Pointer;
    SetGridBpm: Pointer;
    GetObjectName: Pointer;
    SetObjectName: TSetObjectNameFunc;
  end;

  PSCENE_INFO = ^TSCENE_INFO;
  TSCENE_INFO = record
    Width, Height: Integer;
    Rate, Scale: Integer;
    SampleRate: Integer;
  end;

  POBJECT_INFO = ^TOBJECT_INFO;
  TOBJECT_INFO = record
    ID: Int64;
    Frame: Integer;
    FrameTotal: Integer;
    Time: Double;
    TimeTotal: Double;
    Width, Height: Integer;
    SampleIndex: Int64;
    SampleTotal: Int64;
    SampleNum: Integer;
    ChannelNum: Integer;
    EffectID: Int64;
    Flag: Integer;
    Layer: Integer;
    Index: Integer;
    Num: Integer;
    FrameS: Integer;
    FrameE: Integer;
    EffectLayer: Integer;
    OriginFrame: Integer;
  end;

  POBJECT_IMAGE_PARAM = ^TOBJECT_IMAGE_PARAM;
  TOBJECT_IMAGE_PARAM = record
    X, Y, Z: Single;       // 基準座標。
    RX, RY, RZ: Single;    // 回転角度。360.0で1回転。
    SX, SY, SZ: Single;    // 拡大率。1.0で等倍。
    CX, CY, CZ: Single;    // 基準座標からの相対中心座標。
    Alpha: Single;         // 0.0から1.0の不透明度。
  end;

  TPIXEL_RGBA = packed record
    R, G, B, A: Byte;
  end;
  PPIXEL_RGBA = ^TPIXEL_RGBA;

  TVERTEX_COLOR = record
    X, Y, Z: Single;       // オブジェクトのローカル3D座標。
    R, G, B, A: Single;    // 0.0から1.0の乗算済みアルファ色。
  end;

  TVERTEX_TEXTURE = record
    X, Y, Z: Single;       // オブジェクトのローカル3D座標。
    U, V: Single;          // 0.0から1.0の正規化テクスチャ座標。
    A: Single;             // 0.0から1.0の頂点アルファ。
  end;

  TVERTEX_COLOR_NORM = record
    X, Y, Z: Single;       // オブジェクトのローカル3D座標。
    R, G, B, A: Single;    // 0.0から1.0の乗算済みアルファ色。
    VX, VY, VZ: Single;    // 法線ベクトル。
  end;

  TVERTEX_TEXTURE_NORM = record
    X, Y, Z: Single;       // オブジェクトのローカル3D座標。
    U, V: Single;          // 0.0から1.0の正規化テクスチャ座標。
    A: Single;             // 0.0から1.0の頂点アルファ。
    VX, VY, VZ: Single;    // 法線ベクトル。
  end;

  TFILTER_PROC_VIDEO_GET_TEX2D = function: Pointer; cdecl;
  TGetOutputImageParamFunc = function(Obj: OBJECT_HANDLE; Offset: Double;
    Param: POBJECT_IMAGE_PARAM; ParamSize: Integer): Byte; cdecl;
  TGetImageObjectFunc = function(Layer: Integer;
    Offset: Double): OBJECT_HANDLE; cdecl;
  TDrawImageFunc = function(Resource: LPCWSTR; X, Y, Z, RX, RY, RZ,
    SX, SY, SZ, Alpha: Single): Byte; cdecl;
  TDrawPolyFunc = function(VertexType: Integer; VertexList: Pointer;
    VertexNum: Integer; Resource: LPCWSTR): Byte; cdecl;
  TSetDefaultAnchorProc = procedure(Width, Height: Integer); cdecl;
  TSetBlendModeProc = procedure(BlendMode: Integer); cdecl;
  TSetMaterialShineProc = procedure(Shine: Single); cdecl;
  TSetSamplerModeProc = procedure(SamplerMode: Integer); cdecl;
  TSetCullingStateProc = procedure(Culling: Byte); cdecl;
  TSetBillboardModeProc = procedure(BillboardMode: Integer); cdecl;
  TCreateImageResourceProc = procedure(Resource: LPCWSTR;
    Buffer: PPIXEL_RGBA; Width, Height: Integer); cdecl;
  PFILTER_PROC_VIDEO = ^TFILTER_PROC_VIDEO;
  TFILTER_PROC_VIDEO = record
    Scene: PSCENE_INFO;
    Object_: POBJECT_INFO;
    GetImageData: procedure(Buffer: PPIXEL_RGBA); cdecl;
    SetImageData: procedure(Buffer: PPIXEL_RGBA; Width, Height: Integer); cdecl;
    GetImageTexture2D: TFILTER_PROC_VIDEO_GET_TEX2D;
    GetFramebufferTexture2D: TFILTER_PROC_VIDEO_GET_TEX2D;
    Edit: PEDIT_SECTION;
    Param: POBJECT_IMAGE_PARAM;
    GetOutputImageParam: TGetOutputImageParamFunc;
    GetImageObject: TGetImageObjectFunc;
    DrawImage: TDrawImageFunc;
    DrawPoly: TDrawPolyFunc;
    SetDefaultAnchor: TSetDefaultAnchorProc;
    SetBlendMode: TSetBlendModeProc;
    SetMaterialShine: TSetMaterialShineProc;
    SetSamplerMode: TSetSamplerModeProc;
    SetCullingState: TSetCullingStateProc;
    SetBillboardMode: TSetBillboardModeProc;
    CreateImageResource: TCreateImageResourceProc;
  end;

  TFuncProcVideo = function(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
  TFuncProcAudio = function(Audio: Pointer): Byte; cdecl;
  TFuncCreate = function(EffectID: Int64): Pointer; cdecl;
  TFuncDestroy = procedure(EffectID: Int64; UserData: Pointer); cdecl;

  TFILTER_ITEM_STRING = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: LPCWSTR;
  end;
  TFILTER_ITEM_TRACK = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: Double;
    S: Double;
    E: Double;
    Step: Double;
  end;
  TFILTER_ITEM_CHECK = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: Byte;
  end;
  TFILTER_ITEM_GROUP = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    DefaultVisible: Byte;
  end;
  TFILTER_ITEM_SELECT_ITEM = record
    Name: LPCWSTR;
    Value: Integer;
  end;
  TFILTER_ITEM_SELECT = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: Integer;
    List: ^TFILTER_ITEM_SELECT_ITEM;
  end;
  TFILTER_ITEM_BUTTON = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Callback: TFilterItemButtonCallback;
  end;
  TFILTER_ITEM_COLOR = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    B, G, R, X: Byte;
  end;
  TFILTER_ITEM_FILE = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: LPCWSTR;
    FileFilter: LPCWSTR;
  end;

  PFILTER_PLUGIN_TABLE = ^TFILTER_PLUGIN_TABLE;
  TFILTER_PLUGIN_TABLE = record
    Flag: Integer;
    Name: LPCWSTR;
    Label_: LPCWSTR;
    Information: LPCWSTR;
    Items: ^Pointer;
    Func_Proc_Video: TFuncProcVideo;
    Func_Proc_Audio: TFuncProcAudio;
    Func_Create: TFuncCreate;
    Func_Destroy: TFuncDestroy;
  end;

const
  FILTER_FLAG_VIDEO = 1;
  FILTER_FLAG_INPUT = 4;
  FILTER_FLAG_FILTER = 8;
  VERTEX_TYPE_TRIANGLE_COLOR = 1;
  VERTEX_TYPE_TRIANGLE_COLOR_NORM = 2;
  VERTEX_TYPE_TRIANGLE_TEXTURE = 3;
  VERTEX_TYPE_TRIANGLE_TEXTURE_NORM = 4;
  VERTEX_TYPE_QUAD_COLOR = 5;
  SAMPLER_MODE_LOOP = 2;
  SAMPLER_MODE_DOT = 4;

implementation

end.
