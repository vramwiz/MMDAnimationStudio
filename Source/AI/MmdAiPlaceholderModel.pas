unit MmdAiPlaceholderModel;

// PMX未指定時に標準MMDボーン名と概略比率を提示する、描画専用の仮モデル。

interface

uses
  PmxModel;

function CreateMmdPlaceholderModel: TPmxModel;

implementation

function AddBone(Model: TPmxModel; const Name: string; X, Y, Z: Single;
  ParentIndex: Integer): Integer;
begin
  Result := Length(Model.Bones);
  SetLength(Model.Bones, Result + 1);
  Model.Bones[Result] := Default(TPmxBone);
  Model.Bones[Result].Name := Name;
  Model.Bones[Result].Position.X := X;
  Model.Bones[Result].Position.Y := Y;
  Model.Bones[Result].Position.Z := Z;
  Model.Bones[Result].ParentIndex := ParentIndex;
  Model.Bones[Result].InheritParentIndex := -1;
  Model.Bones[Result].IkTargetIndex := -1;
end;

procedure AddFinger(Model: TPmxModel; const SideName, FingerName: string;
  Side: Single; WristIndex: Integer; BaseY, BaseZ: Single;
  FirstNumber, BoneCount: Integer);
var
  I, ParentIndex: Integer;
begin
  ParentIndex := WristIndex;
  for I := 0 to BoneCount - 1 do
    ParentIndex := AddBone(Model, SideName + FingerName +
      WideChar($FF10 + FirstNumber + I),
      Side * (4.35 + I * 0.42), BaseY - I * 0.04,
      BaseZ, ParentIndex);
end;

procedure AddArm(Model: TPmxModel; const SideName: string; Side: Single;
  UpperBodyIndex: Integer);
var
  ArmIndex, ElbowIndex, ShoulderIndex, ShoulderPIndex, WristIndex: Integer;
begin
  ShoulderPIndex := AddBone(Model, SideName + '肩P', Side * 0.20, 14.1,
    0, UpperBodyIndex);
  ShoulderIndex := AddBone(Model, SideName + '肩', Side * 0.55, 14.0,
    0, ShoulderPIndex);
  ArmIndex := AddBone(Model, SideName + '腕', Side * 1.35, 13.75,
    0, ShoulderIndex);
  AddBone(Model, SideName + '腕捩', Side * 2.05, 13.40, 0, ArmIndex);
  ElbowIndex := AddBone(Model, SideName + 'ひじ', Side * 2.85, 12.85,
    0, ArmIndex);
  AddBone(Model, SideName + '手捩', Side * 3.50, 12.55, 0, ElbowIndex);
  WristIndex := AddBone(Model, SideName + '手首', Side * 4.15, 12.30,
    0, ElbowIndex);
  AddFinger(Model, SideName, UnicodeString('親指'), Side, WristIndex, 12.05,
    -0.25 * Side, 0, 3);
  AddFinger(Model, SideName, UnicodeString('人指'), Side, WristIndex, 12.42,
    -0.12 * Side, 1, 3);
  AddFinger(Model, SideName, UnicodeString('中指'), Side, WristIndex, 12.48,
    0, 1, 3);
  AddFinger(Model, SideName, UnicodeString('薬指'), Side, WristIndex, 12.42,
    0.12 * Side, 1, 3);
  AddFinger(Model, SideName, '小指', Side, WristIndex, 12.30,
    0.24 * Side, 1, 3);
end;

procedure AddLeg(Model: TPmxModel; const SideName: string; Side: Single;
  LowerBodyIndex: Integer);
var
  AnkleIndex, KneeIndex, LegIndex: Integer;
begin
  LegIndex := AddBone(Model, SideName + '足', Side * 0.75, 9.4, 0,
    LowerBodyIndex);
  KneeIndex := AddBone(Model, SideName + 'ひざ', Side * 0.78, 5.6, 0,
    LegIndex);
  AnkleIndex := AddBone(Model, SideName + '足首', Side * 0.80, 1.8, 0,
    KneeIndex);
  AddBone(Model, SideName + 'つま先', Side * 0.80, 0.25, -1.15,
    AnkleIndex);
end;

procedure AddBoundsVertices(Model: TPmxModel; RootIndex: Integer);
var
  I: Integer;
begin
  SetLength(Model.Vertices, 2);
  Model.Vertices[0].Position.X := -5.5;
  Model.Vertices[0].Position.Y := 0;
  Model.Vertices[0].Position.Z := -1.2;
  Model.Vertices[1].Position.X := 5.5;
  Model.Vertices[1].Position.Y := 17.5;
  Model.Vertices[1].Position.Z := 1.2;
  for I := 0 to High(Model.Vertices) do
  begin
    Model.Vertices[I].Normal.Z := -1;
    Model.Vertices[I].DeformType := pdtBdef1;
    Model.Vertices[I].BoneIndices[0] := RootIndex;
    Model.Vertices[I].BoneWeights[0] := 1;
  end;
end;

function CreateMmdPlaceholderModel: TPmxModel;
var
  CenterIndex, GrooveIndex, HeadIndex, LowerBodyIndex, NeckIndex,
  RootIndex, UpperBody2Index, UpperBodyIndex: Integer;
begin
  Result := TPmxModel.Create;
  Result.Name := '標準仮骨格';
  RootIndex := AddBone(Result, '全ての親', 0, 0, 0, -1);
  CenterIndex := AddBone(Result, 'センター', 0, 8.0, 0, RootIndex);
  GrooveIndex := AddBone(Result, UnicodeString('グルーブ'), 0, 8.5, 0,
    CenterIndex);
  AddBone(Result, '腰', 0, 9.8, 0, GrooveIndex);
  LowerBodyIndex := AddBone(Result, '下半身', 0, 10.3, 0, CenterIndex);
  UpperBodyIndex := AddBone(Result, '上半身', 0, 10.5, 0, CenterIndex);
  UpperBody2Index := AddBone(Result, '上半身2', 0, 12.3, 0,
    UpperBodyIndex);
  NeckIndex := AddBone(Result, UnicodeString('首'), 0, 14.35, 0,
    UpperBody2Index);
  HeadIndex := AddBone(Result, '頭', 0, 15.35, 0, NeckIndex);
  AddBone(Result, '両目', 0, 15.65, -0.35, HeadIndex);
  AddBone(Result, '左目', 0.18, 15.65, -0.42, HeadIndex);
  AddBone(Result, '右目', -0.18, 15.65, -0.42, HeadIndex);
  AddArm(Result, '左', 1, UpperBody2Index);
  AddArm(Result, '右', -1, UpperBody2Index);
  AddLeg(Result, '左', 1, LowerBodyIndex);
  AddLeg(Result, '右', -1, LowerBodyIndex);
  AddBoundsVertices(Result, RootIndex);
end;

end.
