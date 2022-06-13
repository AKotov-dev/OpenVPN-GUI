unit PingTRD;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, Controls, SysUtils, Process, Graphics;

type
  CheckPing = class(TThread)
  private

    { Private declarations }
  protected
  var
    PingStr: TStringList;

    procedure Execute; override;
    procedure ShowStatus;

  end;

//Флаг Ping-а (True/False) - публичный
var
  Ping: boolean;

implementation

uses unit1;

{ TRD }

procedure CheckPing.Execute;
var
  PingProcess: TProcess;
begin
  FreeOnTerminate := True; //Уничтожать по завершении

  while not Terminated do
    try
      PingStr := TStringList.Create;
      PingProcess := TProcess.Create(nil);

      PingProcess.Executable := 'bash';
      PingProcess.Parameters.Add('-c');
      PingProcess.Options := PingProcess.Options + [poUsePipes, poWaitOnExit];

      PingProcess.Parameters.Add(
        '[[ $(fping google.com) && $(ip -br a | grep tun[[:digit:]]) ]] && echo "yes" || echo "no"');
      PingProcess.Execute;

      PingStr.LoadFromStream(PingProcess.Output);
      Synchronize(@ShowStatus);

      Sleep(1000);
    finally
      PingStr.Free;
      PingProcess.Free;
    end;
end;

procedure CheckPing.ShowStatus;
begin
  if Trim(PingStr[0]) = 'yes' then
  begin
    MainForm.Shape1.Brush.Color := clLime;
    MainForm.Panel4.Enabled := False;
  end
  else
  begin
    MainForm.Shape1.Brush.Color := clYellow;
    MainForm.Panel4.Enabled := True;
  end;
  MainForm.Shape1.Repaint;
end;

end.
