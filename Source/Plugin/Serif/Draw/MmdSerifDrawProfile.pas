unit MmdSerifDrawProfile;


{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

// 共通SerifDrawへMMDAnimationStudio固有の公開名と診断先を登録する。

interface

// GetTable／InitializeSerifDrawPluginの前提となる製品設定を登録する。
procedure RegisterMmdSerifDrawProfile;

implementation

uses
  SerifDrawPluginProfile;

procedure RegisterMmdSerifDrawProfile;
var
  Profile: TSerifDrawPluginProfile;
begin
  Profile := Default(TSerifDrawPluginProfile);
  Profile.ProductID := 'MMDAnimationStudio';
  Profile.EffectName := 'MMDセリフ表示';
  Profile.GroupName := 'MMD';
  Profile.Information := 'MMDセリフ表示';
  Profile.SettingsItemName := 'テキストパラメータ1';
  Profile.DebugLogFileName :=
    'C:\ProgramData\aviutl2\Plugin\MMD\MMD_SerifDraw_debug.log';
  RegisterSerifDrawPluginProfile(Profile);
end;

end.
