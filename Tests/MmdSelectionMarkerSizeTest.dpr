program MmdSelectionMarkerSizeTest;

{$APPTYPE CONSOLE}

// 実シェーダーで選択球を描き、ズーム・縦横寸法変更後も直径12pxを維持するか確認する。
uses
  Winapi.Windows, Winapi.D3D11, Winapi.D3DCommon, Winapi.DXGI,
  System.SysUtils, System.Math, Vcl.Forms, Vcl.Graphics,
  PmxModel, MmdD3DScene, MmdD3DShapes, MmdD3DShaders, MmdD3DDevice,
  MmdD3DBuffers, MmdD3DTextures, MmdD3DCapture;

procedure CheckSize(Width, Height: Integer; Zoom: Single; Locked: Boolean;
  SimpleMarker: Boolean = False);
var
  Form: TForm;
  Device: ID3D11Device;
  Context: ID3D11DeviceContext;
  SwapChain: IDXGISwapChain;
  Blend: ID3D11BlendState;
  Rasterizer: ID3D11RasterizerState;
  Target: ID3D11RenderTargetView;
  Depth: ID3D11Texture2D;
  DepthView: ID3D11DepthStencilView;
  Buffer: ID3D11Buffer;
  Shaders: TMmdD3DShaders;
  Textures: TMmdD3DTextures;
  Model: TPmxModel;
  Bitmap: TBitmap;
  Projection: TMmdPreviewProjection;
  Camera: TMmdPreviewCamera;
  Selected: TMmdPreviewTarget;
  Joints: TMmdPreviewJoints;
  Vertices: TMmdPreviewVertices;
  Viewport: TD3D11_VIEWPORT;
  Clear: TFourSingleArray;
  Stride, Offset: Cardinal;
  X, Y, MinX, MaxX, MinY, MaxY, ExpectedSize, CyanPixels: Integer;
  Pixel: PByte;
begin
  Form := TForm.Create(nil);
  Model := TPmxModel.Create;
  Bitmap := TBitmap.Create;
  Shaders := nil;
  Textures := nil;
  try
    Form.ClientWidth := Width;
    Form.ClientHeight := Height;
    CreatePreviewDevice(Form.Handle, SwapChain, Device, Context, Blend, Rasterizer);
    CreatePreviewRenderTargets(SwapChain, Device, Target, Depth, DepthView);
    Shaders := TMmdD3DShaders.Create(Device);
    Textures := TMmdD3DTextures.Create(Device, Model);
    Projection := Default(TMmdPreviewProjection);
    Projection.ModelWidth := 10;
    Projection.ModelHeight := 20;
    Projection.Radius := 20;
    Camera := DefaultPreviewCamera;
    Camera.Zoom := Zoom;
    Camera.PanX := 17;
    Camera.PanY := -13;
    SetLength(Joints, 1);
    Joints[0].BoneIndex := 0;
    Selected := EmptyPreviewTarget;
    Selected.JointIndex := 0;
    Selected.Kind := ptJoint;
    Selected.Locked := Locked;
    BuildPreviewBoneShapes(Joints, nil, Selected, EmptyPreviewTarget, 20,
      Vertices, SimpleMarker);
    Buffer := CreatePreviewVertexBuffer(Device, Vertices);
    FillChar(Clear, SizeOf(Clear), 0);
    Context.ClearRenderTargetView(Target, Clear);
    Context.ClearDepthStencilView(DepthView, D3D11_CLEAR_DEPTH, 1, 0);
    Context.OMSetRenderTargets(1, Target, DepthView);
    Viewport := TD3D11_VIEWPORT.Create(Depth, Target);
    Context.RSSetViewports(1, @Viewport);
    Context.RSSetState(Rasterizer);
    Shaders.UpdateCamera(Context, Camera, Projection, Width, Height);
    Shaders.Bind(Context);
    Textures.Bind(Context, -1);
    Stride := SizeOf(TMmdPreviewVertex);
    Offset := 0;
    Context.IASetVertexBuffers(0, 1, Buffer, @Stride, @Offset);
    Context.IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    Context.Draw(Length(Vertices), 0);
    ReadSwapChainToBitmap(SwapChain, Device, Context, Bitmap);
    MinX := Width;
    MinY := Height;
    MaxX := -1;
    MaxY := -1;
    CyanPixels := 0;
    for Y := 0 to Bitmap.Height - 1 do
    begin
      Pixel := Bitmap.ScanLine[Y];
      for X := 0 to Bitmap.Width - 1 do
      begin
        if (Pixel[0] > 30) or (Pixel[1] > 30) or (Pixel[2] > 30) then
        begin
          MinX := Min(MinX, X);
          MaxX := Max(MaxX, X);
          MinY := Min(MinY, Y);
          MaxY := Max(MaxY, Y);
          if Pixel[0] > Pixel[2] + 30 then Inc(CyanPixels);
        end;
        Inc(Pixel, 4);
      end;
    end;
    // ピクセル境界の丸めによる1px差だけを許容する。
    ExpectedSize := 12;
    if SimpleMarker then ExpectedSize := 18;
    if not InRange(MaxX - MinX + 1, ExpectedSize - 1, ExpectedSize) or
      not InRange(MaxY - MinY + 1, ExpectedSize - 1, ExpectedSize) then
      raise Exception.CreateFmt('Unexpected marker size: %dx%d at zoom %.1f',
        [MaxX - MinX + 1, MaxY - MinY + 1, Zoom]);
    if SimpleMarker and (CyanPixels = 0) then
      raise Exception.Create('Simple controller marker is not cyan');
    Writeln(Format('PASS %dx%d zoom %.1f locked=%s: fixed %dpx diameter',
      [Width, Height, Zoom, BoolToStr(Locked, True), ExpectedSize]));
  finally
    if Context <> nil then
      Context.ClearState;
    Textures.Free;
    Shaders.Free;
    Bitmap.Free;
    Model.Free;
    Form.Free;
  end;
end;

begin
  Application.Initialize;
  try
    CheckSize(640, 480, 0.2, False);
    CheckSize(640, 480, 1, False);
    CheckSize(640, 480, 5, False);
    CheckSize(1200, 800, 5, False);
    CheckSize(480, 900, 1, True);
    CheckSize(640, 480, 0.2, False, True);
    CheckSize(1200, 800, 5, False, True);
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
