{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  cargo,
  pkg-config,
  meson,
  ninja,
  blueprint-compiler,
  glib,
  gtk4,
  libadwaita,
  rustc,
  wrapGAppsHook4,
  appstream-glib,
  desktop-file-utils,
  nix-update-script,
}:

stdenv.mkDerivation rec {
  pname = "eyedropper";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "FineFindus";
    repo = "eyedropper";
    rev = "v${version}";
    hash = "sha256-FyGj0180Wn8iIDTdDqnNEvFYegwdWCsCq+hmyTTUIo4=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    name = "${pname}-${version}";
    hash = "sha256-nYmH7Nu43TDJKvwfSaBKSihD0acLPmIUQpQM6kV4CAk=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    blueprint-compiler
    wrapGAppsHook4
    appstream-glib
    desktop-file-utils
    cargo
    rustc
    rustPlatform.cargoSetupHook
  ];

  buildInputs = [
    glib
    gtk4
    libadwaita
  ];

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Pick and format colors";
    homepage = "https://github.com/FineFindus/eyedropper";
    mainProgram = "eyedropper";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ zendo ];
    teams = [ lib.teams.gnome-circle ];
  };
}
