; Instalador do jogo New Craft (Inno Setup 6).
; Gera: build\Instalador do Jogo\NewCraft-Setup.exe
; Antes, exporte o jogo para build\NewCraft.exe (perfil "Jogo (Windows)").

#define AppName "New Craft"
#define AppVersion "1.0.0"

[Setup]
AppId={{E65AE1FD-92AF-43EF-8D8C-DF72F8B828B6}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=New Craft
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Instala sem pedir administrador (na pasta do usuario); quem quiser pode escolher instalar para todos.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\Instalador do Jogo
OutputBaseFilename=NewCraft-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\NewCraft.exe
UninstallDisplayName={#AppName}

[Languages]
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"

[Files]
Source: "..\build\NewCraft.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\Jogar.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\NewCraft.exe"; WorkingDir: "{app}"
Name: "{group}\{#AppName} (modo de compatibilidade)"; Filename: "{app}\Jogar.bat"; WorkingDir: "{app}"; IconFilename: "{app}\NewCraft.exe"; \
	Comment: "Use se o jogo travar ao abrir (ReShade, overlays)"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\NewCraft.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\NewCraft.exe"; Description: "Jogar {#AppName} agora"; Flags: nowait postinstall skipifsilent

[Messages]
ptbr.FinishedLabel=O {#AppName} foi instalado.%n%nSe o jogo travar ao abrir, use o atalho "{#AppName} (modo de compatibilidade)" no menu Iniciar.%n%nOs mundos salvos ficam em %%APPDATA%%\Godot\app_userdata\New Craft\mundos e não são apagados ao desinstalar.
