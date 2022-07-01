unit unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, FileCtrl,
  ExtCtrls, StdCtrls, Grids, IniPropStorage, Process, Buttons,
  LCLTranslator, DefaultTranslator;

type

  { TMainForm }

  TMainForm = class(TForm)
    AutoStartCheckBox: TCheckBox;
    ClearBox: TCheckBox;
    DeleteBtn: TButton;
    IniPropStorage1: TIniPropStorage;
    LoadBtn: TButton;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    Shape1: TShape;
    StaticText1: TStaticText;
    FileListBox1: TFileListBox;
    GroupBox2: TGroupBox;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    SelectAllBtn: TButton;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    Splitter3: TSplitter;
    StartBtn: TButton;
    StopBtn: TButton;
    StringGrid1: TStringGrid;
    Timer1: TTimer;
    procedure AutoStartCheckBoxChange(Sender: TObject);
    procedure ClearBoxChange(Sender: TObject);
    procedure FileListBox1Change(Sender: TObject);
    procedure IniPropStorage1RestoreProperties(Sender: TObject);
    procedure IniPropStorage1RestoringProperties(Sender: TObject);
    procedure IniPropStorage1SaveProperties(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure LoadBtnClick(Sender: TObject);
    procedure SelectAllBtnClick(Sender: TObject);

    procedure StopBtnClick(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Panel2Resize(Sender: TObject);
    procedure DeleteBtnClick(Sender: TObject);
    procedure ButtonsEnable;
    procedure CSVLoad;
    procedure StringGrid1EditingDone(Sender: TObject);
    procedure SaveLogin;
    procedure Timer1Timer(Sender: TObject);
    procedure StartProcess(command: string);
  private
    { private declarations }
  public


    { public declarations }
  end;

//Ресурсы перевода
resourcestring
  SAppRunning = 'The program is already running!';
  SDeleteConfiguration = 'Delete the selected configuration?';
  SLogin = 'Login:';
  SPassword = 'Password:';

var
  MainForm: TMainForm;

implementation

uses PingTRD;

{$R *.lfm}

{ TMainForm }

//Общая процедура запуска команд (асинхронная)
procedure TMainForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  Application.ProcessMessages;
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := '/bin/bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    //  ExProcess.Options := ExProcess.Options + [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
  end;
end;

//Проверка чекбокса AutoStart
function CheckAutoStart: boolean;
var
  S: ansistring;
begin
  RunCommand('/bin/bash', ['-c',
    '[[ -n $(systemctl is-enabled openvpngui | grep "enabled") ]] && echo "yes"'], S);

  if Trim(S) = 'yes' then
    Result := True
  else
    Result := False;
end;

//Проверка чекбокса ClearBox (очистка кеш/cookies)
function CheckClear: boolean;
begin
  if FileExists('/etc/openvpngui/clear-browser') then
    Result := True
  else
    Result := False;
end;

//Старт VPN-соединения
procedure TMainForm.StartBtnClick(Sender: TObject);
var
  i: integer;
  auth: boolean;
  S: TStringList;
begin
  //Если список конфигураций пуст - Выход (двойной клик на списке)
  if FileListBox1.Count = 0 then Exit;

  StopBtn.Click;

  try
    //Создаём файл логин/пароль
    S := TStringList.Create;

    //Конфигурация содержит инструкции аутентификации?
    S.LoadFromFile(FileListBox1.FileName);

    for i := 0 to S.Count - 1 do
    begin
      if Trim(S[i]) = 'auth-user-pass' then
      begin
        auth := True;
        break;
      end
      else
        auth := False;
    end;

    S.Clear;
    S.Add(Trim(StringGrid1.Cells[0, 1]));
    S.Add(Trim(StringGrid1.Cells[1, 1]));
    S.SaveToFile('/etc/openvpngui/openvpngui.pass');

    S.Clear;
    //Формируем /etc/systemd/system/protonvpn.service
    S.Add('[Unit]');

    S.Add('Description=OpenVPN-GUI Tunneling Application');
    S.Add('After=network-online.target');
    S.Add('Wants=network-online.target');
    S.Add('');

    S.Add('[Service]');
    S.Add('PrivateTmp=true');
    S.Add('Type=forking');
    S.Add('PIDFile=/run/openvpn/openvpngui.pid');
    S.Add('ExecStart=/usr/sbin/openvpn --daemon --writepid /run/openvpn/openvpngui.pid \');
    S.Add('--config "' + FileListBox1.FileName + '" --log /var/log/openvpngui.log \');

    S.Add('--script-security 2 --up /etc/openvpngui/update-resolv-conf \');
    S.Add('--down /etc/openvpngui/update-resolv-conf \');

    //Инструкция аутентификации?
    if auth then
    begin
      if ((Trim(StringGrid1.Cells[0, 1]) = '') or (Trim(StringGrid1.Cells[1, 1]) = ''))
      then
        S.Add('--mute-replay-warnings --auth-user-pass /etc/openvpngui/false.pass')
      else
        S.Add('--mute-replay-warnings --auth-user-pass /etc/openvpngui/openvpngui.pass');
    end
    else
      S.Add('--mute-replay-warnings');

    S.Add('');

    S.Add('[Install]');
    S.Add('WantedBy=multi-user.target');
    S.SaveToFile('/etc/systemd/system/openvpngui.service');

    //Запуск VPN-соединения (#persist-tun - освобождаем интерфейс в случае сбоя VPN)
    StartProcess('chmod 600 /etc/openvpngui/openvpngui.pass; systemctl stop openvpngui.service; '
      + 'sed -i ' + '''' + 's/^persist-tun*/#persist-tun/' + '''' +
      ' "' + FileListBox1.FileName +
      '"; systemctl daemon-reload; systemctl restart openvpngui.service');

  finally
    S.Free;
  end;
end;

//Сохраняем одноименный с конфигурацией файл с login/password (для выбора из списка)
procedure TMainForm.SaveLogin;
begin
  if (FileListBox1.SelCount <> 0) and (FileListBox1.Items.Count <> 0) then
    StringGrid1.SaveToCSVFile(FileListBox1.FileName + '.csv', ',', False, True);
end;

//Вывод лога
procedure TMainForm.Timer1Timer(Sender: TObject);
var
  LOG: TStringList;
begin
  LOG := TStringList.Create;
  try
    if FileExists('/var/log/openvpngui.log') then
    begin
      LOG.LoadFromFile('/var/log/openvpngui.log');
      if LOG.Text <> Memo1.Lines.Text then
      begin
        Memo1.Lines.Assign(LOG);
        //Промотать список вниз
        Memo1.SelStart := Length(Memo1.Text);
        Memo1.SelLength := 0;
      end;
    end;
  finally
    LOG.Free;
  end;
end;

//Сохраняем логины после редактирования/копирования
procedure TMainForm.StringGrid1EditingDone(Sender: TObject);
begin
  SaveLogin;
end;

//Начитываем файл-логин для конфигурации *.ovpn
procedure TMainForm.CSVLoad;
begin
  FileListBox1.Click;
  INIPropStorage1.WriteInteger('findex', FileListBox1.ItemIndex);

  if FileListBox1.SelCount <> 0 then
    if FileExists(GetEnvironmentVariable('HOME') + '/.OpenVPN-GUI/' +
      FileListBox1.Items.Strings[FileListBox1.ItemIndex] + '.csv') then
      StringGrid1.LoadFromCSVFile(FileListBox1.FileName + '.csv', ',', False, 0, True)
    else
      StringGrid1.Clean([gzNormal, gzFixedRows]);
end;

//Состояние кнопок
procedure TMainForm.ButtonsEnable;
begin
  if FileListBox1.Items.Count <> 0 then
  begin
    SelectAllBtn.Enabled := True;
    DeleteBtn.Enabled := True;
    Panel3.Enabled := True;
  end
  else
  begin
    SelectAllBtn.Enabled := False;
    DeleteBtn.Enabled := False;
    Panel3.Enabled := False;
    StringGrid1.Clean([gzNormal, gzFixedRows]);
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  FCheckPingThread: TThread;
begin
  IniPropStorage1.IniFileName :=
    GetEnvironmentVariable('HOME') + '/.OpenVPN-GUI/ConfigForm.ini';

  Caption := Application.Title;

  StringGrid1.Cells[0, 0] := SLogin;
  StringGrid1.Cells[1, 0] := SPassword;

  FileListBox1.Directory := GetEnvironmentVariable('HOME') + '/.OpenVPN-GUI';
  FileListBox1.UpdateFileList;

  //Получаем FileName показывая форму
  FileListBox1.ItemIndex := IniPropStorage1.ReadInteger('findex', -1);
  FileListBox1.Click;

  ButtonsEnable;

  //Поток проверки состояния
  FCheckPingThread := CheckPing.Create(False);
  FCheckPingThread.Priority := tpNormal;
end;

//Стоп соединения
procedure TMainForm.StopBtnClick(Sender: TObject);
begin
  Shape1.Brush.Color := clYellow;
  Shape1.Repaint;

  StartProcess('systemctl stop openvpngui.service');
end;

//Выделить всё
procedure TMainForm.SelectAllBtnClick(Sender: TObject);
begin
  FileListBox1.SelectAll;
end;

//Загрузка конфигураций
procedure TMainForm.LoadBtnClick(Sender: TObject);
var
  i: integer;
  NameWithoutSpaces: string;
begin
  SaveLogin;
  NameWithoutSpaces := '';

  if OpenDialog1.Execute then
  begin
    for i := 0 to OpenDialog1.Files.Count - 1 do
    begin
      NameWithoutSpaces := StringReplace(ExtractFileName(OpenDialog1.Files.Strings[i]),
        ' ', '_', [rfReplaceAll, rfIgnoreCase]);

      //Если файлы с одинаковыми именами, уничтожаем логин-файл
      if FileExists(GetEnvironmentVariable('HOME') + '/.OpenVPN-GUI/' +
        NameWithoutSpaces) then
        DeleteFile(GetEnvironmentVariable('HOME') + '/.OpenVPN-GUI/' +
          NameWithoutSpaces + '.csv');

      //Копируем новые конфигурации с заменой
      CopyFile(OpenDialog1.Files.Strings[i],
        GetEnvironmentVariable('HOME') + '/.OpenVPN-GUI/' +
        NameWithoutSpaces, False);
    end;

    //Апдейт содержимого списка
    with FileListBox1 do
    begin
      UpdateFileList;
      if OpenDialog1.Files.Count = 1 then
        ItemIndex := Items.IndexOf(NameWithoutSpaces)
      else
        ItemIndex := 0;
      SetFocus;
      Click;
    end;

    //Состояние кнопок
    ButtonsEnable;

    //Запоминаем индекс
    INIPropStorage1.WriteInteger('findex', FileListBox1.ItemIndex);
  end;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  //Сохраняем логины перед закрытием
  SaveLogin;
  //Масштабирование для Plasma
  IniPropStorage1.Save;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  //Масштабирование для Plasma
  IniPropStorage1.Restore;

  AutoStartCheckBox.Checked := CheckAutoStart;
  ClearBox.Checked := CheckClear;
  CSVLoad;
end;

//Восстанавливаем курсор списка
procedure TMainForm.IniPropStorage1RestoringProperties(Sender: TObject);
begin
  FileListBox1.ItemIndex := IniPropStorage1.ReadInteger('findex', -1);
end;

//Сохраняем курсор списка
procedure TMainForm.IniPropStorage1SaveProperties(Sender: TObject);
begin
  INIPropStorage1.WriteInteger('findex', FileListBox1.ItemIndex);
end;

procedure TMainForm.FileListBox1Change(Sender: TObject);
begin
  CSVLoad;
end;

//Автозапуск
procedure TMainForm.AutoStartCheckBoxChange(Sender: TObject);
var
  S: ansistring;
begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  if AutoStartCheckBox.Checked then
    RunCommand('/bin/bash', ['-c', 'systemctl enable openvpngui'], S)
  else
    RunCommand('/bin/bash', ['-c', 'systemctl disable openvpngui'], S);

  AutoStartCheckBox.Checked := CheckAutoStart;
  Screen.Cursor := crDefault;
end;

//Чекбокс очистки кешей и кукисов установленных браузеров
procedure TMainForm.ClearBoxChange(Sender: TObject);
var
  S: ansistring;
begin
  if not ClearBox.Checked then
    RunCommand('/bin/bash', ['-c', 'rm -f /etc/openvpngui/clear-browser'], S)
  else
    RunCommand('/bin/bash', ['-c', 'touch /etc/openvpngui/clear-browser'], S);
end;

procedure TMainForm.IniPropStorage1RestoreProperties(Sender: TObject);
begin
  FileListBox1.ItemIndex := IniPropStorage1.ReadInteger('findex', -1);
end;

//Автоширина Login/Password
procedure TMainForm.Panel2Resize(Sender: TObject);
begin
  StringGrid1.ColWidths[0] := StringGrid1.Width div 2 - 1;
  StringGrid1.ColWidths[1] := StringGrid1.ColWidths[0];
end;

//Удаление выбранных конфигураций
procedure TMainForm.DeleteBtnClick(Sender: TObject);
var
  i: integer;
begin
  if MessageDlg(SDeleteConfiguration, mtConfirmation, [mbYes, mbNo], 0) = mrYes then

    //Удаление конфигураций + логин-файлы.csv
  begin
    with FileListBox1 do
    begin
      for i := -1 + Items.Count downto 0 do
        if Selected[i] then
        begin
          //Ессли файл конфигурации используется, оставляем его в списке до останова
          if FileListBox1.Items.Strings[i] <> Memo1.Hint then
          begin
            DeleteFile(GetEnvironmentVariable('HOME') + '/.OpenVPN-GUI/' +
              FileListBox1.Items.Strings[i]);
            DeleteFile(GetEnvironmentVariable('HOME') + '/.OpenVPN-GUI/' +
              FileListBox1.Items.Strings[i] + '.csv');
          end;
        end;
    end;

    FileListBox1.UpdateFileList;
    ButtonsEnable;

    if FileListBox1.Count > 0 then
    begin
      FileListBox1.ItemIndex := 0;
      CSVLoad;
    end;

  end;

  //Запоминаем позицию курсора
  INIPropStorage1.StoredValue['findex'] := IntToStr(FileListBox1.ItemIndex);
end;

end.
