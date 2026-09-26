program InspectKiritanMaterial;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  PmxModel,
  PmxReader,
  PmxMorph,
  MMD_Model_MaterialSelection;

var
  Model: TPmxModel;
  Weights: TPmxMorphWeights;
  Materials: TArray<TPmxMaterial>;
  DrawOrder: TArray<Integer>;
  Selected: TArray<Boolean>;
  I, J, MorphIndex, SourceIndex: Integer;
  MinX, MaxX, MinY, MaxY, MinZ, MaxZ: Single;
begin
  SetConsoleOutputCP(CP_UTF8);
  Model := LoadPmxModel(ParamStr(1));
  try
    TFile.WriteAllText('buildcheck\KiritanMorph73.txt', Model.Morphs[73].Name,
      TEncoding.UTF8);
    Writeln('materials=', Length(Model.Materials), ' morphs=', Length(Model.Morphs));
    for I := 0 to High(Model.Materials) do
      if (I = 0) or (I = 10) or (I = 13) or ((I >= 17) and (I <= 24)) then
      begin
        MinX := 1e9; MinY := 1e9; MinZ := 1e9;
        MaxX := -1e9; MaxY := -1e9; MaxZ := -1e9;
        for J := Model.Materials[I].SurfaceStart to
          Model.Materials[I].SurfaceStart + Model.Materials[I].SurfaceCount - 1 do
        begin
          SourceIndex := Model.Indices[J];
          if Model.Vertices[SourceIndex].Position.X < MinX then MinX := Model.Vertices[SourceIndex].Position.X;
          if Model.Vertices[SourceIndex].Position.X > MaxX then MaxX := Model.Vertices[SourceIndex].Position.X;
          if Model.Vertices[SourceIndex].Position.Y < MinY then MinY := Model.Vertices[SourceIndex].Position.Y;
          if Model.Vertices[SourceIndex].Position.Y > MaxY then MaxY := Model.Vertices[SourceIndex].Position.Y;
          if Model.Vertices[SourceIndex].Position.Z < MinZ then MinZ := Model.Vertices[SourceIndex].Position.Z;
          if Model.Vertices[SourceIndex].Position.Z > MaxZ then MaxZ := Model.Vertices[SourceIndex].Position.Z;
        end;
        Writeln('bounds ', I, ' x=', MinX:0:2, '..', MaxX:0:2,
          ' y=', MinY:0:2, '..', MaxY:0:2, ' z=', MinZ:0:2, '..', MaxZ:0:2);
        if (Model.Materials[I].TextureIndex >= 0) and
           (Model.Materials[I].TextureIndex < Length(Model.Textures)) then
          TFile.AppendAllText('buildcheck\KiritanTextures.txt',
            IntToStr(I) + ' ' + Model.Textures[Model.Materials[I].TextureIndex] + sLineBreak,
            TEncoding.UTF8);
      end;
    for I := 0 to High(Model.Morphs) do
      begin
        Writeln('morph ', I, ' ', Model.Morphs[I].Name, ' panel=', Model.Morphs[I].Panel, ' type=', Ord(Model.Morphs[I].MorphType));
        for J := 0 to High(Model.Morphs[I].MaterialOffsets) do
          Writeln(' offset ', Model.Morphs[I].MaterialOffsets[J].MaterialIndex,
            ' operation=', Ord(Model.Morphs[I].MaterialOffsets[J].Operation),
            ' alpha=', Model.Morphs[I].MaterialOffsets[J].Diffuse.W:0:3);
      end;
    for MorphIndex := -2 to High(Model.Morphs) do
    begin
      if MorphIndex >= 0 then
        if Model.Morphs[MorphIndex].MorphType <> pmtMaterial then
          Continue;
      InitializeMorphWeights(Model, Weights);
      if MorphIndex >= 0 then Weights[MorphIndex] := 1;
      if MorphIndex = -2 then Weights[74] := 1;
      if MorphIndex = 73 then Weights[74] := 1;
      ResolveMorphMaterials(Model, Weights, Materials);
      DrawOrder := SelectResolvedPmxMaterialDrawOrder(Model, Materials);
      SetLength(Selected, Length(Model.Materials));
      for I := 0 to High(DrawOrder) do Selected[DrawOrder[I]] := True;
      Writeln('STATE morph=', MorphIndex, ' drawcount=', Length(DrawOrder));
      for I := 0 to High(Model.Materials) do
        Writeln('mat ', I, ' ', Model.Materials[I].Name,
          ' faces=', Model.Materials[I].SurfaceCount,
          ' base=', Model.Materials[I].Diffuse.W:0:3,
          ' resolved=', Materials[I].Diffuse.W:0:3,
          ' selected=', Selected[I]);
    end;
  finally
    Model.Free;
  end;
end.
