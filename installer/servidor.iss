; Instalador do servidor do New Craft (Inno Setup 6).
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
; NewCraftServer.exe abre o painel (criar mundo, ligar, desligar); o .console.exe roda sem janela mostrando o registro.
Source: "..\build\NewCraftServer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\NewCraftServer.console.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\Servidor.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Servidor New Craft"; Filename: "{app}\NewCraftServer.exe"; WorkingDir: "{app}"; Comment: "Painel do servidor: criar mundo, ligar e desligar"
Name: "{group}\Servidor New Craft (sem janela, porta 7777)"; Filename: "{app}\NewCraftServer.console.exe"; Parameters: "--headless --port=7777"; WorkingDir: "{app}"; \
	IconFilename: "{app}\NewCraftServer.exe"; Comment: "Liga o último mundo do servidor sem janela (Ctrl+C para parar)"
Name: "{group}\Pasta do servidor"; Filename: "{app}"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Servidor New Craft"; Filename: "{app}\NewCraftServer.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\NewCraftServer.exe"; Description: "Abrir o painel do servidor agora"; Flags: nowait postinstall skipifsilent

[Messages]
ptbr.FinishedLabel=O servidor do New Craft foi instalado.%n%nAbra o atalho "Servidor New Craft": crie um mundo, escolha a porta e clique em "Ligar mundo". Sem janela: Servidor.bat [porta] [id-do-mundo] na pasta do servidor.%n%nNa primeira vez, o Windows pode perguntar se libera o servidor no Firewall: permita para outros jogadores conectarem. Para jogar pela internet, abra a porta (UDP) no roteador.%n%nOs mundos do servidor ficam em %%APPDATA%%\Godot\app_userdata\New Craft\servidor_mundos e não são apagados ao desinstalar.
