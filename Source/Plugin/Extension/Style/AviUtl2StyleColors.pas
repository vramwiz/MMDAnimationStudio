unit AviUtl2StyleColors;

// 共通ItemListViewが必要とするAviUtl2拡張画面の配色を定義する。

interface

uses
  Vcl.Graphics;

const
  A2SCEditBackground = TColor($003A3A3A);
  A2SCEditText = clWhite;
  A2SCListViewBackground = TColor($001E1E1E);
  A2SCListViewAltBackground = TColor($002A2A2A);
  A2SCListViewText = TColor($00DCDCDC);
  A2SCListViewSelection = TColor($00FF6666);
  A2SCListViewSelectionText = clWhite;
  A2SCToolBarBackground = TColor($002B2B2B);
  A2SCToolBarHot = TColor($00B03C3C);

implementation

end.
