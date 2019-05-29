{******************************************************************************}
{                                                                              }
{  Delphi JOSE Library                                                         }
{  Copyright (c) 2015-2017 Paolo Rossi                                         }
{  https://github.com/paolo-rossi/delphi-jose-jwt                              }
{                                                                              }
{******************************************************************************}
{                                                                              }
{  Licensed under the Apache License, Version 2.0 (the "License");             }
{  you may not use this file except in compliance with the License.            }
{  You may obtain a copy of the License at                                     }
{                                                                              }
{      http://www.apache.org/licenses/LICENSE-2.0                              }
{                                                                              }
{  Unless required by applicable law or agreed to in writing, software         }
{  distributed under the License is distributed on an "AS IS" BASIS,           }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    }
{  See the License for the specific language governing permissions and         }
{  limitations under the License.                                              }
{                                                                              }
{******************************************************************************}

unit JWTDemo.Form.Debugger;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls,
  JOSE.Core.JWT,
  JOSE.Core.JWS,
  JOSE.Core.JWE,
  JOSE.Core.JWK,
  JOSE.Core.JWA,
  JOSE.Types.JSON,
  JOSE.Encoding.Base64;

type
  TfrmDebugger = class(TForm)
    lblEncoded: TLabel;
    lblAlgorithm: TLabel;
    lblDecoded: TLabel;
    lblHMAC: TLabel;
    memoHeader: TMemo;
    memoPayload: TMemo;
    richEncoded: TRichEdit;
    cbbDebuggerAlgo: TComboBox;
    edtKey: TEdit;
    chkKeyBase64: TCheckBox;
    shpStatus: TShape;
    lblStatus: TLabel;
    lblHeader: TLabel;
    lblPayload: TLabel;
    lblSignature: TLabel;
    procedure cbbDebuggerAlgoChange(Sender: TObject);
    procedure chkKeyBase64Click(Sender: TObject);
    procedure edtKeyChange(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure memoHeaderChange(Sender: TObject);
    procedure memoPayloadChange(Sender: TObject);
  private
    FJWT: TJWT;
    FAlg: TJOSEAlgorithmId;

    procedure GenerateToken;
    procedure WriteCompactHeader(const AHeader: string);
    procedure WriteCompactClaims(const AClaims: string);
    procedure WriteCompactSignature(const ASignature: string);
    procedure WriteCompactSeparator;
    procedure SetStatus(AVerified: Boolean);
    procedure SetErrorJSON;
    function VerifyToken(AKey: TJWK): Boolean;
    procedure WriteDefault;
  public
    { Public declarations }
  end;

var
  frmDebugger: TfrmDebugger;

implementation

{$R *.dfm}

procedure TfrmDebugger.cbbDebuggerAlgoChange(Sender: TObject);
begin
  case cbbDebuggerAlgo.ItemIndex of
    0: FAlg := TJOSEAlgorithmId.HS256;
    1: FAlg := TJOSEAlgorithmId.HS384;
    2: FAlg := TJOSEAlgorithmId.HS512;
  end;
  GenerateToken;
end;

procedure TfrmDebugger.chkKeyBase64Click(Sender: TObject);
begin
  GenerateToken;
end;

procedure TfrmDebugger.edtKeyChange(Sender: TObject);
var
  LKey: TJWK;
begin
  if chkKeyBase64.Checked then
    LKey := TJWK.Create(TBase64.Decode(edtKey.Text))
  else
    LKey := TJWK.Create(edtKey.Text);

  try
    SetStatus(VerifyToken(LKey));
  finally
    LKey.Free;
  end;
end;

procedure TfrmDebugger.FormDestroy(Sender: TObject);
begin
  FJWT.Free;
end;

procedure TfrmDebugger.FormCreate(Sender: TObject);
begin
  FJWT := TJWT.Create(TJWTClaims);

  FJWT.Header.JSON.Free;
  FJWT.Header.JSON := TJSONObject(TJSONObject.ParseJSONValue(memoHeader.Lines.Text));

  FJWT.Claims.JSON.Free;
  FJWT.Claims.JSON := TJSONObject(TJSONObject.ParseJSONValue(memoPayload.Lines.Text));

  FAlg := TJOSEAlgorithmId.HS256;

  WriteDefault;
end;

procedure TfrmDebugger.GenerateToken;
var
  LSigner: TJWS;
  LKey: TJWK;
begin
  richEncoded.Lines.Clear;
  if Assigned(FJWT.Header.JSON) and Assigned(FJWT.Claims.JSON) then
  begin
    richEncoded.Color := clWindow;

    LSigner := TJWS.Create(FJWT);

    if chkKeyBase64.Checked then
      LKey := TJWK.Create(TBase64.Decode(edtKey.Text))
    else
      LKey := TJWK.Create(edtKey.Text);

    try
      LSigner.SkipKeyValidation := True;
      LSigner.Sign(LKey, FAlg);

      WriteCompactHeader(LSigner.Header);
      WriteCompactSeparator;
      WriteCompactClaims(LSigner.Payload);
      WriteCompactSeparator;
      WriteCompactSignature(LSigner.Signature);

      SetStatus(VerifyToken(LKey));
    finally
      LKey.Free;
      LSigner.Free;
    end;
  end
  else
  begin
    richEncoded.Color := $00CACAFF;
    SetErrorJSON;
  end;
end;

procedure TfrmDebugger.memoHeaderChange(Sender: TObject);
begin
  FJWT.Header.JSON.Free;
  FJWT.Header.JSON := TJSONObject(TJSONObject.ParseJSONValue((Sender as TMemo).Lines.Text));
  GenerateToken;
end;

procedure TfrmDebugger.memoPayloadChange(Sender: TObject);
begin
  FJWT.Claims.JSON.Free;
  FJWT.Claims.JSON := TJSONObject(TJSONObject.ParseJSONValue((Sender as TMemo).Lines.Text));
  GenerateToken;
end;

procedure TfrmDebugger.SetErrorJSON;
begin
  shpStatus.Brush.Color := clRed;
  lblStatus.Caption := 'JSON Data Error';
end;

procedure TfrmDebugger.SetStatus(AVerified: Boolean);
begin
  if AVerified then
  begin
    shpStatus.Brush.Color := $00F5C647;
    lblStatus.Caption := 'Signature Verified';
  end
  else
  begin
    shpStatus.Brush.Color := clRed;
    lblStatus.Caption := 'Invalid Signature';
  end;
end;

function TfrmDebugger.VerifyToken(AKey: TJWK): Boolean;
var
  LToken: TJWT;
  LSigner: TJWS;
  LCompactToken: string;
begin
  Result := False;
  LCompactToken := StringReplace(richEncoded.Lines.Text, sLineBreak, '', [rfReplaceAll]);

  LToken := TJWT.Create;
  try
    LSigner := TJWS.Create(LToken);
    LSigner.SkipKeyValidation := True;
    try
      LSigner.SetKey(AKey);
      LSigner.CompactToken := LCompactToken;
      LSigner.VerifySignature;
    finally
      LSigner.Free;
    end;

    if LToken.Verified then
      Result := True;
  finally
    LToken.Free;
  end;
end;

procedure TfrmDebugger.WriteCompactClaims(const AClaims: string);
begin
  richEncoded.SelAttributes.Color := clFuchsia;
  richEncoded.SelText := AClaims;
end;

procedure TfrmDebugger.WriteCompactHeader(const AHeader: string);
begin
  richEncoded.SelAttributes.Color := clRed;
  richEncoded.SelText := AHeader;
end;

procedure TfrmDebugger.WriteCompactSeparator;
begin
  richEncoded.SelAttributes.Color := clBlack;
  richEncoded.SelText := '.';
end;

procedure TfrmDebugger.WriteCompactSignature(const ASignature: string);
begin
  richEncoded.SelAttributes.Color := clTeal;
  richEncoded.SelText := ASignature;
end;

procedure TfrmDebugger.WriteDefault;
begin
  richEncoded.Lines.Clear;
  WriteCompactHeader('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9');
  WriteCompactSeparator;
  WriteCompactClaims('eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWV9');
  WriteCompactSeparator;
  WriteCompactSignature('TJVA95OrM7E2cBab30RMHrHDcEfxjoYZgeFONFh7HgQ');

  SetStatus(True);
end;

end.
