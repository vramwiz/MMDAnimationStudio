program MmdSerifAviUtlAdapterTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AppFolderUtils in '..\..\AviUtl2PluginLib\Lib\AppFolderUtils\AppFolderUtils.pas',
  SerifAviUtlProfile in '..\..\AviUtl2PluginLib\Serif\AviUtl\Adapter\Core\SerifAviUtlProfile.pas',
  SerifAviUtlAliasProvider in '..\..\AviUtl2PluginLib\Serif\AviUtl\Adapter\Core\SerifAviUtlAliasProvider.pas',
  SerifAviUtlDrawAliasBuilder in '..\..\AviUtl2PluginLib\Serif\AviUtl\Adapter\Core\SerifAviUtlDrawAliasBuilder.pas',
  MmdSerifAviUtlNames in '..\Source\Plugin\Serif\AviUtl\MmdSerifAviUtlNames.pas',
  MmdSerifAviUtlProfile in '..\Source\Plugin\Serif\AviUtl\MmdSerifAviUtlProfile.pas',
  MmdSerifAviUtlAliasProvider in '..\Source\Plugin\Serif\AviUtl\MmdSerifAviUtlAliasProvider.pas',
  MmdSerifAviUtlAdapter in '..\Source\Plugin\Serif\AviUtl\MmdSerifAviUtlAdapter.pas';

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  AliasText: string;
  Data: TSerifAviUtlInputAliasData;
  FrameEnd: Integer;
  Profile: TSerifAviUtlProfile;
begin
  try
    Profile := CurrentSerifAviUtlProfile;
    Check(Profile.ProductID = MMD_SERIF_PRODUCT_ID,
      'profile product mismatch');
    Check(CurrentSerifAviUtlAliasProviderProductID = MMD_SERIF_PRODUCT_ID,
      'provider product mismatch');

    BeginSerifAviUtlAliasBatch;
    Data := Default(TSerifAviUtlInputAliasData);
    Data.Character := 'キャラA';
    Data.Emotion := '通常';
    Data.Direction := 0;
    Data.Serif := '一行目' + sLineBreak + '二行目';
    Data.Lab := '0 1000000 a';
    Data.UID := '{TEST-UID}';
    Data.Layer := 4;
    Data.FrameStart := 10;
    Data.FrameLength := 30;
    Data.Group := 2;
    AddSerifAviUtlInputAlias(Data, FrameEnd);
    AliasText := BuildSerifAviUtlAliasBatch;

    Check(FrameEnd = 40, 'frame end mismatch');
    Check(Pos('effect.name=' + MMD_SERIF_EFFECT_NAME, AliasText) > 0,
      'MMD serif effect is missing');
    Check(Pos('effect.name=MMD' + #$30BB#$30EA#$30D5 +
      '@MMD_Script', AliasText) > 0,
      'MMD serif effect Unicode mismatch');
    Check(Pos('effect.name=' + #$56F3#$5F62, AliasText) = 0,
      'obsolete shape base leaked into Serif alias');
    Check(Pos('effect.name=' + #$6A19#$6E96#$63CF#$753B, AliasText) > 0,
      'standard drawing effect Unicode mismatch');
    Check(Pos(MMD_SERIF_CHARACTER_ITEM + '=キャラA', AliasText) > 0,
      'character item is missing');
    Check(Pos(MMD_SERIF_TEXT_ITEM + '=一行目\n二行目', AliasText) > 0,
      'line break was not escaped');
    Check(Pos('[0.0]' + sLineBreak + 'effect.name=' +
      MMD_SERIF_EFFECT_NAME, AliasText) > 0,
      'Serif script is not the base effect');
    Check(Pos('[0.1]' + sLineBreak + 'effect.name=' +
      #$6A19#$6E96#$63CF#$753B, AliasText) > 0,
      'standard drawing is not the second effect');
    Check(Pos('frame=10,40', AliasText) > 0,
      'object frame is missing');
    Check(Pos('Syncroh2_', AliasText) = 0,
      'Syncroh2 dependency leaked into MMD alias');
    Check(Pos('effect.name=' + MMD_SERIF_DRAW_EFFECT_NAME,
      BuildSerifAviUtlDrawAlias) > 0,
      'MMD serif display alias is missing');
    Writeln('MmdSerifAviUtlAdapterTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdSerifAviUtlAdapterTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
