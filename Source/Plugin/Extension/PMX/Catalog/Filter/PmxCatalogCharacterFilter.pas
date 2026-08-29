unit PmxCatalogCharacterFilter;

// PMXの表示名とファイル名を既知のキャラ名へ分類し、一覧の絞り込みに使う。

interface

uses
  System.Classes,
  Vcl.StdCtrls,
  PmxCatalogStorage;

type
  TPmxCatalogCharacterDef = record
    Name: UnicodeString;
    Word1: UnicodeString;
    Word2: UnicodeString;
    Word3: UnicodeString;
  end;

const
  PmxCatalogAllCharactersCaption = 'すべて';

type
  TPmxCatalogCharacterCombo = class(TComboBox)
  private
    FUpdating: Boolean;
  protected
    procedure Change; override;
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    // 登録モデルに一致するキャラ名だけを候補へ追加し、現在選択を可能なら維持する。
    procedure Rebuild(ACatalog: TPmxCatalogStorage);
  end;

function PmxCatalogCharacterCount: Integer;
function PmxCatalogCharacterDef(Index: Integer): TPmxCatalogCharacterDef;
function PmxCatalogCharacterIndexOfName(const Name: string): Integer;
function PmxCatalogCharacterIsAll(const Caption: string): Boolean;
function PmxCatalogCharacterMatches(const Def: TPmxCatalogCharacterDef;
  const Text: string): Boolean;

implementation

uses
  Winapi.UxTheme,
  System.SysUtils,
  AviUtl2StyleColors;

{$WARN IMPLICIT_STRING_CAST OFF}
const
  CharacterDefs: array[0..32] of TPmxCatalogCharacterDef = (
    (Name: '東北きりたん'; Word1: 'きりたん'; Word2: 'kiritan'; Word3: ''),
    (Name: '東北ずん子'; Word1: 'ずん子'; Word2: 'zunko'; Word3: ''),
    (Name: '東北イタコ'; Word1: 'イタコ'; Word2: 'itako'; Word3: ''),
    (Name: '結月ゆかり'; Word1: 'ゆかり'; Word2: 'yukari'; Word3: ''),
    (Name: '弦巻マキ'; Word1: 'マキ'; Word2: 'maki'; Word3: ''),
    (Name: '紲星あかり'; Word1: 'あかり'; Word2: 'akari'; Word3: ''),
    (Name: '月読アイ'; Word1: 'アイ'; Word2: 'ai'; Word3: ''),
    (Name: '月読ショウタ'; Word1: 'ショウタ'; Word2: 'shouta'; Word3: 'syouta'),
    (Name: '京町セイカ'; Word1: 'セイカ'; Word2: 'seika'; Word3: ''),
    (Name: '音街ウナ'; Word1: 'ウナ'; Word2: 'una'; Word3: ''),
    (Name: 'ずんだもん'; Word1: 'zundamon'; Word2: 'zunda'; Word3: ''),
    (Name: '四国めたん'; Word1: 'めたん'; Word2: 'metan'; Word3: ''),
    (Name: '春日部つむぎ'; Word1: 'つむぎ'; Word2: 'tsumugi'; Word3: ''),
    (Name: '雨晴はう'; Word1: 'はう'; Word2: 'hau'; Word3: ''),
    (Name: '波音リツ'; Word1: 'リツ'; Word2: 'ritsu'; Word3: ''),
    (Name: '玄野武宏'; Word1: '武宏'; Word2: 'takehiro'; Word3: 'kurono'),
    (Name: '白上虎太郎'; Word1: '虎太郎'; Word2: 'kotaro'; Word3: 'shirakami'),
    (Name: '青山龍星'; Word1: '龍星'; Word2: 'ryusei'; Word3: 'aoyama'),
    (Name: '冥鳴ひまり'; Word1: 'ひまり'; Word2: 'himari'; Word3: ''),
    (Name: '九州そら'; Word1: 'そら'; Word2: 'sora'; Word3: ''),
    (Name: 'もち子さん'; Word1: 'もち子'; Word2: 'mochiko'; Word3: ''),
    (Name: 'あんこもん'; Word1: 'ankomon'; Word2: 'anko'; Word3: ''),
    (Name: 'WhiteCUL'; Word1: 'ホワイトカル'; Word2: 'whitecul'; Word3: ''),
    (Name: '小夜/SAYO'; Word1: '小夜'; Word2: 'sayo'; Word3: ''),
    (Name: '中国うさぎ'; Word1: 'うさぎ'; Word2: 'usagi'; Word3: ''),
    (Name: '中部つるぎ'; Word1: 'つるぎ'; Word2: 'tsurugi'; Word3: ''),
    (Name: 'つくよみちゃん'; Word1: 'つくよみ'; Word2: 'tsukuyomi'; Word3: ''),
    (Name: 'さとうささら'; Word1: 'ささら'; Word2: 'sasara'; Word3: ''),
    (Name: 'すずきつづみ'; Word1: 'つづみ'; Word2: 'tsuzumi'; Word3: ''),
    (Name: 'タカハシ'; Word1: 'takahashi'; Word2: ''; Word3: ''),
    (Name: '小春六花'; Word1: '六花'; Word2: 'rikka'; Word3: ''),
    (Name: '琴葉茜'; Word1: '茜'; Word2: 'akane'; Word3: ''),
    (Name: '琴葉葵'; Word1: '葵'; Word2: 'aoi'; Word3: '')
  );
{$WARN IMPLICIT_STRING_CAST ON}

function Normalize(const Value: string): string;
begin
  Result := LowerCase(Value);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
  Result := StringReplace(Result, '　', '', [rfReplaceAll]);
  Result := StringReplace(Result, '_', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
end;

function WordMatches(const Word, Text: string): Boolean;
begin
  Result := (Word <> '') and (Pos(Normalize(Word), Normalize(Text)) > 0);
end;

procedure TPmxCatalogCharacterCombo.Change;
begin
  if not FUpdating then
    inherited;
end;

constructor TPmxCatalogCharacterCombo.Create(AOwner: TComponent);
begin
  inherited;
  Style := csDropDownList;
  Sorted := False;
  Color := A2SCComboBackground;
  Font.Color := A2SCComboText;
  Font.Height := -13;
end;

procedure TPmxCatalogCharacterCombo.CreateWnd;
begin
  inherited;
  SetWindowTheme(Handle, '', '');
end;

procedure TPmxCatalogCharacterCombo.Rebuild(ACatalog: TPmxCatalogStorage);
var
  Character: TPmxCatalogCharacterDef;
  CharacterIndex: Integer;
  ModelIndex: Integer;
  SearchText: string;
  SelectedText: string;
begin
  SelectedText := Text;
  FUpdating := True;
  Items.BeginUpdate;
  try
    Items.Clear;
    Items.Add(PmxCatalogAllCharactersCaption);
    if Assigned(ACatalog) then
      for CharacterIndex := 0 to PmxCatalogCharacterCount - 1 do
      begin
        Character := PmxCatalogCharacterDef(CharacterIndex);
        for ModelIndex := 0 to ACatalog.Count - 1 do
        begin
          SearchText := ACatalog.Items[ModelIndex].DisplayName + ' ' +
            ExtractFileName(ACatalog.Items[ModelIndex].SourcePath);
          if PmxCatalogCharacterMatches(Character, SearchText) then
          begin
            Items.Add(Character.Name);
            Break;
          end;
        end;
      end;
    ItemIndex := Items.IndexOf(SelectedText);
    if ItemIndex < 0 then
      ItemIndex := 0;
  finally
    Items.EndUpdate;
    FUpdating := False;
  end;
end;

function PmxCatalogCharacterCount: Integer;
begin
  Result := Length(CharacterDefs);
end;

function PmxCatalogCharacterDef(Index: Integer): TPmxCatalogCharacterDef;
begin
  if (Index < Low(CharacterDefs)) or (Index > High(CharacterDefs)) then
    raise EArgumentOutOfRangeException.Create('Character definition index is out of range.');
  Result := CharacterDefs[Index];
end;

function PmxCatalogCharacterIndexOfName(const Name: string): Integer;
begin
  for Result := Low(CharacterDefs) to High(CharacterDefs) do
    if SameText(Normalize(CharacterDefs[Result].Name), Normalize(Name)) then
      Exit;
  Result := -1;
end;

function PmxCatalogCharacterIsAll(const Caption: string): Boolean;
begin
  Result := SameText(Normalize(Caption),
    Normalize(PmxCatalogAllCharactersCaption));
end;

function PmxCatalogCharacterMatches(const Def: TPmxCatalogCharacterDef;
  const Text: string): Boolean;
begin
  Result := WordMatches(Def.Name, Text) or WordMatches(Def.Word1, Text) or
    WordMatches(Def.Word2, Text) or WordMatches(Def.Word3, Text);
end;

end.
