require 'spec_helper'

describe 'ima' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do

      let(:facts) do
        os_facts.merge(
          cmdline:      { 'ima' => 'on' },
          ima_log_size: 29000000,
        )
      end

      context 'with default params' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('ima') }
        it { is_expected.to contain_class('ima::appraise') }
        it { is_expected.to contain_class('ima::policy') }
        it { is_expected.not_to contain_reboot_notify('ima_log') }
        it { is_expected.to contain_kernel_parameter('ima').with_value('on') }
        it { is_expected.to contain_kernel_parameter('ima').with_bootmode('normal') }
        it { is_expected.to contain_kernel_parameter('ima_audit').with_value('0') }
        it { is_expected.to contain_kernel_parameter('ima_audit').with_bootmode('normal') }
        it { is_expected.to contain_kernel_parameter('ima_tcb') }
        it { is_expected.to contain_kernel_parameter('ima_tcb').with_bootmode('normal') }

        it do
          is_expected.to contain_mount('/sys/kernel/security').with(
            ensure:   'mounted',
            atboot:   true,
            device:   'securityfs',
            fstype:   'securityfs',
            target:   '/etc/fstab',
            remounts: true,
            options:  'defaults',
            dump:     '0',
            pass:     '0'
          )
        end
      end

      context 'should tell the user to reboot when the ima log is filling up' do
        let(:facts) do
          os_facts.merge( ima_log_size: 50000002 )
        end
        let(:params) {{ log_max_size: 50000000 }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_reboot_notify('ima_log') }
      end

      context 'with kernel version >= 3.13' do
        let(:facts) do
          os_facts.merge({
            cmdline:      { 'foo' => 'bar' },
            ima_log_size: 29000000,
            kernelmajversion: '3.13'
          })
        end

        let(:params) {{
          mount_dir:     '/sys/kernel/security',
          ima_audit:     false,
          ima_template:  'ima-ng',
          ima_hash:      'sha256',
          ima_tcb:       true
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file(params[:mount_dir]) }
        it { is_expected.to contain_reboot_notify('ima_reboot') }
        it { is_expected.to contain_kernel_parameter('ima').with_value('on') }
        it { is_expected.to contain_kernel_parameter('ima').with_bootmode('normal') }
        it { is_expected.to contain_kernel_parameter('ima_audit').with_value('0') }
        it { is_expected.to contain_kernel_parameter('ima_audit').with_bootmode('normal') }
        it { is_expected.to contain_kernel_parameter('ima_template').with_value(params[:ima_template]) }
        it { is_expected.to contain_kernel_parameter('ima_template').with_bootmode('normal') }
        it { is_expected.to contain_kernel_parameter('ima_hash').with_value(params[:ima_hash]) }
        it { is_expected.to contain_kernel_parameter('ima_hash').with_bootmode('normal') }
        it { is_expected.to contain_kernel_parameter('ima_tcb') }
        it { is_expected.to contain_kernel_parameter('ima_tcb').with_bootmode('normal') }
      end

      context 'with_kernel_version < 3.13' do
        let(:facts) do
          os_facts.merge({
            cmdline:          { 'foo' => 'bar' },
            ima_log_size:     29000000,
            kernelmajversion: '3.10'
          })
        end

        let(:params) {{
          ima_audit:     true,
          ima_template:  'ima-ng',
          ima_hash:      'sha256',
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_reboot_notify('ima_reboot') }
        it { is_expected.to contain_kernel_parameter('ima').with_value('on') }
        it { is_expected.to contain_kernel_parameter('ima').with_bootmode('normal') }
        it { is_expected.to contain_kernel_parameter('ima_template').with_ensure('absent') }
        it { is_expected.to contain_kernel_parameter('ima_template').with_bootmode('normal') }
        it { is_expected.to contain_kernel_parameter('ima_hash').with_ensure('absent') }
        it { is_expected.to contain_kernel_parameter('ima_hash').with_bootmode('normal') }
        it { is_expected.to contain_kernel_parameter('ima_audit').with_value('1') }
        it { is_expected.to contain_kernel_parameter('ima_tcb') }
      end

      context 'with enable set to false' do
        let(:facts) do
          os_facts.merge(
            cmdline:      { 'ima' => 'on' },
          )
        end

        let(:params) {{ enable: false }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_reboot_notify('ima_reboot') }
        it { is_expected.to create_kernel_parameter('ima').with_ensure('absent') }
        it { is_expected.to create_kernel_parameter('ima').with_bootmode('normal') }
        it { is_expected.to create_kernel_parameter('ima_tcb').with_ensure('absent') }
        it { is_expected.to create_kernel_parameter('ima_tcb').with_bootmode('normal') }
        it { is_expected.to create_kernel_parameter('ima_audit').with_ensure('absent') }
        it { is_expected.to create_kernel_parameter('ima_audit').with_bootmode('normal') }
        it { is_expected.to create_kernel_parameter('ima_template').with_ensure('absent') }
        it { is_expected.to create_kernel_parameter('ima_template').with_bootmode('normal') }
        it { is_expected.to create_kernel_parameter('ima_hash').with_ensure('absent') }
        it { is_expected.to create_kernel_parameter('ima_hash').with_bootmode('normal') }
      end

    end
  end
end
