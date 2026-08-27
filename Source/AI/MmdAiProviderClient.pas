unit MmdAiProviderClient;

// MMD共通AIプロバイダーの必要サイズ取得型C境界を、Delphi文字列呼出しへ変換する。

interface

// UTF-16のJSON要求をUTF-8 C ABIへ渡し、UTF-16のJSON応答として返す。
function InvokeMmdAiProvider(const RequestText: string): string;

implementation

uses
  System.SysUtils,
  MmdAiProvider;

function InvokeMmdAiProvider(const RequestText: string): string;
var
  Buffer: TBytes;
  RequestUtf8, ResponseUtf8: UTF8String;
  Required, Written: Integer;
begin
  RequestUtf8 := UTF8String(RequestText);
  Required := MmdAiProviderInvoke(PAnsiChar(RequestUtf8), nil, 0);
  if Required < 0 then
    raise Exception.Create('MMD AI provider returned an invalid response size.');
  SetLength(Buffer, Required + 1);
  Written := MmdAiProviderInvoke(PAnsiChar(RequestUtf8),
    PAnsiChar(@Buffer[0]), Length(Buffer));
  if Written <> Required then
    raise Exception.CreateFmt(
      'MMD AI provider response size changed from %d to %d.',
      [Required, Written]);
  SetString(ResponseUtf8, PAnsiChar(@Buffer[0]), Written);
  Result := UTF8ToString(ResponseUtf8);
end;

end.
