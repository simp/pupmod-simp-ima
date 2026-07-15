# Sets up IMA kernel boot flags if they are not enabled, and mounts the
# ``securityfs`` when they are.
#
# @param enable
#   Enable IMA on the system
#
# @param mount_dir
#   Where to mount the IMA ``securityfs``
#
# @param ima_audit
#   Audit control.  Can be set to:
#     true  - Enable additional integrity auditing messages
#     false - Enable integrity auditing messages (default)
#
# @param ima_template
#   A predefined IMA measurement template format.
#
#   * NOTE: This is only valid in kernel version >= ``3.13``. It is always
#     ``ima`` in older versions.
#
# @param ima_hash
#   The list of supported hashes can be found in ``crypto/hash_infotru.h``
#
# @param ima_tcb Toggle the TCB policy.  This means IMA will measure
#   all programs exec'd, files mmap'd for exec, and all file opened
#   for read by uid=0. Defaults to true.
#
# @param log_max_size The size of the
#   /sys/kernel/security/ima/ascii_runtime_measurements, in bytes, that will
#   cause a reboot notification will be sent to the user.
#
# @param ima_tcb
#   Toggle the TCB policy
#
#   * IMA will measure all programs called via ``exec``, files copied via
#     ``mmap``, and all files opened by ``uid=0``.
#
# @param log_max_size
#   The size of ``/sys/kernel/security/ima/ascii_runtime_measurements``, in
#   bytes, that will cause a reboot notification will be sent to the user.
#
class ima (
  Boolean                $enable          = true,
  Stdlib::AbsolutePath   $mount_dir       = '/sys/kernel/security',
  Boolean                $ima_audit       = false,
  Ima::Template          $ima_template    = 'ima-ng',
  String[1]              $ima_hash        = 'sha256',
  Boolean                $ima_tcb         = true,
  Integer[1]             $log_max_size    = 30000000,
) {

  if $enable {

    if $facts['cmdline']['ima'] == 'on' {
      mount { $mount_dir:
        ensure   => mounted,
        atboot   => true,
        device   => 'securityfs',
        fstype   => 'securityfs',
        target   => '/etc/fstab',
        remounts => true,
        options  => 'defaults',
        dump     => '0',
        pass     => '0'
      }
    }

    kernel_parameter { 'ima':
      value    => 'on',
      bootmode => 'normal',
      notify   => Reboot_notify['ima_reboot']
    }

    $_ima_audit = $ima_audit ? {
      true    => '1',
      default => '0'
    }
    kernel_parameter { 'ima_audit':
      value    => $_ima_audit,
      bootmode => 'normal',
      notify   => Reboot_notify['ima_reboot']
    }

    if (versioncmp($facts['kernelmajversion'],'3.13') >= 0) {
      kernel_parameter { 'ima_template':
        value    => $ima_template,
        bootmode => 'normal',
        notify   => Reboot_notify['ima_reboot']
      }
      kernel_parameter { 'ima_hash':
        value    => $ima_hash,
        bootmode => 'normal',
        notify   => Reboot_notify['ima_reboot']
      }
    }
    else {
      kernel_parameter { [ 'ima_template', 'ima_hash' ]:
        ensure   => 'absent',
        bootmode => 'normal',
        notify   => Reboot_notify['ima_reboot']
      }
    }

    if $ima_tcb {
      kernel_parameter { 'ima_tcb':
        notify   => Reboot_notify['ima_reboot'],
        bootmode => 'normal'
      }
    }

    if $facts['ima_log_size'] {
      if $facts['ima_log_size'] >= $log_max_size {
        reboot_notify { 'ima_log':
          reason => 'The IMA /sys/kernel/security/ima/ascii_runtime_measurements is filling up kernel memory. Please reboot to clear.'
        }
      }
    }
  }
  else {
    kernel_parameter { [ 'ima', 'ima_audit', 'ima_template', 'ima_hash', 'ima_tcb' ]:
      ensure   => 'absent',
      bootmode => 'normal',
      notify   => Reboot_notify['ima_reboot']
    }
  }

  # Each kernel_parameter above declares `notify => Reboot_notify['ima_reboot']`
  # rather than this resource subscribing to them by title. The
  # kernel_parameter type (augeasproviders_grub) uses composite namevars
  # (name + bootmode) and overrides its title to "<name>:<bootmode>", so a
  # bare-title reference such as Kernel_parameter['ima'] no longer resolves to
  # a resource declared with bootmode => 'normal' -- it fails catalog
  # dependency resolution. Notifying from each resource avoids the title
  # lookup entirely, matching the pattern in the fips and selinux modules.
  reboot_notify { 'ima_reboot': }
}
