describe Travis::Scheduler::Serialize::Worker::Job do
  let(:request) { Request.new }
  let(:build)   { Build.new(request: request) }
  let(:job)     { Job.new(source: build) }
  subject       { described_class.new(job) }

  describe 'env_vars' do
    xit
  end

  describe 'pull_request?' do
    describe 'with event_type :push' do
      before { build.event_type = 'push' }
      it { expect(subject.pull_request?).to be false }
    end

    describe 'with event_type :pull_request' do
      before { build.event_type = 'pull_request' }
      it { expect(subject.pull_request?).to be true }
    end
  end

  describe '#secure_env?' do
    describe 'with a push event' do
      before { build.event_type = 'push' }
      it { expect(subject.secure_env?).to eq(true) }
    end

    describe 'with a pull_request event' do
      before { build.event_type = 'pull_request' }

      describe 'from the same repository' do
        before { request.stubs(:same_repo_pull_request?).returns(true) }
        it { expect(subject.secure_env?).to eq(true) }
      end

      describe 'from a different repository' do
        before { request.stubs(:same_repo_pull_request?).returns(false) }
        it { expect(subject.secure_env?).to eq(false) }
      end
    end
  end
end
