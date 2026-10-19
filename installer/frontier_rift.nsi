; Per-user Frontier Rift installer. No admin. Windowed exe only.
; CI builds this twice. The first pass writes the uninstaller, CI hashes it,
; and the second pass ships that hash as uninstall.sha256. Nothing here
; starts a shell while the installer is running.

Unicode True
RequestExecutionLevel user

!include "MUI2.nsh"
!include "FileFunc.nsh"

Name "Frontier Rift"
OutFile "..\build\installer\FrontierRift-Setup.exe"
InstallDir "$LOCALAPPDATA\Frontier Rift"
InstallDirRegKey HKCU "Software\Frontier Rift" "InstallDir"

!define PRODUCT_VERSION "0.1.0.0"
VIProductVersion "${PRODUCT_VERSION}"
VIFileVersion "${PRODUCT_VERSION}"
VIAddVersionKey "ProductName" "Frontier Rift"
VIAddVersionKey "FileDescription" "Frontier Rift"
VIAddVersionKey "CompanyName" "alsatplaza-commits"
VIAddVersionKey "LegalCopyright" "(c) 2026 Frontier Rift"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "InternalName" "FrontierRift"
VIAddVersionKey "OriginalFilename" "FrontierRift-Setup.exe"
VIAddVersionKey "LegalTrademarks" "Frontier Rift"
VIAddVersionKey "Comments" "Frontier Rift"

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Turkish"

; Compile-time only. makensis runs this with the script directory as cwd.
; %1 is the uninstaller NSIS just produced.
!uninstfinalize 'mkdir -p "../build/installer" && cp "%1" "../build/installer/unins000-prebuilt.exe"'

Section "Kurulum"
  SetOutPath "$INSTDIR"
  ; Ship only the windowed executable. Never add a *.console.exe.
  File "..\build\windows\FrontierRift.exe"
  WriteUninstaller "$INSTDIR\unins000.exe"
  !ifdef EMBED_HASH
    File "/oname=uninstall.sha256" "..\build\installer\uninstall.sha256"
  !endif

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
