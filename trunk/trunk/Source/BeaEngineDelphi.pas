// ====================================================================
//
// Delphi Static lib for BeaEngine 4.x
//
// upDate: 2010-Jan-9
// v0.4 support Delphi7 - Delphi2010
// ====================================================================
// BeaEngine.pas convert by Vince
// updated by kao
// ====================================================================
// [+] BranchTaken,BranchNotTaken added in TPREFIXINFO v3.1.0
unit BeaEngineDelphi;

// ====================================================================
// Default link type is static lib
// comment below line to switch link with DLL
// ====================================================================
// {$DEFINE USEDLL}
// ====================================================================
// Copyright 2006-2009, BeatriX
// File coded by BeatriX
//
// This file is part of BeaEngine.
//
// BeaEngine is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// BeaEngine is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with BeaEngine.  If not, see <http://www.gnu.org/licenses/>.
{
  武稀松2012.2修正.
  把32位64位文件合并.
}

{$Z4}
interface

uses Windows {, SysUtils};

const
  INSTRUCT_LENGTH = 64;

type
  UIntPtr = NativeInt;
  Int8 = ShortInt;
  Int16 = SmallInt;
  Int32 = Integer;
  IntPtr = NativeInt;
  UInt8 = Byte;
  UInt16 = Word;
  UInt32 = Cardinal;

type

  TREX_Struct = packed record
    W_: UInt8;
    R_: UInt8;
    X_: UInt8;
    B_: UInt8;
    state: UInt8;
  end;

  TPREFIXINFO = packed record
    Number: Int32;
    NbUndefined: Int32;
    LockPrefix: UInt8;
    OperandSize: UInt8;
    AddressSize: UInt8;
    RepnePrefix: UInt8;
    RepPrefix: UInt8;
    FSPrefix: UInt8;
    SSPrefix: UInt8;
    GSPrefix: UInt8;
    ESPrefix: UInt8;
    CSPrefix: UInt8;
    DSPrefix: UInt8;
    BranchTaken: UInt8; // v3.1.0 added 2009-11-05
    BranchNotTaken: UInt8; // v3.1.0 added 2009-11-05
    REX: TREX_Struct;
  end;

  TEFLStruct = packed record
    OF_: UInt8;
    SF_: UInt8;
    ZF_: UInt8;
    AF_: UInt8;
    PF_: UInt8;
    CF_: UInt8;
    TF_: UInt8;
    IF_: UInt8;
    DF_: UInt8;
    NT_: UInt8;
    RF_: UInt8;
    alignment: UInt8;
  end;

  TMEMORYTYPE = packed record
    BaseRegister: Int32;
    IndexRegister: Int32;
    Scale: Int32;
    Displacement: Int64;
  end;

  TINSTRTYPE = packed record
    Category: Int32;
    Opcode: Int32;
    Mnemonic: array [0 .. 15] of AnsiChar;
    BranchType: Int32;
    Flags: TEFLStruct;
    AddrValue: UInt64;
    Immediat: Int64;
    ImplicitModifiedRegs: UInt32;
  end;

  TARGTYPE = packed record
    ArgMnemonic: array [0 .. 32 - 1] of AnsiChar;
    ArgType: Int32;
    ArgSize: Int32;
    ArgPosition: Int32;
    AccessMode: UInt32;
    Memory: TMEMORYTYPE;
    SegmentReg: Int32;
  end;

  _Disasm = packed record
    EIP: UIntPtr;
    VirtualAddr: UInt64;
    SecurityBlock: UInt32;
    CompleteInstr: array [0 .. (INSTRUCT_LENGTH) - 1] of AnsiChar;
    Archi: UInt32;
    Options: UInt64;
    Instruction: TINSTRTYPE;
    Argument1: TARGTYPE;
    Argument2: TARGTYPE;
    Argument3: TARGTYPE;
    Prefix: TPREFIXINFO;
    Reserved_: array [0 .. 39] of longint;
  end;

  TDISASM = _Disasm;
  PDISASM = ^_Disasm;
  LPDISASM = ^_Disasm;

const
  ESReg = 1;
  DSReg = 2;
  FSReg = 3;
  GSReg = 4;
  CSReg = 5;
  SSReg = 6;
  InvalidPrefix = 4;
  SuperfluousPrefix = 2;
  NotUsedPrefix = 0;
  MandatoryPrefix = 8;
  InUsePrefix = 1;

type
  INSTRUCTION_TYPE = Int32;

Const
  GENERAL_PURPOSE_INSTRUCTION = $10000;
  FPU_INSTRUCTION = $20000;
  MMX_INSTRUCTION = $40000;
  SSE_INSTRUCTION = $80000;
  SSE2_INSTRUCTION = $100000;
  SSE3_INSTRUCTION = $200000;
  SSSE3_INSTRUCTION = $400000;
  SSE41_INSTRUCTION = $800000;
  SSE42_INSTRUCTION = $1000000;
  SYSTEM_INSTRUCTION = $2000000;
  VM_INSTRUCTION = $4000000;
  UNDOCUMENTED_INSTRUCTION = $8000000;
  AMD_INSTRUCTION = $10000000;
  ILLEGAL_INSTRUCTION = $20000000;
  AES_INSTRUCTION = $40000000;
  CLMUL_INSTRUCTION = $80000000;

  DATA_TRANSFER = $1;
  ARITHMETIC_INSTRUCTION = 2;
  LOGICAL_INSTRUCTION = 3;
  SHIFT_ROTATE = 4;
  BIT_BYTE = 5;
  CONTROL_TRANSFER = 6;
  STRING_INSTRUCTION = 7;
  InOutINSTRUCTION = 8;
  ENTER_LEAVE_INSTRUCTION = 9;
  FLAG_CONTROL_INSTRUCTION = 10;
  SEGMENT_REGISTER = 11;
  MISCELLANEOUS_INSTRUCTION = 12;
  COMPARISON_INSTRUCTION = 13;
  LOGARITHMIC_INSTRUCTION = 14;
  TRIGONOMETRIC_INSTRUCTION = 15;
  UNSUPPORTED_INSTRUCTION = 16;
  LOAD_CONSTANTS = 17;
  FPUCONTROL = 18;
  STATE_MANAGEMENT = 19;
  CONVERSION_INSTRUCTION = 20;
  SHUFFLE_UNPACK = 21;
  PACKED_SINGLE_PRECISION = 22;
  SIMD128bits = 23;
  SIMD64bits = 24;
  CACHEABILITY_CONTROL = 25;
  FP_INTEGER_CONVERSION = 26;
  SPECIALIZED_128bits = 27;
  SIMD_FP_PACKED = 28;
  SIMD_FP_HORIZONTAL = 29;
  AGENT_SYNCHRONISATION = 30;
  PACKED_ALIGN_RIGHT = 31;
  PACKED_SIGN = 32;
  PACKED_BLENDING_INSTRUCTION = 33;
  PACKED_TEST = 34;
  PACKED_MINMAX = 35;
  HORIZONTAL_SEARCH = 36;
  PACKED_EQUALITY = 37;
  STREAMING_LOAD = 38;
  INSERTION_EXTRACTION = 39;
  DOT_PRODUCT = 40;
  SAD_INSTRUCTION = 41;
  ACCELERATOR_INSTRUCTION = 42; // crc32, popcnt (sse4.2)
  ROUND_INSTRUCTION = 43;

type
  EFLAGS_STATES = Int32;

Const
  TE_ = 1;
  MO_ = 2;
  RE_ = 4;
  SE_ = 8;
  UN_ = $10;
  PR_ = $20;

type
  BRANCH_TYPE = Int32;

Const
  JO = 1;
  JC = 2;
  JE = 3;
  JA = 4;
  JS = 5;
  JP = 6;
  JL = 7;
  JG = 8;
  JB = 9;
  JECXZ = 10;
  JmpType = 11;
  CallType = 12;
  RetType = 13;
  JNO = -(1);
  JNC = -(2);
  JNE = -(3);
  JNA = -(4);
  JNS = -(5);
  JNP = -(6);
  JNL = -(7);
  JNG = -(8);
  JNB = -(9);

type
  ARGUMENTS_TYPE = Int32;

Const
  NO_ARGUMENT = $10000000;
  REGISTER_TYPE = $20000000;
  MEMORY_TYPE = $40000000;
  CONSTANT_TYPE = $80000000;

  MMX_REG = $10000;
  GENERAL_REG = $20000;
  FPU_REG = $40000;
  SSE_REG = $80000;
  CR_REG = $100000;
  DR_REG = $200000;
  SPECIAL_REG = $400000;
  MEMORY_MANAGEMENT_REG = $800000;
  SEGMENT_REG = $1000000;

  RELATIVE_ = $4000000;
  ABSOLUTE_ = $8000000;

  READ = $1;
  WRITE = $2;

  REG0 = $1;
  REG1 = $2;
  REG2 = $4;
  REG3 = $8;
  REG4 = $10;
  REG5 = $20;
  REG6 = $40;
  REG7 = $80;
  REG8 = $100;
  REG9 = $200;
  REG10 = $400;
  REG11 = $800;
  REG12 = $1000;
  REG13 = $2000;
  REG14 = $4000;
  REG15 = $8000;

type
  SPECIAL_INFO = Int32;

Const
  UNKNOWN_OPCODE = -(1);
  OUT_OF_BLOCK = 0;
  { === mask = 0xff }
  NoTabulation = $00000000;
  Tabulation = $00000001;
  { === mask = 0xff00 }
  MasmSyntax = $00000000;
  GoAsmSyntax = $00000100;
  NasmSyntax = $00000200;
  ATSyntax = $00000400;
  { === mask = 0xff0000 }
  PrefixedNumeral = $00010000;
  SuffixedNumeral = $00000000;
  { === mask = 0xff000000 }
  ShowSegmentRegs = $01000000;
  LowPosition = 0;
  HighPosition = 1;

function Disasm(var aDisAsm: TDISASM): longint; stdcall;
function BeaEngineVersion: longint; stdcall;
function BeaEngineRevision: longint; stdcall;

implementation

{$IFNDEF USEDLL}
{$IFDEF CPUX64}
{$L BeaEngine64.obj}
{$ELSE}
{$L BeaEngine32.obj}
{$ENDIF}

function strlen(s: PAnsiChar): Cardinal; cdecl;
begin
  Result := Length(s);
end;

function strcpy(dest, src: PAnsiChar): PAnsiChar; cdecl;
begin
  Move(src^, dest^, (strlen(src) + 1) * SizeOf(AnsiChar));
  Result := dest;
end;

function memset(Destination: Pointer; C: Integer; Count: NativeInt)
  : Pointer; cdecl;
begin
  FillChar(PAnsiChar(Destination)^, Count, C);
  Result := Destination;
end;

function sprintf(Buffer, Format: PAnsiChar): longint; varargs; cdecl;
  external 'User32.DLL' name 'wsprintfA';

function Disasm(var aDisAsm: TDISASM): longint; stdcall; external;
function BeaEngineVersion: longint; stdcall; external;
function BeaEngineRevision: longint; stdcall; external;

{$ELSE}
function Disasm(var aDisAsm: TDISASM): longint; stdcall;
  external 'BeaEngine.DLL' name '_Disasm@4';
function BeaEngineVersion: longint; stdcall;
  external 'BeaEngine.DLL' name '_BeaEngineVersion@0';
function BeaEngineRevision: longint; stdcall;
  external 'BeaEngine.DLL' name '_BeaEngineRevision@0';
{$ENDIF}

end.
