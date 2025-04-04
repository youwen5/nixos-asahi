# the Asahi Linux kernel and options that must go along with it

{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.hardware.asahi.enable {
    boot.kernelPackages =
      let
        pkgs' = config.hardware.asahi.pkgs;
      in
      pkgs'.linux-asahi.override {
        _kernelPatches = config.boot.kernelPatches;
        withRust = config.hardware.asahi.withRust;
      };

    # we definitely want to use CONFIG_ENERGY_MODEL, and
    # schedutil is a prerequisite for using it
    # source: https://www.kernel.org/doc/html/latest/scheduler/sched-energy.html
    powerManagement.cpuFreqGovernor = lib.mkOverride 800 "schedutil";

    boot.initrd.includeDefaultModules = false;
    boot.initrd.availableKernelModules = [
      # list of initrd modules stolen from
      # https://github.com/AsahiLinux/asahi-scripts/blob/f461f080a1d2575ae4b82879b5624360db3cff8c/initcpio/install/asahi
      "apple-mailbox"
      "nvme_apple"
      "pinctrl-apple-gpio"
      "macsmc"
      "macsmc-rtkit"
      "i2c-pasemi-platform"
      "tps6598x"
      "apple-dart"
      "dwc3"
      "dwc3-of-simple"
      "xhci-pci"
      "pcie-apple"
      "gpio_macsmc"
      "phy-apple-atc"
      "nvmem_apple_efuses"
      "spi-apple"
      "spi-hid-apple"
      "spi-hid-apple-of"
      "rtc-macsmc"
      "simple-mfd-spmi"
      "spmi-apple-controller"
      "nvmem_spmi_mfd"
      "apple-dockchannel"
      "dockchannel-hid"
      "apple-rtkit-helper"

      # additional stuff necessary to boot off USB for the installer
      # and if the initrd (i.e. stage 1) goes wrong
      "usb-storage"
      "xhci-plat-hcd"
      "usbhid"
      "hid_generic"
    ];

    boot.kernelParams = [
      # nice insurance against f***ing up the kernel so much, the Mac no longer boots
      # (NixOS generations are another wonderful insurance policy, obvs)
      "boot.shell_on_fail"
      # There was originally a scary warning here from tpwrules based on the commit
      # https://github.com/AsahiLinux/linux/commit/eecbf0d278c3a5785d460246e9baef22705410f1
      # warning that if you set flush_interval > 0, there is a theoretical possibility
      # of data loss for data written in the 1-2 seconds before power loss.  This is
      # not a worry on laptops because they are battery-backed.  This risk can be mitigated
      # on the desktop with a UPS.  Setting this to zero decreases disk performance by 95%
      # so we set it to the recommended 1000 and don't worry too much about data loss
      "nvme_apple.flush_interval=1000"
      # make boot mostly silent, not because we don't appreciate the useful
      # information (we do), but because spew slows down boot
      "quiet"
      "loglevel=4"
      "systemd.show_status=auto"
      "rd.udev.log_level=4"
    ];

    # U-Boot does not support EFI variables
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    # U-Boot does not support switching console mode
    boot.loader.systemd-boot.consoleMode = "0";

    # GRUB has to be installed as removable if the user chooses to use it
    boot.loader.grub = lib.mkDefault {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };

    # autosuspend was enabled as safe for the PCI SD card reader
    # "Genesys Logic, Inc GL9755 SD Host Controller [17a0:9755] (rev 01)"
    # by recent systemd versions, but this has a "negative interaction"
    # with our kernel/SoC and causes random boot hangs. disable it!
    services.udev.extraHwdb = ''
      pci:v000017A0d00009755*
        ID_AUTOSUSPEND=0
    '';
  };

  imports = [
    (lib.mkRemovedOptionModule [
      "hardware"
      "asahi"
      "addEdgeKernelConfig"
    ] "All edge kernel config options are now the default.")
  ];

  options.hardware.asahi.withRust = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Build the Asahi Linux kernel with Rust support.
    '';
  };
}
