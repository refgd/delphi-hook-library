unit HookUtils;

{
  wr960204武稀松.2012.2

  主页  http://www.raysoftware.cn

  通用Hook库.
  支持X86和X64.                     Get
  使用了开源的BeaEngine反汇编引擎.BeaEngine的好处是可以用BCB编译成OMF格式的Obj,
  被链接进Delphi的DCU和目标文件中.不需要额外带DLL.
  BeaEngin引擎
  http://www.beaengine.org/

  限制:
  1.不能Hook代码大小小于5个字节的函数.
  2.不能Hook前五个字节中有跳转指令的函数.
  希望使用的朋友们自己也具有一定的汇编或者逆向知识.
  Hook函数前请确定该函数不属于上面两种情况.


  另外钩COM对象有一个技巧,如果你想在最早时机勾住某个COM对象,
  可以在你要钩的COM对象创建前自己先创建一个该对象,Hook住,然后释放你自己的对象.
  这样这个函数已经被下钩子了,而且是钩在这个COM对象创建前的.
}
interface

{ 下函数钩子
  64位中会有一种情况失败,就是VirtualAlloc不能在被Hook函数地址正负2Gb范围内分配到内存.
  不过这个可能微乎其微.几乎不可能发生.
}
function HookProc(Func, NewFunc: Pointer; out originalFunc: Pointer)
  : Boolean; overload;
function HookProcInModule(DLLName, FuncName: PChar; NewFunc: Pointer; out originalFunc: Pointer): Boolean;
  overload;

//deprecated 不建议试用,返回值后返回,这时无法Hook函数中使用的设置虚拟内存和线程状态的函数
function HookProc(Func, NewFunc: Pointer): Pointer; overload;
//deprecated 不建议试用,返回值后返回,这时无法Hook函数中使用的设置虚拟内存和线程状态的函数
function HookProcInModule(DLLName, FuncName: PChar; NewFunc: Pointer): Pointer;
  overload;
{ 计算COM对象中方法的地址;AMethodIndex是方法的索引.
  AMethodIndex是接口包含父接口的方法的索引.
  例如:
  IA = Interface
  procedure A();//因为IA是从IUnKnow派生的,IUnKnow自己有3个方法,所以AMethodIndex=3
  end;
  IB = Interface(IA)
  procedure B(); //因为IB是从IA派生的,所以AMethodIndex=4
  end;
}
function CalcInterfaceMethodAddr(var AInterface; AMethodIndex: Integer)
  : Pointer;
// 下COM对象方法的钩子
function HookInterface(var AInterface; AMethodIndex: Integer;
  NewFunc: Pointer; out originalFunc: Pointer): Boolean;
// 解除钩子
function UnHook(OldFunc: Pointer): Boolean;

implementation

uses
  BeaEngineDelphi, Windows, TLHelp32;

const
  PageSize = 4096;
{$IFDEF CPUX64}
{$DEFINE USELONGJMP}
{$ENDIF}
  {.$DEFINE USEINT3 }// 在机器指令中插入INT3,断点指令.方便调试.

type
  THandles = array of THandle;
  ULONG_PTR = NativeUInt;
  POldProc = ^TOldProc;

  PJMPCode = ^TJMPCode;

  TJMPCode = packed record
{$IFDEF USELONGJMP}
    JMP: Word;
    JmpOffset: Int32;
{$ELSE}
    JMP: byte;
{$ENDIF}
    Addr: UIntPtr;
  end;

  TOldProc = packed record
{$IFDEF USEINT3}
    Int3OrNop: byte;
{$ENDIF}
    BackCode: array [0 .. $20 - 1] of byte;
    JmpRealFunc: TJMPCode;
    JmpHookFunc: TJMPCode;

    BackUpCodeSize: Integer;
    OldFuncAddr: Pointer;
  end;

  PNewProc = ^TNewProc;

  TNewProc = packed record
    JMP: byte;
    Addr: Integer;
  end;

  // 计算需要覆盖的机器指令大小.借助了BeaEngin反汇编引擎.以免指令被从中间切开
function CalcHookCodeSize(Func: Pointer): Integer;
var
  ldiasm: TDISASM;
  len: longint;
begin
  Result := 0;
  ZeroMemory(@ldiasm, SizeOf(ldiasm));
  ldiasm.EIP := UIntPtr(Func);
  ldiasm.Archi := {$IFDEF CPUX64}64{$ELSE}32{$ENDIF};
  while Result < SizeOf(TNewProc) do
  begin
    len := Disasm(ldiasm);
    Inc(ldiasm.EIP, len);
    Inc(Result, len);
  end;
end;

const
  THREAD_ALL_ACCESS = STANDARD_RIGHTS_REQUIRED or SYNCHRONIZE or $3FF;

function OpenThread(dwDesiredAccess: DWORD; bInheritHandle: BOOL;
  dwThreadId: DWORD): THandle; stdcall; external kernel32;

function SuspendOneThread(dwThreadId: NativeUInt; ACode: Pointer;
  ASize: Integer): THandle;
var
  hThread: THandle;
  dwSuspendCount: DWORD;
  ctx: TContext;
  IPReg: Pointer;
  tryTimes: Integer;
begin
  Result := INVALID_HANDLE_VALUE;
  hThread := OpenThread(THREAD_ALL_ACCESS, FALSE, dwThreadId);
  if (hThread <> 0) and (hThread <> INVALID_HANDLE_VALUE) then
  begin
    dwSuspendCount := SuspendThread(hThread);
    // SuspendThread返回的是被挂起的引用计数,-1的话是失败.
    if dwSuspendCount <> DWORD(-1) then
    begin
      while (GetThreadContext(hThread, ctx)) do
      begin
        tryTimes := 0;
        IPReg := Pointer({$IFDEF CPUX64}ctx.Rip{$ELSE}ctx.EIP{$ENDIF});
        if (NativeInt(IPReg) >= NativeInt(ACode)) and
          (NativeInt(IPReg) <= (NativeInt(ACode) + ASize)) then
        begin
          ResumeThread(hThread);
          Sleep(100);
          SuspendThread(hThread);
          Inc(tryTimes);
          if tryTimes > 5 then
          begin
            Break;
          end;
        end
        else
        begin
          Result := hThread;
          Break;
        end;
      end;
    end;
  end;
end;

function SuspendOtherThread(ACode: Pointer; ASize: Integer): THandles;
var
  hSnap: THandle;
  te: THREADENTRY32;
  nThreadsInProcess: DWORD;
  hThread: THandle;
begin
  Exit;
  hSnap := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, GetCurrentProcessId());
  te.dwSize := SizeOf(te);

  nThreadsInProcess := 0;
  if (Thread32First(hSnap, te)) then
  begin
    while True do
    begin
      if (te.th32OwnerProcessID = GetCurrentProcessId()) then
      begin

        if (te.th32ThreadID <> GetCurrentThreadId()) then
        begin
          hThread := SuspendOneThread(te.th32ThreadID, ACode, ASize);
          if hThread <> INVALID_HANDLE_VALUE then
          begin
            Inc(nThreadsInProcess);
            SetLength(Result, nThreadsInProcess);
            Result[nThreadsInProcess - 1] := hThread;
          end;
        end
      end;
      te.dwSize := SizeOf(te);
      if not Thread32Next(hSnap, te) then
        Break;
    end;
    // until not Thread32Next(hSnap, te);
  end;

  CloseHandle(hSnap);
end;

procedure ResumOtherThread(threads: THandles);
var
  i: Integer;
begin
  Exit;
  for i := Low(threads) to High(threads) do
  begin
    ResumeThread(threads[i]);
    CloseHandle(threads[i]);
  end;
end;

{
  尝试在指定指针APtr的正负2Gb以内分配内存.32位肯定是这样的.
  64位JMP都是相对的.操作数是32位整数.所以必须保证新的函数在旧函数的正负2GB内.
  否则没法跳转到或者跳转回来.
}
function TryAllocMem(APtr: Pointer; ASize: Cardinal): Pointer;
const
  KB: Int64 = 1024;
  MB: Int64 = 1024 * 1024;
  GB: Int64 = 1024 * 1024 * 1024;
var
  mbi: TMemoryBasicInformation;
  Min, Max: Int64;
  pbAlloc: Pointer;
  sSysInfo: TSystemInfo;
begin

  GetSystemInfo(sSysInfo);
  Min := NativeUInt(APtr) - 2 * GB;
  if Min <= 0 then
    Min := 1;
  Max := NativeUInt(APtr) + 2 * GB;

  Result := nil;
  pbAlloc := Pointer(Min);
  while NativeUInt(pbAlloc) < Max do
  begin
    if (VirtualQuery(pbAlloc, mbi, SizeOf(mbi)) = 0) then
      Break;
    if ((mbi.State or MEM_FREE) = MEM_FREE) and (mbi.RegionSize >= ASize) and
      (mbi.RegionSize >= sSysInfo.dwAllocationGranularity) then
    begin
      pbAlloc :=
        PByte(ULONG_PTR((ULONG_PTR(pbAlloc) + (sSysInfo.dwAllocationGranularity
        - 1)) div sSysInfo.dwAllocationGranularity) *
        sSysInfo.dwAllocationGranularity);
      Result := VirtualAlloc(pbAlloc, ASize, MEM_COMMIT or MEM_RESERVE
{$IFDEF CPUX64}
        or MEM_TOP_DOWN
{$ENDIF}
        , PAGE_EXECUTE_READWRITE);
      if Result <> nil then
        Break;
    end;
    pbAlloc := Pointer(NativeUInt(mbi.BaseAddress) + mbi.RegionSize);
  end;

end;

function HookProc(Func, NewFunc: Pointer): Pointer; overload;
begin
  if not HookProc(Func, NewFunc, Result) then
    Result := nil;
end;

function HookProcInModule(DLLName, FuncName: PChar; NewFunc: Pointer): Pointer;
begin
  if not HookProcInModule(DLLName, FuncName, NewFunc, Result) then
    Result := nil;
end;

function HookProcInModule(DLLName, FuncName: PChar; NewFunc: Pointer; out originalFunc: Pointer): Boolean;
var
  h: HMODULE;
begin
  Result := False;
  h := GetModuleHandle(DLLName);
  if h = 0 then
    h := LoadLibrary(DLLName);
  if h = 0 then
    Exit;
  Result := HookProc(GetProcAddress(h, FuncName), NewFunc, originalFunc);
end;

function HookProc(Func, NewFunc: Pointer; out originalFunc: Pointer): Boolean;
  procedure FixFunc();
  var
    ldiasm: TDISASM;
    len: longint;
  begin
    ZeroMemory(@ldiasm, SizeOf(ldiasm));
    ldiasm.EIP := UIntPtr(Func);
    ldiasm.Archi := {$IFDEF CPUX64}64{$ELSE}32{$ENDIF};

    len := Disasm(ldiasm);
    Inc(ldiasm.EIP, len);
    //
    if (ldiasm.Instruction.Mnemonic[0] = 'j') and
      (ldiasm.Instruction.Mnemonic[1] = 'm') and
      (ldiasm.Instruction.Mnemonic[2] = 'p') and
      (ldiasm.Instruction.AddrValue <> 0) then
    begin
      Func := Pointer(ldiasm.Instruction.AddrValue);
      FixFunc();
    end;
  end;

var
  oldProc: POldProc;
  newProc: PNewProc;
  backCodeSize: Integer;
  newProtected, oldProtected: DWORD;
  threads: THandles;
  nOriginalPriority: Integer;
  JmpAfterBackCode: PJMPCode;
begin
  Result := FALSE;
  if (Func = nil) or (NewFunc = nil) then
    Exit;

  FixFunc();
  newProc := PNewProc(Func);
  backCodeSize := CalcHookCodeSize(Func);
  if backCodeSize < 0 then
    Exit;
  nOriginalPriority := GetThreadPriority(GetCurrentThread());
  SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);
  // 改写内存的时候要挂起其他线程,以免造成错误.
  threads := SuspendOtherThread(Func, backCodeSize);
  try
    if not VirtualProtect(Func, backCodeSize, PAGE_EXECUTE_READWRITE,
      oldProtected) then
      Exit;
    //

    originalFunc := TryAllocMem(Func, PageSize);
    // VirtualAlloc(nil, PageSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    if originalFunc = nil then
      Exit;

    FillMemory(originalFunc, SizeOf(TOldProc), $90);
    oldProc := POldProc(originalFunc);
{$IFDEF USEINT3}
    oldProc.Int3OrNop := $CC;
{$ENDIF}
    oldProc.BackUpCodeSize := backCodeSize;
    oldProc.OldFuncAddr := Func;
    CopyMemory(@oldProc^.BackCode, Func, backCodeSize);
    JmpAfterBackCode := PJMPCode(@oldProc^.BackCode[backCodeSize]);
{$IFDEF USELONGJMP}
    oldProc^.JmpRealFunc.JMP := $25FF;
    oldProc^.JmpRealFunc.JmpOffset := 0;
    oldProc^.JmpRealFunc.Addr := UIntPtr(Int64(Func) + backCodeSize);

    JmpAfterBackCode^.JMP := $25FF;
    JmpAfterBackCode^.JmpOffset := 0;
    JmpAfterBackCode^.Addr := UIntPtr(Int64(Func) + backCodeSize);

    oldProc^.JmpHookFunc.JMP := $25FF;
    oldProc^.JmpHookFunc.JmpOffset := 0;
    oldProc^.JmpHookFunc.Addr := UIntPtr(NewFunc);
{$ELSE}
    oldProc^.JmpRealFunc.JMP := $E9;
    oldProc^.JmpRealFunc.Addr := (NativeInt(Func) + backCodeSize) -
      (NativeInt(@oldProc^.JmpRealFunc) + 5);

    oldProc^.JmpHookFunc.JMP := $E9;
    oldProc^.JmpHookFunc.Addr := NativeInt(NewFunc) -
      (NativeInt(@oldProc^.JmpHookFunc) + 5);
{$ENDIF}
    //
    FillMemory(Func, backCodeSize, $90);

    newProc^.JMP := $E9;
    newProc^.Addr := NativeInt(@oldProc^.JmpHookFunc) -
      (NativeInt(@newProc^.JMP) + 5);;
    // NativeInt(NewFunc) - (NativeInt(@newProc^.JMP) + 5);

    if not VirtualProtect(Func, backCodeSize, oldProtected, newProtected) then
      Exit;
    // 刷新处理器中的指令缓存.以免这部分指令被缓存.执行的时候不一致.
    FlushInstructionCache(GetCurrentProcess(), newProc, backCodeSize);
    FlushInstructionCache(GetCurrentProcess(), oldProc, PageSize);
    Result := True;
  finally
    ResumOtherThread(threads);
    SetThreadPriority(GetCurrentThread(), nOriginalPriority);
  end;
end;

function UnHook(OldFunc: Pointer): Boolean;
var
  oldProc: POldProc ABSOLUTE OldFunc;
  newProc: PNewProc;
  backCodeSize: Integer;
  newProtected, oldProtected: DWORD;
  threads: THandles;
  nOriginalPriority: Integer;
begin
  Result := FALSE;
  if (OldFunc = nil) then
    Exit;
  backCodeSize := oldProc^.BackUpCodeSize;
  newProc := PNewProc(oldProc^.OldFuncAddr);

  nOriginalPriority := GetThreadPriority(GetCurrentThread());
  SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);
  threads := SuspendOtherThread(oldProc, SizeOf(TOldProc));
  try
    if not VirtualProtect(newProc, backCodeSize, PAGE_EXECUTE_READWRITE,
      oldProtected) then
      Exit;

    CopyMemory(newProc, @oldProc^.BackCode, oldProc^.BackUpCodeSize);

    if not VirtualProtect(newProc, backCodeSize, oldProtected, newProtected)
    then
      Exit;
    VirtualFree(oldProc, PageSize, MEM_FREE);
    // 刷新处理器中的指令缓存.以免这部分指令被缓存.执行的时候不一致.
    FlushInstructionCache(GetCurrentProcess(), newProc, backCodeSize);
  finally
    ResumOtherThread(threads);
    SetThreadPriority(GetCurrentThread(), nOriginalPriority);
  end;
end;

function CalcInterfaceMethodAddr(var AInterface; AMethodIndex: Integer)
  : Pointer;
type
  TBuf = array [0 .. $FF] of byte;
  PBuf = ^TBuf;
var
  pp: PPointer;
  buf: PBuf;
begin
  pp := PPointer(AInterface)^;
  Inc(pp, AMethodIndex);
  Result := pp^;
  { Delphi的COM对象的方法表比较特别,COM接口实际上是对象的一个成员,实际上调用到
    方法后Self是这个接口成员的地址,所以Delphi的COM方法不直接指向对象方法,而是指向
    一小段机器指令,把Self减去(加负数)这个成员在对象中的偏移,修正好Self指针后再跳转
    到真正对象的方法入口.

    所以这里要"偷窥"一下方法指针指向的头几个字节,如果是修正Self指针的,那么就是Delphi
    实现的COM对象.我们就再往下找真正的对象地址.

    下面代码就是判断和处理Delphi的COM对象的.其他语言实现的COM对象会自动忽略的.
    因为正常的函数头部都是对于栈底的处理或者参数到局部变量的处理代码.
    绝不可能一上来修正第一个参数,也就是Self的指针.所以根据这个来判断.
  }
  buf := Result;
  {
    add Self,[-COM对象相对实现对象偏移]
    JMP  真正的方法
    这样的就是Delphi生成的COM对象方法的前置指令
  }
{$IFDEF CPUX64}
  // add rcx, -COM对象的偏移, JMP 真正对象的方法地址,X64中只有一种stdcall调用约定.其他约定都是stdcall的别名
  if (buf^[0] = $48) and (buf^[1] = $81) and (buf^[2] = $C1) and (buf^[7] = $E9)
  then
    Result := Pointer(NativeInt(@buf[$C]) + PDWORD(@buf^[8])^);
{$ELSE}
  // add [esp + $04],-COM对象的偏移, JMP真正的对象地址,stdcall/cdecl调用约定
  if (buf^[0] = $81) and (buf^[1] = $44) and (buf^[2] = $24) and
    (buf^[03] = $04) and (buf^[8] = $E9) then
    Result := Pointer(NativeInt(@buf[$D]) + PDWORD(@buf^[9])^)
  else // add eax,-COM对象的偏移, JMP真正的对象地址,那就是Register调用约定的
    if (buf^[0] = $05) and (buf^[5] = $E9) then
      Result := Pointer(NativeInt(@buf[$A]) + PDWORD(@buf^[6])^);
{$ENDIF}
end;

function HookInterface(var AInterface; AMethodIndex: Integer;
  NewFunc: Pointer; out originalFunc: Pointer): Boolean;
begin
  Result := HookProc(CalcInterfaceMethodAddr(AInterface, AMethodIndex), NewFunc, originalFunc);
end;

end.
