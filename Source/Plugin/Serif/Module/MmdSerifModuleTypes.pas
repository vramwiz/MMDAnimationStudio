unit MmdSerifModuleTypes;

// AviUtl2 Script Moduleが公開するC ABIの引数表、関数表、モジュール表を定義する。
// packed recordのフィールド順とcdeclはホストSDKとのバイナリ互換境界なので変更しない。

interface

type
  LPCSTR = PAnsiChar;
  PLPCSTR = ^LPCSTR;
  PDouble = ^Double;
  PInteger = ^Integer;

  PMMD_SCRIPT_MODULE_PARAM = ^TMMD_SCRIPT_MODULE_PARAM;
  TMMD_SCRIPT_MODULE_PARAM = packed record
    GetParamNum: function: Integer; cdecl;
    GetParamInt: function(Index: Integer): Integer; cdecl;
    GetParamDouble: function(Index: Integer): Double; cdecl;
    GetParamString: function(Index: Integer): LPCSTR; cdecl;
    GetParamData: function(Index: Integer): Pointer; cdecl;
    GetParamTableInt: function(Index: Integer; Key: LPCSTR): Integer; cdecl;
    GetParamTableDouble: function(Index: Integer; Key: LPCSTR): Double; cdecl;
    GetParamTableString: function(Index: Integer; Key: LPCSTR): LPCSTR; cdecl;
    GetParamArrayNum: function(Index: Integer): Integer; cdecl;
    GetParamArrayInt: function(Index, Key: Integer): Integer; cdecl;
    GetParamArrayDouble: function(Index, Key: Integer): Double; cdecl;
    GetParamArrayString: function(Index, Key: Integer): LPCSTR; cdecl;
    PushResultInt: procedure(Value: Integer); cdecl;
    PushResultDouble: procedure(Value: Double); cdecl;
    PushResultString: procedure(Value: LPCSTR); cdecl;
    PushResultData: procedure(Value: Pointer); cdecl;
    PushResultTableInt: procedure(Key: PLPCSTR; Value: PInteger;
      Num: Integer); cdecl;
    PushResultTableDouble: procedure(Key: PLPCSTR; Value: PDouble;
      Num: Integer); cdecl;
    PushResultTableString: procedure(Key: PLPCSTR; Value: PLPCSTR;
      Num: Integer); cdecl;
    PushResultArrayInt: procedure(Value: PInteger; Num: Integer); cdecl;
    PushResultArrayDouble: procedure(Value: PDouble; Num: Integer); cdecl;
    PushResultArrayString: procedure(Value: PLPCSTR; Num: Integer); cdecl;
    SetError: procedure(MessageText: LPCSTR); cdecl;
    GetParamBoolean: function(Index: Integer): Boolean; cdecl;
    PushResultBoolean: procedure(Value: Boolean); cdecl;
    SetResultNone: procedure; cdecl;
    SetResultInt: procedure(Value: Integer); cdecl;
    SetResultDouble: procedure(Value: Double); cdecl;
    SetResultString: procedure(Value: LPCSTR); cdecl;
  end;

  TMMD_SCRIPT_MODULE_FUNCTION = packed record
    Name: PWideChar;
    Func: procedure(Param: PMMD_SCRIPT_MODULE_PARAM); cdecl;
  end;
  PMMD_SCRIPT_MODULE_FUNCTION = ^TMMD_SCRIPT_MODULE_FUNCTION;

  TMMD_SCRIPT_MODULE_TABLE = packed record
    Information: PWideChar;
    Functions: PMMD_SCRIPT_MODULE_FUNCTION;
  end;
  PMMD_SCRIPT_MODULE_TABLE = ^TMMD_SCRIPT_MODULE_TABLE;

implementation

end.
