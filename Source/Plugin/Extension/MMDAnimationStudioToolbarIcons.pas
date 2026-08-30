unit MMDAnimationStudioToolbarIcons;

// MMDAnimationStudioのページ種別を示すDPI対応ツールバーアイコンを一括生成する。

interface

uses
  Vcl.Graphics,
  Vcl.ImgList;

// Imagesを指定サイズのページアイコンへ置換する。色は通常表示と選択同期表示へ使用する。
procedure BuildMMDAnimationStudioToolbarIcons(Images: TCustomImageList;
  IconSize: Integer; NormalColor, SyncColor: TColor);

implementation

uses
  System.Math,
  System.Types,
  Winapi.Windows,
  SerifToolbarIcons;

const
  BaseSize = 24;
  MaskColor = TColor($00FF00FF);
  ExplorerColor = TColor($0000D7FF);
  MusicColor = TColor($00B469FF);
  LaunchColor = TColor($0078DC64);
  LastImageIndex = 10;

procedure DrawFaceIcon(Canvas: TCanvas; Size: Integer; GlyphColor: TColor);

  function Scale(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Size, BaseSize);
  end;

begin
  Canvas.Pen.Color := GlyphColor;
  Canvas.Pen.Width := Max(1, Scale(2));
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsClear;
  Canvas.Ellipse(Scale(3), Scale(2), Scale(21), Scale(22));

  Canvas.Brush.Color := GlyphColor;
  Canvas.Brush.Style := bsSolid;
  Canvas.Ellipse(Scale(7), Scale(8), Scale(10), Scale(11));
  Canvas.Ellipse(Scale(14), Scale(8), Scale(17), Scale(11));

  Canvas.Brush.Style := bsClear;
  Canvas.Polyline([Point(Scale(7), Scale(14)), Point(Scale(9), Scale(16)),
    Point(Scale(12), Scale(17)), Point(Scale(15), Scale(16)),
    Point(Scale(17), Scale(14))]);
end;

procedure DrawMusicIcon(Canvas: TCanvas; Size: Integer; GlyphColor: TColor);

  function Scale(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Size, BaseSize);
  end;

begin
  Canvas.Pen.Color := GlyphColor;
  Canvas.Pen.Width := Max(1, Scale(2));
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Color := GlyphColor;
  Canvas.Brush.Style := bsSolid;

  Canvas.MoveTo(Scale(9), Scale(5));
  Canvas.LineTo(Scale(20), Scale(2));
  Canvas.LineTo(Scale(20), Scale(15));
  Canvas.MoveTo(Scale(9), Scale(5));
  Canvas.LineTo(Scale(9), Scale(18));
  Canvas.MoveTo(Scale(9), Scale(8));
  Canvas.LineTo(Scale(20), Scale(5));
  Canvas.Ellipse(Scale(3), Scale(16), Scale(10), Scale(22));
  Canvas.Ellipse(Scale(14), Scale(13), Scale(21), Scale(19));
end;

procedure DrawRunningPersonIcon(Canvas: TCanvas; Size: Integer;
  GlyphColor: TColor);

  function Scale(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Size, BaseSize);
  end;

begin
  Canvas.Pen.Color := GlyphColor;
  Canvas.Pen.Width := Max(1, Scale(2));
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Color := GlyphColor;
  Canvas.Brush.Style := bsSolid;

  Canvas.Ellipse(Scale(15), Scale(2), Scale(20), Scale(7));
  Canvas.MoveTo(Scale(15), Scale(8));
  Canvas.LineTo(Scale(11), Scale(13));
  Canvas.LineTo(Scale(14), Scale(16));
  Canvas.MoveTo(Scale(13), Scale(10));
  Canvas.LineTo(Scale(7), Scale(8));
  Canvas.MoveTo(Scale(14), Scale(10));
  Canvas.LineTo(Scale(20), Scale(12));
  Canvas.MoveTo(Scale(11), Scale(13));
  Canvas.LineTo(Scale(6), Scale(20));
  Canvas.MoveTo(Scale(14), Scale(16));
  Canvas.LineTo(Scale(20), Scale(20));
end;

procedure DrawMotionIcon(Canvas: TCanvas; Size: Integer; GlyphColor: TColor);

  function Scale(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Size, BaseSize);
  end;

begin
  Canvas.Pen.Color := GlyphColor;
  Canvas.Pen.Width := Max(1, Scale(2));
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(Scale(3), Scale(5), Scale(21), Scale(19));
  Canvas.MoveTo(Scale(7), Scale(5));
  Canvas.LineTo(Scale(7), Scale(19));
  Canvas.MoveTo(Scale(17), Scale(5));
  Canvas.LineTo(Scale(17), Scale(19));
  Canvas.Brush.Color := GlyphColor;
  Canvas.Brush.Style := bsSolid;
  Canvas.Polygon([Point(Scale(10), Scale(8)), Point(Scale(16), Scale(12)),
    Point(Scale(10), Scale(16))]);
end;

procedure DrawLaunchIcon(Canvas: TCanvas; Size: Integer; GlyphColor: TColor);

  function Scale(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Size, BaseSize);
  end;

begin
  Canvas.Pen.Color := GlyphColor;
  Canvas.Pen.Width := Max(1, Scale(2));
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsClear;
  Canvas.Ellipse(Scale(2), Scale(2), Scale(22), Scale(22));

  Canvas.Brush.Color := GlyphColor;
  Canvas.Brush.Style := bsSolid;
  Canvas.Polygon([Point(Scale(9), Scale(7)), Point(Scale(18), Scale(12)),
    Point(Scale(9), Scale(17))]);
end;

procedure DrawImage(Canvas: TCanvas; ImageIndex, Size: Integer;
  NormalColor, SyncColor: TColor);
begin
  case ImageIndex of
    0: DrawSerifToolbarIcon(Canvas, stiChara, Size, NormalColor);
    1: DrawFaceIcon(Canvas, Size, NormalColor);
    2: DrawRunningPersonIcon(Canvas, Size, NormalColor);
    3: DrawSerifToolbarIcon(Canvas, stiSerif, Size, NormalColor);
    4: DrawSerifToolbarIcon(Canvas, stiProject, Size, ExplorerColor);
    5: DrawMusicIcon(Canvas, Size, MusicColor);
    6: DrawMotionIcon(Canvas, Size, NormalColor);
    7: DrawSerifToolbarIcon(Canvas, stiChara, Size, SyncColor);
    9: DrawSerifToolbarIcon(Canvas, stiSerif, Size, SyncColor);
    10: DrawLaunchIcon(Canvas, Size, LaunchColor);
  end;
end;

procedure BuildMMDAnimationStudioToolbarIcons(Images: TCustomImageList;
  IconSize: Integer; NormalColor, SyncColor: TColor);
var
  Bitmap: Vcl.Graphics.TBitmap;
  ImageIndex: Integer;
begin
  if not Assigned(Images) or (IconSize <= 0) then
    Exit;

  Images.Clear;
  Images.Width := IconSize;
  Images.Height := IconSize;
  Images.Masked := True;
  Images.BkColor := clNone;

  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(IconSize, IconSize);
    for ImageIndex := 0 to LastImageIndex do
    begin
      Bitmap.Canvas.Brush.Style := bsSolid;
      Bitmap.Canvas.Brush.Color := MaskColor;
      Bitmap.Canvas.FillRect(Rect(0, 0, IconSize, IconSize));
      DrawImage(Bitmap.Canvas, ImageIndex, IconSize, NormalColor, SyncColor);
      Images.AddMasked(Bitmap, MaskColor);
    end;
  finally
    Bitmap.Free;
  end;
end;

end.
