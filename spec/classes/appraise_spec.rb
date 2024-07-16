require 'spec_helper'

shared_examples_for 'an ima appraise enabled system' do
  it { is_expected.to compile.with_all_deps }
  it { is_expected.to create_class('ima::appraise') }
  it { is_expected.to contain_class('ima') }
  it { is_expected.to create_package('attr') }
  it { is_expected.to create_package('ima-evm-utils') }
  it { is_expected.to create_kernel_parameter('ima_appraise_tcb') }
  it { is_expected.to create_kernel_parameter('ima_appraise_tcb').with_bootmode('normal') }
  it { is_expected.to create_kernel_parameter('rootflags').with_value('i_version') }
  it { is_expected.to create_kernel_parameter('rootflags').with_bootmode('normal') }
  it do
    is_expected.to create_file('/myscripts/ima_security_attr_update.sh')
      .with('source' => 'puppet:///modules/ima/ima_security_attr_update.sh')
  end
end

describe 'ima::appraise' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:default_facts) do
        os_facts.merge(
          puppet: { vardir: '/tmp' },
          cmdline: { 'ima' => 'on' },
        )
      end

      context 'with default params' do
        let(:params) do
          {
            relabel_file: '/tmp/relabel',
            ensure_packages: 'installed',
            scriptdir: '/myscripts',
          }
        end

        context 'with ima_appraise not set' do
          let(:facts) do
            default_facts.merge(cmdline: { 'foo' => 'bar' })
          end

          it_behaves_like 'an ima appraise enabled system'
          it do
            is_expected.to contain_class('ima::appraise::fixmode')
              .with('relabel' => true)
          end
        end

        context 'with ima_appraise not set but ima_appraise_tcb set' do
          let(:facts) do
            default_facts.merge(cmdline: { 'foo' => 'bar', 'ima_appraise_tcb' => '' })
          end

          it_behaves_like 'an ima appraise enabled system'
          it { is_expected.not_to contain_class('ima::appraise::fixmode') }
          it { is_expected.not_to contain_class('ima::appraise::relabel') }
          it do
            is_expected.to contain_file('/tmp/relabel')
              .with('ensure' => 'absent')
          end
        end

        context 'with ima_appraise fix' do
          let(:facts) do
            default_facts.merge(cmdline: { 'ima_appraise' => 'fix' })
          end

          it_behaves_like 'an ima appraise enabled system'
          it { is_expected.not_to contain_class('ima::appraise::fixmode') }
          it do
            is_expected.to contain_class('ima::appraise::relabel')
              .with('relabel_file' => '/tmp/relabel')
          end
        end

        context 'with ima_appraise enforce' do
          let(:facts) do
            default_facts.merge(cmdline: { 'ima_appraise' => 'enforce' })
          end

          it_behaves_like 'an ima appraise enabled system'
          it { is_expected.not_to contain_class('ima::appraise::fixmode') }
          it { is_expected.not_to contain_class('ima::appraise::relabel') }
          it do
            is_expected.to contain_file('/tmp/relabel')
              .with('ensure' => 'absent')
          end
        end

        context 'with ima_appraise off' do
          let(:facts) do
            default_facts.merge(cmdline: { 'ima_appraise' => 'off' })
          end

          it_behaves_like 'an ima appraise enabled system'
          it do
            is_expected.to contain_class('ima::appraise::fixmode')
              .with('relabel' => true)
          end
          it { is_expected.not_to contain_class('ima::appraise::relabel') }
        end
      end

      context 'with fix_mode set to true' do
        let(:params) do
          {
            relabel_file: '/tmp/relabel',
            scriptdir: '/myscripts',
            force_fixmode: true,
          }
        end
        let(:facts) do
          os_facts.merge(cmdline: { 'ima' => 'on' })
        end

        it_behaves_like 'an ima appraise enabled system'
        it do
          is_expected.to contain_class('ima::appraise::fixmode')
            .with('relabel' => false)
        end
        it { is_expected.not_to contain_class('ima::appraise::relabel') }
      end

      context 'with enable set to false' do
        let(:params) do
          {
            enable: false,
            ensure_packages: 'installed',
            scriptdir: '/myscripts',
            relabel_file: '/tmp/relabel',
          }
        end
        let(:facts) do
          os_facts.merge(cmdline: { 'ima' => 'on' })
        end

        it do
          is_expected.to create_kernel_parameter('ima_appraise_tcb')
            .with('ensure' => 'absent')
        end
        it do
          is_expected.to create_kernel_parameter('ima_appraise')
            .with('ensure' => 'absent')
        end
      end
    end
  end
end
