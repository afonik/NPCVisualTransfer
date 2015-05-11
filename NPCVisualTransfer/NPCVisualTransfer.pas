{
  NPC Visual Transfer

  Allows to replace the visuals, and just the visuals of one NPC to Another
}
unit NPCVisualTransfer;
uses mteFunctions;
const
  MinElementsToModify = 'RNAM,WNAM,ANAM,"Head Parts",HCLF,NAM6,NAM7,QNAM,"Tint Layers",OBND,NAM9,NAMA,FTST,ANAM,DOFT';
  copyGRUPS = 'TXTS,';
  bethESMs = 'skyrim.esm'#13'dawnguard.esm'#13'dragonborn.esm'#13'hearthfires.esm'#13'update.esm';
  bethBSAs = 'skyrim - animations.bsa'#13'skyrim - meshes.bsa'#13'Skyrim - textures.bsa'#13'skyrim - misc.bsa'#13'dawnguard.bsa'#13'dragonborn.bsa'#13'hearthfires.bsa'#13'update.bsa';
  lMeshPath = 'meshes\actors\character\facegendata\facegeom\';
  lTexPath = 'textures\actors\character\facegendata\facetint\';
  moDataFolder = 'VNPC_Data';
  ScriptName = 'Visual Transfer Tool';
var 
  sourceNPCIDs, destNPCIDs: TStringList;
  SourceNPC, DestNPC, PatchFile, DestFL: IInterface;
  slResList,slElementToXFer,slCurrentNPCs, slAssetPaths, slCurrPass, slNextPass: TStringList;
  slAssets: TwbFastStringList;
  bTrue, bFalse, bQuit, bUsingMO, bCreatingModFolders, bAdvancedTransfer, bFirstTime, bDebug: Boolean;
  //NPC Specific Bools
  bCustomRace, bHasWNAM, bHasUDOFT, bHasUSOFT: boolean;
  moPath,xferPath, sSourceNPCName, sDestNPCName: String;
  slContainers: TwbFastStringList;


function GrabWinningRecordFromSelection(input: String): IInterface;
var
  i: Integer;
  sHexID: String;
  iiMasterRecord: IInterface;
begin
 // if Length(input) < 8 then exit;
  sHexID := CopyFromTo(input, Length(input)-7, Length(input));
  AddMessage(sHexID);
  iiMasterRecord := RecordByHex(sHexID);
  if not Assigned(iiMasterRecord) then exit;
  if OverrideCount(iiMasterRecord) > 0 then begin
    Result := WinningOverride(MasterOrSelf(iiMasterRecord));
  end else
    Result := MasterOrSelf(iiMasterRecord);
end;

procedure ChangeFlag(i:integer; sSourceFlags:string; var sDestFlags:string);
var
  c: char;
begin
  AddMessage('Source: '+ sSourceFlags[i]+ ' Dest: '+ sDestFlags[i]);
  if (sSourceFlags[i] <> sDestFlags[i]) then begin
    if sDestFlags[i] = '0' then c := '1' else c := '0';
    SetChar(sDestFlags, i, c);
  end;
end;


function AdditionalOptions(): integer;
var
  i: Integer;
  frm: TForm;
  sSourceFlags,sDestFlags : String;
  c: char;
begin
  sSourceFlags := geev(SourceNPC, 'ACBS\Flags');
  sDestFlags := geev(DestNPC, 'ACBS\Flags');
  while Length(sSourceFlags) < 32 do
    sSourceFlags := sSourceFlags + '0';
  while Length(sDestFlags) < 32 do
    sDestFlags := sDestFlags + '0';

  AddMessage(sDestFlags);
  //Gender Index: 1
  ChangeFlag(1,sSourceFlags,sDestFlags);
  //Opposite Animation Index: 20 
  ChangeFlag(20,sSourceFlags,sDestFlags);
  seev(DestNPC,'ACBS\Flags', sDestFlags);


end;

procedure GrabActorsFromFile(iiFile: IInterface);
var
  j: Integer;
  npcGRUP, indexRecord: IInterface;
  npcName: String;
begin
  slCurrentNPCs.Clear;
  npcGRUP := GroupBySignature(iiFile, 'NPC_');
  if Assigned(npcGRUP) then begin
    for j := 0 to Pred(ElementCount(npcGRUP)) do begin
      indexRecord := ElementByIndex(npcGRUP, j);
      npcName := geev(indexRecord, 'FULL');
      if npcName = '' then
      npcName := '_'+geev(indexRecord, 'EDID');
      npcName := IntToStr(j)+' '+npcName + ' : ' + HexFormID(indexRecord);
      slCurrentNPCs.Append(npcName);
    end;
  end else
  slCurrentNPCs.Append(' ');
end;

procedure RemoveNPC(iiNPC: IInterface);
var
  dHex, dFileName: string;
begin
  if Assigned(iiNPC) then begin
    dHex := '00'+ CopyFromTo(HexFormID(iiNPC),3,8);
    dFileName := GetFileName(GetFile(MasterOrSelf(iiNPC)));
    DeleteFile(xferPath+moDataFolder+'\'+lMeshPath+dFileName+'\'+dHex+'.nif');
    DeleteFile(xferPath+moDataFolder+'\'+lTexPath+dFileName+'\'+dHex+'.dds');
    AddMessage('-Removing NPC');
    Remove(iiNPC);
  end else AddMessage('-Nothing To Remove');
end;

function ActorSelect(grup,prompt,prompt2: string; tsSourceList,tsDestList: TStringList; var iiSourceNPC:IInterface; var iiDestNPC: IInterface): integer;
var
  frm: TForm;
  lbl, lbl2: TLabel;
  lbActors: TListBox;
  lbActors2: TListBox;
  btnOk, btnCancel, btnRemoveNPC: TButton;
  cbActors: TComboBox;
  i,modals: integer;
  s, input1,input2: string;
begin
  Debug('Inside ActorSelect');
  frm := TForm.Create(nil);
  GrabActorsFromFile(PatchFile);
  try
    frm.Caption := 'Select '+ grup;
    frm.Width := 556;
    frm.Height := 480;
    frm.Position := poScreenCenter;
    
    lbl := TLabel.Create(frm);
    lbl.Parent := frm;
    lbl.Width := 200;
    if Pos(#13, prompt) > 0 then begin
      lbl.Height := 60;
    end
    else begin
      lbl.Height := 30;
      frm.Height := 160;
    end;
    lbl.Left := 10;
    lbl.Top := 8;
    lbl.Caption := prompt;
    lbl.Autosize := false;
    lbl.Wordwrap := True;
    
    lbActors := TListBox.Create(frm);
    lbActors.Parent := frm;
    lbActors.Top := lbl.Top + lbl.Height + 6;
    lbActors.Left := 10;
    lbActors.Width := 230;
    lbActors.Height := 300;

    lbActors2 := TListBox.Create(frm);
    lbActors2.Parent := frm;
    lbActors2.Top := lbActors.Top;
    lbActors2.Left := lbActors.Left+lbActors.Width + 60;
    lbActors2.Width := 230;
    lbActors2.Height := lbActors.Height;

    lbl2 := TLabel.Create(frm);
    lbl2.Parent := frm;
    lbl2.Height := lbl.Height;
    lbl2.Left := lbActors2.Left;
    lbl2.Width := 200;
    lbl2.Top := 8;
    lbl2.Caption := prompt2;
    lbl2.Autosize := false;
    lbl2.Wordwrap := True;

    lbActors.Items.Add(' ');
    lbActors2.Items.Add(' ');
    for i := 0 to tsSourceList.Count-1 do begin
      lbActors.Items.Add(tsSourceList[i]);
    end;
    for i := 0 to tsDestList.Count-1 do begin
      lbActors2.Items.Add(tsDestList[i]);
    end;
    
    btnOk := TButton.Create(frm);
    btnOk.Parent := frm;
    btnOk.Left := lbActors.Left + ((lbActors2.Left+lbActors2.Width-lbActors.Left)/2)-btnOk.Width-8;
    btnOk.Top := lbActors.Top + lbActors.Height + 10;
    btnOk.Caption := 'Transfer';
    btnOk.ModalResult := mrOk;
    
    btnCancel := TButton.Create(frm);
    btnCancel.Parent := frm;
    btnCancel.Caption := 'Quit';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Left := btnOk.Left + btnOk.Width + 16;
    btnCancel.Top := btnOk.Top;
    lbActors.ItemIndex := 0;
    lbActors2.ItemIndex := 0;

    cbActors := TComboBox.Create(frm);
    cbActors.Parent := frm;
    cbActors.Style := csDropDown;
    cbActors.Sorted := false;
    cbActors.AutoDropdown := True;
    cbActors.Left := lbActors.Left + lbActors.Width/2;
    cbActors.Width := lbActors.Width;
    cbActors.Top := btnOk.Top + btnOk.Height+16;
    cbActors.Text := 'NPC To Remove...';

    for i := 0 to slCurrentNPCs.Count-1 do begin
      cbActors.Items.Add(slCurrentNPCs[i]);
    end;
    
    btnRemoveNPC := TButton.Create(frm);
    btnRemoveNPC.Parent := frm;
    btnRemoveNPC.Caption := 'Remove Transfered NPC';
    btnRemoveNPC.Width := 150;
    btnRemoveNPC.Left := cbActors.Left + +cbActors.Width+10;
    btnRemoveNPC.Top := cbActors.Top;
    btnRemoveNPC.ModalResult := mrYes;

    modals := frm.ShowModal;
    if modals = mrOk then begin
      input1 := lbActors.Items[(lbActors.ItemIndex)];
      input2 := lbActors2.Items[(lbActors2.ItemIndex)];
      if (input1 = ' ') or (input2 = ' ') then Exit;
        iiSourceNPC := GrabWinningRecordFromSelection(input1);
        iiDestNPC := GrabWinningRecordFromSelection(input2);
      if Equals(GetFile(iiDestNPC), PatchFile) and (OverrideCount(iiDestNPC) > 0) then begin
        RemoveNPC(iiDestNPC);
        iiDestNPC := GrabWinningRecordFromSelection(input2);
      end;
      sSourceNPCName := geev(iiSourceNPC, 'FULL');
      if sSourceNPCName = '' then
        sSourceNPCName := geev(iiSourceNPC, 'EDID');
  
      sDestNPCName := geev(iiDestNPC, 'FULL');
      if sDestNPCName = '' then
        sDestNPCName := geev(iiDestNPC, 'EDID');

      AddRequiredElementMasters(iiDestNPC, PatchFile, false);
      AddRequiredElementMasters(iiSourceNPC, PatchFile, false);
      iiDestNPC := wbCopyElementToFile(iiDestNPC,PatchFile,false,true);
      end 
    else if modals = mrYes then begin
      input1 := cbActors.Text;
      if not (input1 = 'NPC To Remove...') then begin
        RemoveNPC(ElementByIndex(GroupBySignature(PatchFile,'NPC_'), StrToInt(input1[1])));
      end;
    end
    else begin
      AddMessage('== User Has Quit ==');
      bQuit := true;
    end;
  finally
    frm.Free;
  end;
end;

procedure MoveRenameFaceGen(sHex,sFile,dHex,dFile: String);
var
  tXferPath: String;
begin
  Debug('Inside MoveRenameFaceGen');
  tXferPath := xferPath+moDataFolder+'\';
  ForceDirectories(tXferPath+lMeshPath+dFile+'\');
  ForceDirectories(tXferPath+lTexPath+dFile+'\');

  wCopyFile(TempPath+lMeshPath+sFile+'\'+sHex+'.nif',tXferPath+lMeshPath+dFile+'\'+dHex+'.nif', true);
  wCopyFile(TempPath+lTexPath+sFile+'\'+sHex+'.dds',tXferPath+lTexPath+dFile+'\'+dHex+'.dds', true);
  wCopyFile(TempPath+lMeshPath+sFile+'\'+sHex+'.nif',tXferPath+lMeshPath+dFile+'\'+dHex+'.nif', false);
  wCopyFile(TempPath+lTexPath+sFile+'\'+sHex+'.dds',tXferPath+lTexPath+dFile+'\'+dHex+'.dds', false);
end;



procedure TransferFaceGenData();
var
  i: Integer;
  sourceLocalHexID, destLocalHexID, destFileName, sourceFilename: String;
  tempFile: IInterface;
begin
  AddMessage('Inside Of TransferFaceGenData');
  sourceLocalHexID := '00'+ CopyFromTo(HexFormID(SourceNPC), 3, 8);
  destLocalHexID := '00'+ CopyFromTo(HexFormID(DestNPC), 3, 8);
  tempFile := MasterOrSelf(DestNPC);
  destFileName := GetFileName(tempFile);
  tempFile := MasterOrSelf(SourceNPC);
  sourceFilename := GetFileName(tempFile);
  ExtractFaceGen(sourceNPC);
  MoveRenameFaceGen(sourceLocalHexID, sourceFilename, destLocalHexID, destFileName);
end;


procedure TransferElements();
var
  i: integer;
  path: string;
  iiDest, iiSource, elementToAdd: IInterface;
begin
  Debug('Inside TransferElements');
  iiDest := DestNPC;
  iiSource := SourceNPC;
  for i := 0 to Pred(slElementToXFer.Count) do begin
    RemoveSubElement(iiDest,slElementToXFer[i]);
  end;
  
  for i := 0 to Pred(slElementToXFer.Count) do begin
    CopySubElement(iiSource, iiDest,slElementToXFer[i]);
  end;
  
  AdditionalOptions();
end;

procedure RemoveSubElement(iiRecord: IInterface; elementName: String);
var
  elementToClean: IInterface;
begin
  Debug('Inside RemoveSubElement');
  elementToClean := ElementByIP(iiRecord, elementName);
  if Assigned(elementToClean) then begin
    AddMessage('Removed : '+elementName);
    Remove(elementToClean);
  end;
end;

procedure CopySubElement(iiS,iiD: IInterface; elementName: String);
var
  elementToCopy: IInterface;
begin
  Debug('Inside CopySubElement');
  elementToCopy := ElementByIP(iiS, elementName);
  if Assigned(elementToCopy) then begin
    if not CheckForErrors(0,elementToCopy) then begin
      AddMessage('Transfering : '+elementName);
      try
        AddRequiredElementMasters(elementToCopy,iiD, false);
        wbCopyElementToRecord(elementToCopy,iiD,false,true);
      except
        on E:Exception do AddMessage('Could Not Copy Record!');
      finally
      end;
    end;
  end;
end;

function ExtractFaceGen(iiNpc: IInterface): boolean;
var
  i: Integer;
  bFound: Boolean;
  oFName, mFName, ovShortName, mstrShortName, bsaToCheck, hexID, test: String;
  nifPath, nifFile, ddsPath,ddsFile: String;
  iiNPCMaster: IInterface;
begin
  Debug('Inside ExtractFaceGeom');
  bFound := false;
  oFName := GetFileName(GetFile(iiNPC));
  ovShortName := CopyFromTo(oFName, 1,Length(oFName)-4)+'.bsa';
  iiNPCMaster := MasterOrSelf(iiNPC);
  mFName := GetFileName(GetFile(iiNPCMaster));
  hexID := '00'+ CopyFromTo(HexFormID(iiNPC), 3, 8);

  nifPath := lMeshPath+mFName+'\';
  nifFile := hexID+'.nif';
  ddsPath := lTexPath+mFName+'\';
  ddsFile := hexID+'.dds';

  AddMessage('ExtractFaceGen To Temp:'+ TempPath);
  
  test := TryToCopy(nifPath,nifFile);
  AddMessage(test);
  test := TryToCopy(ddsPath,ddsFile);
  AddMessage(test);

 
end;

function TryToCopy(filePath, fileName: String): String;
var
  i: Integer;
  slRes: TStringList;
  fileString: String;
begin
  Debug('Inside TryToCopy');
  slRes := TStringList.Create;
  try
    ResourceCount(filePath+fileName, slRes);
    ForceDirectories(TempPath+filePath);
    for i := Pred(slRes.Count) downto 0 do begin
      if slContainers.IndexOf(slRes[i]) <> -1 then begin
        Result := slRes[i];  
        AddMessage(Result);
        Break;
      end;
    end;

    if (Result <> '') then ResourceCopy(Result, filePath+fileName, TempPath);
  except
    on E:Exception do begin
    slRes.Free;
    AddMessage('Could Not Copy!');
    end;
  finally
    slRes.Free;
  end; 
end;

procedure GrabActors();
var
  i,j: integer;
  npcName, npcRace, filename: string;
  npcGRUP, indexRecord: IInterface;
begin
  sourceNPCIDs := TStringList.Create;
  sourceNPCIDs.Duplicates := dupIgnore;
  sourceNPCIDs.Sorted := true;
  destNPCIDs := TStringList.Create;
  destNPCIDs.Duplicates := dupIgnore;
  destNPCIDs.Sorted := true;
  for i := 0 to FileCount - 1 do begin
  npcGRUP := GroupBySignature(FileByIndex(i), 'NPC_');
    if Assigned(npcGRUP) then begin
      for j := 0 to Pred(ElementCount(npcGRUP)) do begin
        indexRecord := ElementByIndex(npcGRUP,j);
        if geev(indexRecord, 'ACBS\Flags\Unique') = '' then continue;
        npcName := geev(indexRecord, 'FULL');
        if npcName = '' then
        npcName := '_'+geev(indexRecord, 'EDID');
        npcName := npcName + ' : ' + HexFormID(indexRecord);
        destNPCIDs.Append(npcName);
        indexRecord := MasterOrSelf(indexRecord);
        filename := Lowercase(GetFileName(GetFile(indexRecord)));
        //Checks to see if the actor originates from bethesdas esms - if so then skip.
        //if Pos(filename,bethESMs) > 0 then continue;
        //npcRace := geev(indexRecord,'RNAM');
        //if Pos('RACE:00',npcRace) > 0 then continue;
        sourceNPCIDs.Append(npcName);
      end;
    end;
  end;
end; 

// Moved over from mtefunction.pas with a fix due to a small error from a released version. 
function RecordByHex(id: string): IInterface;
var
  f: IInterface;
begin
  f := FileByLoadOrder(StrToInt('$' + Copy(id, 1, 2)));
  Result := RecordByFormID(f, StrToInt('$' + id), true);
end;


function SimpleName(aName: string): string;
begin
  Result := ExtractFileName(aName);
  if Result = '' then
    Result := 'Data';
end;

function CheckFileName(sFileName: string): boolean;
begin
  Result := false;
  if Pos('.esp.esp',Lowercase(sFileName)) > 0 then begin
    MessageDlg('ERROR: You''ve accidentally added a .esp when inputting your filename; resulting in the filename:'#13+sFileName+#13'Script Will Now Quit.'#13'When exiting please make sure to deselect '+sFileName+' So the file does not get created!',mtError, [mbOk], 0);
    bQuit := true;
    AddMessage('-Created Faulty Filename');
    Result := true;
  end;
end;

procedure GatherIniInfo();
var
  ini: TMemIniFile;
  cFilePath, fileNameString: string;
  moButton, moButton2, filenameOK: integer;
begin
  xferPath := '';
  bUsingMO := false;
  cFilePath := FileSearch('npcvt_Config.ini', DataPath);
  try
  //If Ini file isnt there - make it and set gv otherwise set gv from ini file
    if cFilePath = '' then begin
      bFirstTime := true;
      moButton := MessageDlg('Welcome To NPC Visual Transfer:'#13'Since this is the first time you are runnning this script lets do some setup:'#13#13'Do You Use Mod Organizer?',mtConfirmation, [mbYes, mbNo], 0);
      if moButton = mrYes then begin
        bUsingMO := true;
        moPath := SelectDirectory('Select The Folder Containing ModOrganizer.exe','',DataPath,'');
        if (moPath = '') then begin 
          AddMessage('== User Has Cancelled Directory Selection: Quitting ==');
          bQuit := true;
          Exit;
        end;
          xferPath := moPath;
          if not StrEndsWith(xferPath,'\mods\') then
          xferPath := xferPath + '\mods\';
      end else begin
        MessageDlg('ERROR:  Incompatible mod manager'#13#13'As of now, this script will only work for users who use mod organizer.'#13'For more information as to why, please visit the nexus modpage.', mtError, [mbOk], 0);
        AddMessage('-user does not have mod organizer');
        bQuit := true;
        Exit;
      end;
      PatchFile := FileByName('NPCVisualTransfer.esp');
      if not Assigned(PatchFile) then
      PatchFile := FileSelect('Please select/create the file which will'#13'house all of your NPC overrides.');
      if Assigned(PatchFile) then fileNameString := GetFileName(PatchFile)
      else begin
        AddMessage('-User Did Not Select Or Create A File: Quitting');
        bQuit := true;
        Exit;
      end;
      if CheckFileName(fileNameString) then Exit;
      ini := TMemIniFile.Create(DataPath+'npcvt_Config.ini');
      ini.WriteString('GENERAL', 'sMOPath', moPath);
      ini.WriteString('GENERAL', 'sXferPath', xferPath);
      ini.WriteString('GENERAL', 'sPatchFilename', fileNameString);
      ini.WriteBool('GENERAL', 'bUsingMO',bUsingMO);
      ini.UpdateFile;
      MessageDlg('Configuration Complete.'#13'An ini File has been created in your overwrite folder named npcvt_Config.ini. Either keep it in the overwrite folder or move it into your NPCVisualTransfer modfolder.'#13'I have also made a new modfolder called '+moDataFolder+'. This is where the modified npc''s head texture/mesh will be saved.  Please do not modify, rename, or merge that folder in any way or this script will assume you are starting from scratch again!',mtInformation, [mbOk], 0);
    end 
    else begin
      ini := TMemIniFile.Create(DataPath+'npcvt_Config.ini');
      moPath := ini.ReadString('GENERAL', 'sMOPath', '');
      xferPath := ini.ReadString('GENERAL','sXferPath',DataPath);
      bUsingMO := ini.ReadBool('GENERAL','bUsingMO', false);
      fileNameString := ini.ReadString('GENERAL','sPatchFilename','NONE');
      PatchFile := FileByName(fileNameString);
      if not Assigned(PatchFile) then begin
        PatchFile := FileByName(Lowercase(fileNameString));
          if not Assigned(PatchFile) then 
          PatchFile := FileSelect(fileNameString+' is not loaded into TES5Edit.'#13'Select/Create a different file to use or cancel to quit');
          if not Assigned(PatchFile) then begin
            AddMessage('-User Did Not Select Or Create A File: Quitting');
            bQuit := true;
            Exit;
          end 
          else begin
            fileNameString := GetFileName(PatchFile);
            if CheckFileName(fileNameString) then Exit;
            ini.WriteString('GENERAL','sPatchFilename',fileNameString);
            ini.UpdateFile;
          end;
      end;
      if IsDataFolderLoaded(moPath) then begin
        MessageDlg('VNPC ERROR: '+moDataFolder+' is active in mod organizer.'#13#13'Please deactivate '+moDataFolder+' in mod organizer then run this script again.',mtError, [mbOk], 0);
        AddMessage(moDataFolder+' is still active in mod organizer.  Please deactivate that folder and run the patch again');
        bQuit := true;
        Exit;
      end;
      moButton := MessageDlg('NPC Visual Transfer Reminder: '#13#13'1: Is '+moDataFolder+' below all NPC-related ModFolders?'#13#13'2: Is '+GetFileName(PatchFile)+' below all NPC-related mods in your loadorder?', mtConfirmation, [mbYes, mbNo], 0);
      if not(moButton = mrYes) then begin
        MessageDlg('Please check that now, otherwise some transfers will not work. Script will now exit.', mtError, [mbOk], 0);
        AddMessage('-Did not setup correctly');
        bQuit := true;
        Exit;
      end;
    end;
  finally
    if Assigned(ini) then ini.Free;
  end;
end;

function IsDataFolderLoaded(mPath: string): boolean;
var
  moINI: TMemIniFile;
  selectedProfile: string;
  profile: TStringList;
  i: integer;
begin
  Result := false;
  moINI := TMemIniFile.Create(mPath+'\ModOrganizer.ini');
  selectedProfile := moINI.ReadString('General','selected_profile','');
  moINI.free;
  if (selectedProfile <> '') then begin
    profile := TStringList.Create;
    profile.LoadFromFile(moPath+'\profiles\'+selectedProfile+'\modlist.txt');
    for i := 0 to Pred(profile.Count) do begin
      if Pos(('+'+moDataFolder),profile[i]) > 0 then Result := true;
    end;
    profile.free;
  end;
end;

function CreateTransferFormList(ovNPC: IInterface): IInterface;
var 
  fl, flo: IInterface;
begin
  Debug('Inside CreateTrasnferFormList');
  fl := RecordByFormID(FileByIndex(0),101404,false);
  flo := wbCopyElementToFile(fl,GetFile(ovNPC),true,true);
  seev(flo, 'EDID', GetFileName(GetFile(ovNPC)));
  Add(flo,'FormIDs',false);
  Result := flo;
end;



function Initialize: integer;
var 
  i: integer;
begin
  bDebug := true;
  bTrue := true;
  bFalse := false;
  bQuit := false;
  bFirstTime := false;
  for i := 0 to 60 do AddMessage('');
  AddMessage('== NPC Visual Transfer ==');
  AddMessage('== Checking TES5Edit Version ==');
  if (wbVersionNumber < 50397184) or (wbAppName <> 'TES5') then begin
    EditOutOfDateLocal('3.1.0', 'http://www.nexusmods.com/skyrim/mods/25859/');
    Result := -1;
    Exit;
  end;
  AddMessage('-'+ GetVersionStringLocal(wbVersionNumber));
  AddMessage('-Version: OK!');
  AddMessage('== Gathering Ini Data ==');
  GatherIniInfo();
  if bQuit then begin
   Result := -1;
   Exit;
  end;
end;

function IsReferencing(elementToCheck, referenceToCheck: IInterface): boolean;
var
  refCount: integer;
  indexRef: IInterface;
begin
  Result := false;
  refCount := ReferenceByCount(elementToCheck);
  for i := 0 to Pred(refCount) do begin
    indexRef := ReferenceByIndex(elementToCheck, i);
    if Equals(indexRef, referenceToCheck) then begin
      Result := true;
      Exit;
    end;
  end;
end;

function CopyRefElementsByGRUP(GrupToCheck: string, referenceToCheck: IInterface);
var 
  i, iGrupSize: integer;
  iGRUP, iIndexElement: IInterface;
begin
  iGRUP := GroupBySignature(GetFile(referenceToCheck),GrupToCheck);
  iGrupSize := ElementCount(iGRUP);
  for i := 0 to Pred(iGrupSize) do begin
    iIndexElement := ElementByIndex(iGRUP, i);
    if IsReferencing(iIndexElement, referenceToCheck) then begin
      CopyAndAdd(iIndexElement,PatchFile,slNextPass);
    end;
  end;
end;

function Finalize: integer;
begin
  try
    AddMessage('== Gathering NPC Information ==');
    AddMessage('-This will take a bit of time');
    InitAllGlobals();
    GrabActors();
    if bQuit then begin
     Result := -1;
     Exit;
    end;
    while bQuit = false do begin
      ResetGlobals();
      ActorSelect('NPC','Select the standalone NPC whose visuals'#13'you wish to use','Select the NPC who will receive'#13'the new visuals', sourceNPCIDs,destNPCIDs, sourceNPC, destNPC);
      if bQuit then continue;
      if Assigned(SourceNPC) and Assigned(DestNPC) then begin
          DestFL := CreateTransferFormList(DestNPC);
          CheckElement(SourceNPC, 'Head Parts');
          TransferElements();
          TransferFaceGenData();
      end;
      if not(Assigned(SourceNPC)) and not(Assigned(DestNPC)) then AddMessage('Nothing Selected');
    end;
  //except
  //  on E: Exception do FreeGlobalLists();
  finally
    FreeGlobalLists();
    CleanMasters(PatchFile);
    SortMasters(PatchFile);
  end;
  //if not Assigned(SourceNPC) then Result := -1;
  if bFirstTime then
  MessageDlg('As this is your first time running this program, I have gone ahead and created a new modfolder called '+moDataFolder+'.  After hitting the refresh button in Mod Organizer this will appear in the left pane at the very bottom.  You will need to activate this folder in order for the approprate head mesh/textures to work.'#13#13'Note: Please do not RENAME or MERGE this modfolder unless you are completely uninstalling '+ScriptName,mtInformation, [mbOk], 0)
  else
  MessageDlg('All NPC FaceGenData has been saved to the '+moDataFolder+' modfolder.  Remember to REACTIVATE that folder or the changes will not take effect!',mtInformation, [mbOk], 0);
end;

procedure InitAllGlobals();
begin
  slContainers := TwbFastStringList.Create;
  slCurrentNPCs := TStringList.Create;
  ResourceContainerList(slContainers);
  slElementToXFer := TStringList.Create;
  slElementToXFer.DelimitedText := MinElementsToModify;
  slAssetPaths := TStringList.Create;
  ResetGlobals();
end;

procedure ResetGlobals();
begin
  bCustomRace := false; bHasWNAM := false; bHasUDOFT := false; bHasUSOFT := false;
  AddMessage(BoolToSrt(bCustomRace));
  SourceNPC := nil;
  DestNPC := nil;

end;

procedure FreeGlobalLists();
begin
  if Assigned(sourceNPCIDs) then sourceNPCIDs.Free;
  if Assigned(destNPCIDs) then destNPCIDs.Free;
  if Assigned(slResList) then slResList.Free;
  if Assigned(slContainers) then slContainers.Free;
  if Assigned(slElementToXFer) then slElementToXFer.Free;
  if Assigned(slCurrentNPCs) then slCurrentNPCs.Free;
  if Assigned(slAssetPaths) then slAssetPaths.Free;
end;


//Ported over from mtefunctions.pas and modified so it does not raise errors with 3.1
function GetVersionStringLocal(v: integer): string;
begin
  Result := Format('%sEdit version %d.%d.%d', [
    wbAppName,
    Int(v) shr 24,
    Int(v) shr 16 and $FF,
    Int(v) shr 8 and $FF
  ]);
end;
//Ported over from mtefunctions.pas and modified so it does not raise errors with 3.1
procedure EditOutOfDateLocal(minimumVersion: String; url: string);
var
  frm: TForm;
  lbl: TLabel;
  btnOk, btnCancel: TButton;
  v: integer;
  s: string;
begin
  frm := TForm.Create(nil);
  try
    frm.Caption := 'xEdit out of Date!';
    frm.Width := 300;
    frm.Height := 150;
    frm.Position := poScreenCenter;
    try
      s := GetVersionStringLocal(wbVersionNumber);
    except on Exception do
      s := wbAppName + 'Edit 3.0.31 or earlier';
    end;
    lbl := TLabel.Create(frm);
    lbl.Parent := frm;
    lbl.Top := 8;
    lbl.Left := 8;
    lbl.WordWrap := True;
    lbl.Width := 270;
    lbl.Caption := 
      'You''re using '+s+', but this script requires TES5Edit '+minimumVersion+' or newer.  '
      'Click the Update button to be directed to get the latest version.';
    AddMessage('You''re using '+s+', but this script requires '+wbAppName+'Edit '+minimumVersion+' or newer.');
    AddMessage('You can get the latest version at '+url);
    
    btnOk := TButton.Create(frm);
    btnOk.Parent := frm;
    btnOk.Top := lbl.Top + lbl.Height + 16;
    btnOk.Left := 40;
    btnOk.Caption := 'Update';
    btnOk.ModalResult := mrOk;
    btnOk.Hint := 'Click to open '+url+' in '#13#10+
    'your internet browser so you can download the latest xEdit beta version.';
    btnOk.ShowHint := true;
    
    btnCancel := TButton.Create(frm);
    btnCancel.Parent := frm;
    btnCancel.Top := btnOk.Top;
    btnCancel.Left := btnOk.Left + btnOk.Width + 20;
    btnCancel.Caption := 'Cancel';
    btnCancel.ModalResult := mrCancel;
    
    frm.Height := btnOk.Top + btnOk.Height + 50;
    
    if frm.ShowModal = mrOk then begin
      ShellExecute(TForm(frm).Handle, 'open', 
        url, '', '', SW_SHOWNORMAL);
    end;
  finally 
    frm.Free;
  end;
end;
//TAKEN FROM CHECK FOR ERRORS.PAS - REMOVED MESSAGES AS THEY DO NOT NEED IT
function CheckForErrors(aIndent: Integer; aElement: IInterface): Boolean;
var
  Error : string;
  i     : Integer;
begin
  Error := Check(aElement);
  Result := Error <> '';
  if Result then begin
    Error := Check(aElement);
    AddMessage(StringOfChar(' ', aIndent * 2) + Name(aElement) + ' -> ' + Error);
  end;

  for i := ElementCount(aElement) - 1 downto 0 do
    Result := CheckForErrors(aIndent + 1, ElementByIndex(aElement, i)) or Result;
end;



procedure Debug(s: string);
begin
  if bDebug then AddMessage('DEBUG:  '+s);
end;

end.
