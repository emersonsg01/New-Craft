; Instalador do servidor dedicado do New Craft (Inno Setup 6).
; Gera: build\Instalador do Servidor\NewCraftServer-Setup.exe
; Antes, exporte o servidor para build\NewCraftServer.exe (perfil "Servidor dedicado (Windows)").

#define AppName "New Craft - Servidor"
#define AppVersion "1.0.0"

[Setup]
AppId={{C28171FB-F5FD-4810-B08D-3B460ED4E8EE}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=New Craft
DefaultDirName={autopf}\New Craft Servidor
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\Instalador do Servidor
OutputBaseFilename=NewCraftServer-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\NewCraftServer.exe
UninstallDisplayName={#AppName}

[Languages]
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"

[Files]
; Os dois executaveis precisam ficar juntos: o .console.exe abre o servidor mostrando o registro.
Source: "..\build\NewCraftServer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\NewCraftServer.console.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\Servidor.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Iniciar servidor New Craft"; Filename: "{app}\NewCraftServer.console.exe"; Parameters: "--port=7777"; WorkingDir: "{app}"; \
	IconFilename: "{app}\NewCraftServer.exe"; Comment: "Servidor dedicado na porta 7777 (feche a janela ou Ctrl+C para parar)"
Name: "{group}\Pasta do servidor"; Filename: "{app}"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Servidor New Craft"; Filename: "{app}\NewCraftServer.console.exe"; Parameters: "--port=7777"; WorkingDir: "{app}"; \
	IconFilename: "{app}\NewCraftServer.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\NewCraftServer.console.exe"; Parameters: "--port=7777"; Description: "Iniciar o servidor agora"; Flags: nowait postinstall skipifsilent unchecked

[Messages]
ptbr.FinishedLabel=O servidor do New Craft foi instalado.%n%nUse o atalho "Iniciar servidor New Craft" (porta 7777). Para outra porta ou semente: Servidor.bat [porta] [semente] na pasta do servidor.%n%nNa primeira vez, o Windows pode perguntar se libera o servidor no Firewall: permita para outros jogadores conectarem. Para jogar pela internet, abra a porta 7777 (UDP) no roteador.%n%nO mundo do servidor fica em %%APPDATA%%\Godot\app_userdata\New Craft\servidor.save e não é apagado ao desinstalar.
