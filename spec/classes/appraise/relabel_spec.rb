require 'spec_helper'

# really testing 'ima::appraise:relabel', but since private, do this
# via ima::appraise

describe 'ima::appraise' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let (:params) {{
        relabel_file: '/tmp/simp/.ima_relabel',
        scriptdir: '/myscripts'
      }}

      let (:default_facts) do
        os_facts.merge({
          :cmdline => { 'ima' => 'on', 'ima_appraise' => 'fix' }
        })
      end

      context 'with ima_security_attr inactive' do
        let (:facts) do
          default_facts.merge({
            :ima_security_attr => 'inactive'
          })
        end
        it { is_expected.to contain_kernel_parameter('ima_appraise').with({
          'value'    => 'enforce',
          'bootmode' => 'normal',
        }).that_notifies('Exec[dracut ima appraise rebuild]')}
        it { is_expected.to contain_exec('dracut ima appraise rebuild').with({
          'command'     => '/sbin/dracut -f',
          'refreshonly' => true
        }).that_subscribes_to('Kernel_parameter[ima_appraise]')}
        it { is_expected.to contain_reboot_notify('ima_appraise_enforce_reboot').that_subscribes_to('Kernel_parameter[ima_appraise]')}
      end

      context 'with ima_security_attr active' do
        let (:facts) do
          default_facts.merge({
            :ima_security_attr => 'active'
          })
        end
        it { is_expected.to contain_notify('IMA updates running')}
      end

      context 'with ima_security_attr relabel' do
        let (:facts) do
          default_facts.merge({
            :ima_security_attr => 'relabel'
          })
        end
        it { is_expected.to contain_notify('IMA updates started')}
        it { is_expected.to contain_exec('ima_security_attr_update').with({
          'command'    => '/myscripts/ima_security_attr_update.sh /tmp/simp/.ima_relabel &',
        })}
      end
    end
  end
end
