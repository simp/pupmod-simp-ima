#  set the ima appraise mode to fix
#
class ima::appraise::fixmode(
  StdLib::AbsolutePath $relabel_file,
  Boolean              $relabel
){
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
