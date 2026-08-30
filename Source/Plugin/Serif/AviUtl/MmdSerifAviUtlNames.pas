unit MmdSerifAviUtlNames;

// MMDセリフ入力Script、Profile、Alias Providerで共有する公開名。
// 名前の不一致を避けるため、製品側のAviUtl2境界だけが参照する。

interface

const
  MMD_SERIF_PRODUCT_ID = 'MMDAnimationStudio';
  MMD_SERIF_PROJECT_FOLDER_KEY: AnsiString = 'MMDSerifFolder';
  MMD_SERIF_MODULE_NAME = 'MMD_Serif_Module';
  MMD_SERIF_SCRIPT_FILE_NAME = '@MMDAnimationStudio_Script.obj2';
  // BOMの有無やDelphiのソース文字コード判定に影響されないよう、
  // AviUtl2へ公開する日本語名はUnicodeコードポイントで定義する。
  MMD_SERIF_EFFECT_NAME = 'MMD' + #$30BB#$30EA#$30D5 +
    '@MMDAnimationStudio_Script';
  MMD_SERIF_TEXT_ITEM = #$30BB#$30EA#$30D5;
  MMD_SERIF_CHARACTER_ITEM = #$30AD#$30E3#$30E9#$30AF#$30BF#$30FC;
  MMD_SERIF_EMOTION_ITEM = #$611F#$60C5;
  MMD_SERIF_DIRECTION_ITEM = #$6F14#$51FA;
  MMD_SERIF_AIUEO_ITEM = #$6BCD#$97F3;
  MMD_SERIF_LAB_ITEM = 'LAB';
  MMD_SERIF_UID_ITEM = 'UID';

implementation

end.
