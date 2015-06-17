{*******************************************************************************
  Copyright (C) Christian Ulrich info@cu-tec.de

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or commercial alternative
  contact us for more information

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
Created 16.06.2015
*******************************************************************************}
 program message_xmpp;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, CustApp
  { you can add units after this },db, Utils, FileUtil, uData, uIntfStrConsts,
  pcmdprometapp, uBaseCustomApplication, uBaseApplication, uxmpp, synautil,
  uPerson, uBaseDbClasses, uspeakinginterface;

type
  { PrometXMPPMessanger }
  PrometXMPPMessanger = class(TBaseCustomApplication)
    procedure SpeakerWriteln(const s: string);
    procedure xmppDebugXML(Sender: TObject; Value: string);
    procedure xmppError(Sender: TObject; ErrMsg: string);
    procedure xmppIqVcard(Sender: TObject; from_, to_, fn_, photo_type_,
      photo_bin_: string);
    procedure xmppLogin(Sender: TObject);
    procedure xmppLogout(Sender: TObject);
    procedure xmppMessage(Sender: TObject; From: string; MsgText: string;
      MsgHTML: string; TimeStamp: TDateTime; MsgType: TMessageType);
    procedure xmppPresence(Sender: TObject; Presence_Type, JID, Resource,
      Status, Photo: string);
  private
    FActive : Boolean;
    FUsers : TStringList;
    Speaker: TSpeakingInterface;
    xmpp: TXmpp;
    FJID : string;
  protected
    procedure DoRun; override;
    function CheckUser(JID : string) : Boolean;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure PrometXMPPMessanger.SpeakerWriteln(const s: string);
begin
  if FJID<>'' then
    begin
      xmpp.SendPersonalMessage(FJID,s);
      writeln('answ:'+s);
    end;
end;
procedure PrometXMPPMessanger.xmppDebugXML(Sender: TObject; Value: string);
begin
  writeln('Debug:'+Value);
end;
procedure PrometXMPPMessanger.xmppError(Sender: TObject; ErrMsg: string);
begin
  FActive := False;
  writeln('error:'+ErrMsg);
end;
procedure PrometXMPPMessanger.xmppIqVcard(Sender: TObject; from_, to_, fn_,
  photo_type_, photo_bin_: string);
begin
  writeln('vcard:'+from_);
end;
procedure PrometXMPPMessanger.xmppLogin(Sender: TObject);
begin
  FActive := True;
  writeln('login ok');
end;
procedure PrometXMPPMessanger.xmppLogout(Sender: TObject);
begin
  FActive:=False;
  writeln('logout');
end;
procedure PrometXMPPMessanger.xmppMessage(Sender: TObject; From: string;
  MsgText: string; MsgHTML: string; TimeStamp: TDateTime; MsgType: TMessageType
  );
begin
  writeln('msg:'+From+':'+MsgText);
  if CheckUser(From) then
    begin
      FJID:=From;
      Speaker.CheckSentence(MsgText);
      FJID:='';
    end
  else writeln('user unknown !')
end;
procedure PrometXMPPMessanger.xmppPresence(Sender: TObject; Presence_Type, JID,
  Resource, Status, Photo: string);
begin
  writeln('presence:'+Presence_Type+','+JID+','+Resource+','+Status+',',Photo);
  if CheckUser(JID) then
    begin

    end
  else writeln('user unknown !')
end;
procedure PrometXMPPMessanger.DoRun;
begin
  FActive:=True;
  with BaseApplication as IBaseApplication do
    begin
      AppVersion:={$I ../base/version.inc};
      AppRevision:={$I ../base/revision.inc};
    end;
  if not Login then Terminate;
  //Your logged in here on promet DB
  Speaker := TSpeakingInterface.Create(nil);
  Speaker.Writeln:=@SpeakerWriteln;
  xmpp := TXmpp.Create;
  xmpp.Host := synautil.SeparateRight(GetOptionValue('jid'), '@');
  xmpp.JabberID := GetOptionValue('jid');
  xmpp.Password := GetOptionValue('pw');
  xmpp.Port:='5222';
  xmpp.OnLogin:=@xmppLogin;
  xmpp.OnError:=@xmppError;
  xmpp.OnPresence:=@xmppPresence;
  xmpp.OnMessage:=@xmppMessage;
  xmpp.OnLogout:=@xmppLogout;
  if HasOption('server-log') then
    xmpp.OnDebugXML:=@xmppDebugXML;
  xmpp.OnIqVcard:=@xmppIqVcard;
  writeln('logging in ...');
  xmpp.Login;
  while FActive and not Terminated do
    begin
      sleep(1);
    end;
  writeln('exitting ...');
  //xmpp.Free;
  Speaker.Free;
  // stop program loop
  Terminate;
end;
function PrometXMPPMessanger.CheckUser(JID: string): Boolean;
var
  aCont: TPersonContactData;
  aUser: TUser;
begin
  if pos('/',JID)>0 then
    JID := copy(JID,0,pos('/',JID)-1);
  Result := FUsers.Values[JID]='True';
  if FUsers.Values[JID]='' then
    begin
      FUsers.Values[JID]:='False';
      aCont := TPersonContactData.Create(nil);
      aCont.Filter(Data.QuoteField('DATA')+'='+Data.QuoteValue(JID));
      if aCont.Count>0 then
        begin
          aUser := TUser.Create(nil);
          aUser.Filter(Data.QuoteField('CUSTOMERNO')+'='+Data.QuoteValue(aCont.FieldByName('ACCOUNTNO').AsString));
          if aUser.Count>0 then
            begin
              FUsers.Values[JID]:='True';
              Result := True;
            end;
          aUser.Free;
        end;
      aCont.Free;
    end;
end;
constructor PrometXMPPMessanger.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
  FUsers := TStringList.Create;
end;
destructor PrometXMPPMessanger.Destroy;
begin
  FUsers.Free;
  inherited Destroy;
end;
var
  Application: PrometXMPPMessanger;
begin
  Application:=PrometXMPPMessanger.Create(nil);
  Application.Run;
  Application.Free;
end.
