object Form4: TForm4
  Left = 460
  Top = 265
  BorderStyle = bsDialog
  Caption = 'Form4'
  ClientHeight = 260
  ClientWidth = 424
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 40
    Top = 32
    Width = 313
    Height = 49
    AutoSize = False
    Caption = 'Label1'
  end
  object CheckBox1: TCheckBox
    Left = 40
    Top = 108
    Width = 313
    Height = 17
    Caption = 'Hook API(DrawtextEx)'
    TabOrder = 0
    OnClick = CheckBox1Click
  end
  object CheckBox2: TCheckBox
    Left = 40
    Top = 145
    Width = 97
    Height = 17
    Caption = 'Hook COM'
    TabOrder = 1
    OnClick = CheckBox2Click
  end
  object CheckBox3: TCheckBox
    Left = 40
    Top = 184
    Width = 97
    Height = 17
    Caption = 'Hook Method'
    TabOrder = 2
    OnClick = CheckBox3Click
  end
end
