require 'spec_helper'

describe 'ima_log_size', type: :fact do
  before :each do
    Facter.clear
    Facter.clear_messages
  end

  context 'the required file is not present' do
    it 'returns nil' do
      allow(File).to receive(:exist?).with('/sys/kernel/security/ima/ascii_runtime_measurements').and_return false
      expect(Facter.fact(:ima_log_size).value).to eq nil
    end
  end

  context 'the required file is present' do
    it 'reads the contents of the file as an integer' do
      allow(File).to receive(:exist?).with('/sys/kernel/security/ima/ascii_runtime_measurements').and_return true
      allow(Facter::Core::Execution).to receive(:execute).with('wc -c /sys/kernel/security/ima/ascii_runtime_measurements').and_return '1337'

      expect(Facter.fact(:ima_log_size).value).to eq 1337
    end
  end
end
