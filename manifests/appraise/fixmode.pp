#  set the ima appraise mode to fix
#
# @param relabel_file
#   The location of the file used to flag that the file system needs to be
#   relabeled with the ``security.ima`` attributes
#
# @param relabel
#   Whether the file system needs to be relabeled with the ``security.ima``
#   attributes.  When ``true``, ``$relabel_file`` is created; when
#   ``false``, it is ensured absent
#
class ima::appraise::fixmode (
  StdLib::AbsolutePath $relabel_file,
  Boolean              $relabel
) {
  assert_private()

  kernel_parameter { 'ima_appraise':
    value    => 'fix',
    bootmode => 'normal',
    notify   => Reboot_notify['ima_appraise_fix_reboot']
  }

  if $relabel {
    file { $relabel_file:
      ensure  => 'file',
      owner   => 'root',
      mode    => '0600',
      content => 'relabel'
    }
  }
  else {
    file { $relabel_file:
      ensure => 'absent'
    }
  }

  # Notified from the kernel_parameter above rather than subscribing to it by
  # title: the augeasproviders_grub kernel_parameter type uses composite
  # namevars, so a bare Kernel_parameter['ima_appraise'] reference does not
  # resolve to a resource declared with bootmode => 'normal'. See ima
  # (init.pp).
  reboot_notify { 'ima_appraise_fix_reboot': }
}
