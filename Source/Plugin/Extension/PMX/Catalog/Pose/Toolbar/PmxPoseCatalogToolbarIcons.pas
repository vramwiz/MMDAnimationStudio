unit PmxPoseCatalogToolbarIcons;

// 参考UIと同じ追加・複製・削除・上下移動の線画アイコンを生成する。

interface

uses
  Vcl.Graphics,
  Vcl.ImgList;

// 指定サイズと色で追加、複製、削除、上下移動の5アイコンを再構築する。
procedure BuildPmxPoseCatalogToolbarIcons(Images: TCustomImageList;
  Size: Integer; Color: TColor);

implementation

uses
  Winapi.Windows,
  System.Math,
  System.Types;

const
  BaseSize = 24;
  MaskColor = TColor($00FF00FF);

function S(Value, Size: Integer): Integer;
begin
  Result := MulDiv(Value, Size, BaseSize);
end;

procedure DrawAdd(Canvas: TCanvas; Size: Integer);
begin
  Canvas.MoveTo(S(12, Size), S(7, Size));
  Canvas.LineTo(S(12, Size), S(17, Size));
  Canvas.MoveTo(S(7, Size), S(12, Size));
  Canvas.LineTo(S(17, Size), S(12, Size));
end;

procedure DrawCopy(Canvas: TCanvas; Size: Integer);
begin
  Canvas.Rectangle(S(9, Size), S(5, Size), S(19, Size), S(15, Size));
  Canvas.Rectangle(S(5, Size), S(9, Size), S(15, Size), S(19, Size));
end;

procedure DrawDelete(Canvas: TCanvas; Size: Integer);
begin
  Canvas.MoveTo(S(6, Size), S(8, Size));
  Canvas.LineTo(S(18, Size), S(8, Size));
  Canvas.MoveTo(S(9, Size), S(5, Size));
  Canvas.LineTo(S(15, Size), S(5, Size));
  Canvas.Rectangle(S(8, Size), S(9, Size), S(16, Size), S(19, Size));
  Canvas.MoveTo(S(11, Size), S(11, Size));
  Canvas.LineTo(S(11, Size), S(17, Size));
  Canvas.MoveTo(S(14, Size), S(11, Size));
  Canvas.LineTo(S(14, Size), S(17, Size));
end;

procedure DrawArrow(Canvas: TCanvas; Size: Integer; Down: Boolean);
var
  TipY: Integer;
  TailY: Integer;
begin
  if Down then
  begin
    TipY := S(18, Size);
    TailY := S(6, Size);
  end
  else
  begin
    TipY := S(6, Size);
    TailY := S(18, Size);
  end;
  Canvas.MoveTo(S(12, Size), TailY);
  Canvas.LineTo(S(12, Size), TipY);
  Canvas.MoveTo(S(6, Size), S(IfThen(Down, 13, 11), Size));
  Canvas.LineTo(S(12, Size), TipY);
  Canvas.LineTo(S(18, Size), S(IfThen(Down, 13, 11), Size));
end;

procedure BuildPmxPoseCatalogToolbarIcons(Images: TCustomImageList;
  Size: Integer; Color: TColor);
var
  Bitmap: Vcl.Graphics.TBitmap;
  Index: Integer;
begin
  if not Assigned(Images) or (Size <= 0) then Exit;
  Images.Clear;
  Images.Width := Size;
  Images.Height := Size;
  Images.Masked := True;
  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(Size, Size);
    for Index := 0 to 4 do
    begin
      Bitmap.Canvas.Brush.Color := MaskColor;
      Bitmap.Canvas.Brush.Style := bsSolid;
      Bitmap.Canvas.FillRect(Rect(0, 0, Size, Size));
      Bitmap.Canvas.Brush.Style := bsClear;
      Bitmap.Canvas.Pen.Color := Color;
      Bitmap.Canvas.Pen.Width := 1;
      case Index of
        0: DrawAdd(Bitmap.Canvas, Size);
        1: DrawCopy(Bitmap.Canvas, Size);
        2: DrawDelete(Bitmap.Canvas, Size);
        3: DrawArrow(Bitmap.Canvas, Size, False);
        4: DrawArrow(Bitmap.Canvas, Size, True);
      end;
      Images.AddMasked(Bitmap, MaskColor);
    end;
  finally
    Bitmap.Free;
  end;
end;

end.
