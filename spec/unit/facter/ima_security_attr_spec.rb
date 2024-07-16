require 'spec_helper'

describe 'ima_security_attr', type: :fact do
  before :each do
    Facter.clear
    Facter.clear_messages
    allow(Facter).to receive(:value).with(:cmdline).and_return({ 'ima_appraise_tcb' => '', 'foo' => 'bar' })
    allow(Facter).to receive(:value).with(:puppet_vardir).and_return('/tmp')
  end

  context 'The script is running' do
    before :each do
      allow(Facter::Core::Execution).to receive(:execute).with('ps -ef').and_return 'All kinds of junk and ima_security_attr_update.sh'
    end

    it 'returns updating' do
      expect(Facter.fact(:ima_security_attr).value).to eq 'active'
    end
  end

  context 'The script is not running' do
    before(:each) { allow(Facter::Core::Execution).to receive(:execute).with('ps -ef').and_return 'All kinds of junki\nAnd more junk\nbut not that which shall not be named' }

    context 'The relabel file is not present' do
      before(:each) { allow(File).to receive(:exist?).with('/tmp/simp/.ima_relabel').and_return(false) }

      it 'returns inactive' do
        expect(Facter.fact(:ima_security_attr).value).to eq 'inactive'
      end
    end

    context 'The relabel file is present' do
      before(:each) { allow(File).to receive(:exist?).with('/tmp/simp/.ima_relabel').and_return(true) }

      it 'returns inactive' do
        expect(Facter.fact(:ima_security_attr).value).to eq 'need_relabel'
      end
    end
  end
end
