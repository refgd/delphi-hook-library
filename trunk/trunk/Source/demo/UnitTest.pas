unit UnitTest;

interface

uses
  Windows, Messages, SysUtils, Variants, ShlObj,
  Graphics, ComObj, ActiveX,
  Controls, Forms, Dialogs, StdCtrls, Classes;

type

  TForm4 = class(TForm)
    Label1: TLabel;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure CheckBox1Click(Sender: TObject);
    procedure CheckBox2Click(Sender: TObject);
    procedure CheckBox3Click(Sender: TObject);
  private
    FShellLink: IShellLink;
  public

  end;

var
  Form4: TForm4;

implementation

{$R *.dfm}

uses
  HookUtils;

var
  old_DrawTextEx: function(DC: HDC; lpchText: LPCTSTR; cchText: Integer;
    var p4: TRect; dwDTFormat: UINT; DTParams: PDrawTextParams)
    : Integer; stdcall;

function _DrawTextEx(DC: HDC; lpchText: LPCTSTR; cchText: Integer;
  var p4: TRect; dwDTFormat: UINT; DTParams: PDrawTextParams): Integer; stdcall;
var
  s: string;
begin
  if copy(lpchText, 1, 5) = 'Label' then
    s := '我把Label开头的文字改成现在的样子了,别见怪!'
  else
    s := lpchText;

  Result := old_DrawTextEx(DC, PChar(s), Length(s), p4, dwDTFormat, DTParams);
end;

var // 真的IShellLink.Setpath方法
  Old_SetPath: function(Self: IShellLink; pszFile: LPTSTR): HResult; stdcall;

  // Hook的IShellLink.SetPath方法
function _SetPath(Self: IShellLink; pszFile: LPTSTR): HResult; stdcall;
begin
  ShowMessage(Format('你调用到ISHellLink($%x)的SetPath方法了,参数"%s"',
    [NativeInt(Pointer(Self)), string(pszFile)]));
  Result := Old_SetPath(Self, 'd:\Windows');
end;

var // 真的IShellLink.Setpath方法
  Old_FreeInstance: procedure(Self: TObject);

  // Hook的IShellLink.SetPath方法
procedure _FreeInstance(Self: TObject);
begin
  if Self <> nil then
    OutputDebugString(PChar(Format('"%s"实例[%x]被释放!', [Self.ClassName,
      NativeInt(Self)])));
  Old_FreeInstance(Self);
end;

procedure TForm4.CheckBox1Click(Sender: TObject);
const
{$IFDEF UNICODE}
  DrawTextExRealName = 'DrawTextExW';
{$ELSE}
  DrawTextExRealName = 'DrawTextExA';
{$ENDIF}
begin

  if CheckBox1.Checked then
  begin
    // 测试API钩子,DrawtextEx,因为我是Unicode版本Delphi
    if not Assigned(old_DrawTextEx) then
    begin
      @old_DrawTextEx := HookProc(user32, DrawTextExRealName, @_DrawTextEx);
      // 重绘,画出来的文字就会变样了.
    end
    else
    begin
      ShowMessage('钩过了,不需要重复来吧!');
    end;
  end
  else
  begin
    if Assigned(old_DrawTextEx) then
      UnHook(@old_DrawTextEx);
    @old_DrawTextEx := nil;
  end;
  // 刷新界面,让Form重绘Label
  Invalidate();
end;

procedure TForm4.CheckBox2Click(Sender: TObject);
begin
  if CheckBox2.Checked then
  begin
    if not Assigned(Old_SetPath) then
    begin
      @Old_SetPath := HookInterface(FShellLink, 20, @_SetPath);
      FShellLink.SetPath('c:\Windows');
    end
    else
    begin
      ShowMessage('钩过了,不需要重复来吧!');
    end;
  end
  else
  begin
    if Assigned(Old_SetPath) then
      UnHook(@Old_SetPath);
    @Old_SetPath := nil;
  end;
end;

procedure TForm4.CheckBox3Click(Sender: TObject);
begin
  if CheckBox3.Checked then
  begin
    if not Assigned(Old_FreeInstance) then
    begin
      @Old_FreeInstance := HookProc(@TObject.FreeInstance, @_FreeInstance);
      ShowMessage('在你的EventLog窗口里看看有哪些对象被释放了 :-)');
    end
    else
    begin
      ShowMessage('钩过了,不需要重复来吧!');
    end;
  end
  else
  begin
    if Assigned(Old_FreeInstance) then
      UnHook(@Old_FreeInstance);
    @Old_FreeInstance := nil;
  end;
end;

procedure TForm4.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(Old_SetPath) then
    UnHook(@Old_SetPath);
  if Assigned(old_DrawTextEx) then
    UnHook(@old_DrawTextEx);
  if Assigned(Old_FreeInstance) then
    UnHook(@Old_FreeInstance);
end;

procedure TForm4.FormCreate(Sender: TObject);
begin
  FShellLink := CreateComObject(CLSID_ShellLink) as IShellLink;
end;

end.
