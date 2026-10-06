; Per-user Frontier Rift installer. No admin. Windowed exe only.
; The uninstaller is always named unins000.exe and its SHA-256 is recorded beside it.

Unicode True
RequestExecutionLevel user

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

Name "Frontier Rift"
OutFile "build/installer/FrontierRift-Setup.exe"
InstallDir "$LOCALAPPDATA\Frontier Rift"
InstallDirRegKey HKCU "Software\Frontier Rift" "InstallDir"

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Turkish"

Section "Kurulum"
  SetOutPath "$INSTDIR"
  ; Ship only the windowed executable. Never add a *.console.exe.
  File "build/windows/FrontierRift.exe"
  WriteUninstaller "$INSTDIR\unins000.exe"

  FileOpen $9 "$INSTDIR\_hash.ps1" w
  FileWrite $9 "$$h = (Get-FileHash -LiteralPath '$INSTDIR\unins000.exe' -Algorithm SHA256).Hash.ToLower()$\r$\n"
  FileWrite $9 "[System.IO.File]::WriteAllText('$INSTDIR\uninstall.sha256', $$h)$\r$\n"
  FileClose $9
  nsExec::ExecToLog 'powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$INSTDIR\_hash.ps1"'
  Pop $0
  Delete "$INSTDIR\_hash.ps1"
  ${If} $0 != 0
    Abort "Kaldırma özeti yazılamadı."
  ${EndIf}

  CreateShortcut "$DESKTOP\Frontier Rift.lnk" "$INSTDIR\FrontierRift.exe" "" "$INSTDIR\FrontierRift.exe" 0
  WriteRegStr HKCU "Software\Frontier Rift" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontierRift" "DisplayName" "Frontier Rift"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontierRift" "UninstallString" "$\"$INSTDIR\unins000.exe$\""
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontierRift" "DisplayIcon" "$INSTDIR\FrontierRift.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontierRift" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontierRift" "Publisher" "Frontier Rift"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontierRift" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontierRift" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontierRift" "EstimatedSize" "$0"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\FrontierRift.exe"
  Delete "$INSTDIR\uninstall.sha256"
  Delete "$DESKTOP\Frontier Rift.lnk"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\FrontierRift"
  DeleteRegKey HKCU "Software\Frontier Rift"
  Delete "$INSTDIR\unins000.exe"
  RMDir "$INSTDIR"
SectionEnd
