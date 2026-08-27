unit MmdAiFingerIdValidation;

// finger_id BMPを画素分類し、五指の色と左右の明度差を検査する。

interface

uses
  System.JSON;

// validate_finger_id要求を処理し、画素統計と合否をJSONで返す。
function ValidateFingerIdImages(const Request: TJSONObject): string;

implementation

uses
  System.IOUtils,
  System.Math,
  System.SysUtils,
  Vcl.Graphics;

const
  FINGER_COUNT = 5;
  MIN_COLOR_PIXELS = 16;
  MIN_BRIGHTNESS_RATIO = 0.50;
  MAX_BRIGHTNESS_RATIO = 0.82;

type
  TFingerKind = (fkThumb, fkIndex, fkMiddle, fkRing, fkLittle, fkNone);
  TFingerStats = record
    Counts: array[0..FINGER_COUNT - 1] of Int64;
    Peaks: array[0..FINGER_COUNT - 1] of Integer;
  end;
  TRgbPixel = packed record
    Blue: Byte;
    Green: Byte;
    Red: Byte;
  end;
  PRgbPixelRow = ^TRgbPixelRow;
  TRgbPixelRow = array[0..(MaxInt div SizeOf(TRgbPixel)) - 1] of TRgbPixel;

function ErrorJson(const Code, MessageText: string): string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'error');
    Root.AddPair('code', Code);
    Root.AddPair('message', MessageText);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function ReadString(const Object_: TJSONObject; const Name: string): string;
var
  Value: TJSONValue;
begin
  Result := '';
  Value := Object_.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function FingerName(Index: Integer): string;
begin
  case Index of
    0: Result := 'thumb';
    1: Result := 'index';
    2: Result := 'middle';
    3: Result := 'ring';
    4: Result := 'little';
  else
    Result := 'unknown';
  end;
end;

function ClassifyPixel(Red, Green, Blue: Byte): TFingerKind;
var
  Maximum, Minimum: Integer;
  R, G, B: Double;
begin
  Result := fkNone;
  Maximum := Max(Red, Max(Green, Blue));
  Minimum := Min(Red, Min(Green, Blue));
  if (Maximum < 32) or (Maximum - Minimum < 20) then
    Exit;
  R := Red / Maximum;
  G := Green / Maximum;
  B := Blue / Maximum;
  if (R >= 0.70) and (G <= 0.35) and (B <= 0.35) and
     (Abs(G - B) <= 0.16) then
    Result := fkThumb
  else if (R >= 0.70) and (G >= 0.60) and (B <= 0.25) then
    Result := fkIndex
  else if (G >= 0.70) and (R <= 0.35) and (B <= 0.45) then
    Result := fkMiddle
  else if (B >= 0.70) and (G >= 0.20) and (G <= 0.65) and
          (R <= 0.35) then
    Result := fkRing
  else if (B >= 0.70) and (R >= 0.50) and (G <= 0.35) then
    Result := fkLittle;
end;

procedure InspectBitmap(const FilePath: string; out Stats: TFingerStats;
  out Width, Height: Integer);
var
  Bitmap: TBitmap;
  Brightness, Index, X, Y: Integer;
  Finger: TFingerKind;
  Pixel: TRgbPixel;
  Row: PRgbPixelRow;
begin
  Stats := Default(TFingerStats);
  Bitmap := TBitmap.Create;
  try
    Bitmap.LoadFromFile(FilePath);
    Bitmap.PixelFormat := pf24bit;
    Width := Bitmap.Width;
    Height := Bitmap.Height;
    for Y := 0 to Height - 1 do
    begin
      Row := Bitmap.ScanLine[Y];
      for X := 0 to Width - 1 do
      begin
        Pixel := Row[X];
        Finger := ClassifyPixel(Pixel.Red, Pixel.Green, Pixel.Blue);
        if Finger = fkNone then
          Continue;
        Index := Ord(Finger);
        Inc(Stats.Counts[Index]);
        Brightness := Max(Pixel.Red, Max(Pixel.Green, Pixel.Blue));
        if Brightness > Stats.Peaks[Index] then
          Stats.Peaks[Index] := Brightness;
      end;
    end;
  finally
    Bitmap.Free;
  end;
end;

function HasAllFingerColors(const Stats: TFingerStats): Boolean;
var
  Index: Integer;
begin
  for Index := 0 to FINGER_COUNT - 1 do
    if Stats.Counts[Index] < MIN_COLOR_PIXELS then
      Exit(False);
  Result := True;
end;

function StatsJson(const FilePath: string; const Stats: TFingerStats;
  Width, Height: Integer): TJSONObject;
var
  Counts, Peaks: TJSONObject;
  Index: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('file_path', FilePath);
  Result.AddPair('width', TJSONNumber.Create(Width));
  Result.AddPair('height', TJSONNumber.Create(Height));
  Counts := TJSONObject.Create;
  Peaks := TJSONObject.Create;
  for Index := 0 to FINGER_COUNT - 1 do
  begin
    Counts.AddPair(FingerName(Index), TJSONNumber.Create(Stats.Counts[Index]));
    Peaks.AddPair(FingerName(Index), TJSONNumber.Create(Stats.Peaks[Index]));
  end;
  Result.AddPair('pixel_counts', Counts);
  Result.AddPair('peak_brightness', Peaks);
  Result.AddPair('all_five_colors', TJSONBool.Create(HasAllFingerColors(Stats)));
end;

function ValidateFingerIdImages(const Request: TJSONObject): string;
var
  AverageRatio, Ratio: Double;
  BrightnessOk, DimensionsMatch, Passed: Boolean;
  Index, LeftHeight, LeftWidth, RightHeight, RightWidth: Integer;
  LeftFile, RightFile: string;
  LeftStats, RightStats: TFingerStats;
  Ratios, Root: TJSONObject;
begin
  try
    LeftFile := ReadString(Request, 'left_file');
    RightFile := ReadString(Request, 'right_file');
    if (LeftFile = '') or not TPath.IsPathRooted(LeftFile) or
       not TFile.Exists(LeftFile) then
      Exit(ErrorJson('invalid_left_file',
        'left_file must be an existing absolute BMP path.'));
    if (RightFile = '') or not TPath.IsPathRooted(RightFile) or
       not TFile.Exists(RightFile) then
      Exit(ErrorJson('invalid_right_file',
        'right_file must be an existing absolute BMP path.'));
    InspectBitmap(LeftFile, LeftStats, LeftWidth, LeftHeight);
    InspectBitmap(RightFile, RightStats, RightWidth, RightHeight);
    DimensionsMatch := (LeftWidth = RightWidth) and
      (LeftHeight = RightHeight);
    BrightnessOk := True;
    AverageRatio := 0.0;
    Ratios := TJSONObject.Create;
    Root := TJSONObject.Create;
    try
      for Index := 0 to FINGER_COUNT - 1 do
      begin
        if LeftStats.Peaks[Index] = 0 then
          Ratio := 0.0
        else
          Ratio := RightStats.Peaks[Index] / LeftStats.Peaks[Index];
        AverageRatio := AverageRatio + Ratio;
        Ratios.AddPair(FingerName(Index), TJSONNumber.Create(Ratio));
        if (Ratio < MIN_BRIGHTNESS_RATIO) or
           (Ratio > MAX_BRIGHTNESS_RATIO) then
          BrightnessOk := False;
      end;
      AverageRatio := AverageRatio / FINGER_COUNT;
      Passed := DimensionsMatch and HasAllFingerColors(LeftStats) and
        HasAllFingerColors(RightStats) and BrightnessOk;
      Root.AddPair('status', 'ok');
      Root.AddPair('extension', 'mmd.preview');
      Root.AddPair('operation', 'validate_finger_id');
      Root.AddPair('passed', TJSONBool.Create(Passed));
      Root.AddPair('left', StatsJson(LeftFile, LeftStats, LeftWidth,
        LeftHeight));
      Root.AddPair('right', StatsJson(RightFile, RightStats, RightWidth,
        RightHeight));
      Root.AddPair('dimensions_match', TJSONBool.Create(DimensionsMatch));
      Root.AddPair('right_to_left_peak_ratios', Ratios);
      Ratios := nil;
      Root.AddPair('average_right_to_left_peak_ratio',
        TJSONNumber.Create(AverageRatio));
      Root.AddPair('expected_ratio_range', Format('%.2f..%.2f',
        [MIN_BRIGHTNESS_RATIO, MAX_BRIGHTNESS_RATIO]));
      Root.AddPair('brightness_difference_valid',
        TJSONBool.Create(BrightnessOk));
      Result := Root.ToJSON;
    finally
      Ratios.Free;
      Root.Free;
    end;
  except
    on E: Exception do
      Result := ErrorJson('finger_id_validation_failed', E.Message);
  end;
end;

end.
