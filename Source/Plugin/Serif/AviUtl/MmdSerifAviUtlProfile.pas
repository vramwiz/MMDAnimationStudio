unit MmdSerifAviUtlProfile;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

// MMDAnimationStudioがAviUtl2上で扱うセリフオブジェクト名を一元管理する。
// Syncroh2のスクリプト名や項目名はここへ持ち込まない。

interface

// 共通Serifが参照するMMDAnimationStudio固有の名称プロファイルを登録する。
procedure RegisterMmdSerifAviUtlProfile;

implementation

uses
  MmdSerifAviUtlNames,
  SerifAviUtlProfile;

procedure RegisterMmdSerifAviUtlProfile;
var
  Profile: TSerifAviUtlProfile;
begin
  Profile := Default(TSerifAviUtlProfile);
  Profile.ProductID := MMD_SERIF_PRODUCT_ID;
  Profile.ProjectFolderKey := MMD_SERIF_PROJECT_FOLDER_KEY;
  Profile.SerifEffectName := MMD_SERIF_EFFECT_NAME;
  Profile.SerifTextItem := MMD_SERIF_TEXT_ITEM;
  Profile.CharacterItem := MMD_SERIF_CHARACTER_ITEM;
  Profile.EmotionItem := MMD_SERIF_EMOTION_ITEM;
  Profile.DirectionItem := MMD_SERIF_DIRECTION_ITEM;
  Profile.AiueoItem := MMD_SERIF_AIUEO_ITEM;
  Profile.LabItem := MMD_SERIF_LAB_ITEM;
  Profile.UIDItem := MMD_SERIF_UID_ITEM;
  Profile.AudioEffectName := '音声ファイル';
  Profile.AudioFileItem := 'ファイル';
  Profile.AudioPlaybackItem := '再生位置';
  Profile.FilterObjectName := 'フィルタオブジェクト';
  Profile.SerifDrawEffectName := MMD_SERIF_DRAW_EFFECT_NAME;
  RegisterSerifAviUtlProfile(Profile);
end;

end.
