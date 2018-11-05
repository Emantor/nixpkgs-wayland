self: super:
let
swaypkgs = {
  # patched deps
  fmt              = self.callPackage ./fmt {};

  # wlroots-related
  wlroots          = self.callPackage ./wlroots {};
  sway-beta        = self.callPackage ./sway-beta {};
  grim             = self.callPackage ./grim {};
  slurp            = self.callPackage ./slurp {};
  mako             = self.callPackage ./mako {};
  kanshi           = self.callPackage ./kanshi {};
  wlstream         = self.callPackage ./wlstream {};
  oguri            = self.callPackage ./oguri {};
  waybar           = self.callPackage ./waybar {};
  wf-config        = self.callPackage ./wf-config {};
  wayfire          = self.callPackage ./wayfire {};
  redshift-wayland = self.callPackage ./redshift-wayland {
    inherit (self.python3Packages) python pygobject3 pyxdg wrapPython;
    geoclue = self.geoclue2;
  };

  # i3-related
  wmfocus          = self.callPackage ./wmfocus {};
  i3status-rust    = self.callPackage ./i3status-rust {};
};
in
  swaypkgs // { inherit swaypkgs; }

