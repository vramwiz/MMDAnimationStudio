unit MmdSerifAviUtlAdapter;

// MMDAnimationStudio起動時に、共通Serifの製品境界をまとめて登録する。

interface

implementation

uses
  MmdSerifAviUtlAliasProvider,
  MmdSerifAviUtlNames,
  MmdSerifAviUtlProfile;

initialization
  RegisterMmdSerifAviUtlProfile;
  RegisterMmdSerifAviUtlAliasProvider;

end.
