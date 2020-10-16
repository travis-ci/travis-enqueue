describe Travis::Queue do
  let(:context)    { Travis::Scheduler.context }
  let(:recently)   { 7.days.ago }
  let(:created_at) { Time.now }
  let(:slug)       { 'travis-ci/travis-ci' }
  let(:config)     { {} }
  let(:percent)    { 0 }

  let(:owner)      { FactoryGirl.build(:user, login: slug.split('/').first) }
  let(:repo)       { FactoryGirl.build(:repo, owner: owner, owner_name: owner.login, name: slug.split('/').last, created_at: created_at) }
  let(:job)        { FactoryGirl.build(:job, config: config, owner: owner, repository: repo) }
  let(:queue)      { described_class.new(job, context.config, logger).select }

  before do
    Travis::Scheduler.logger.stubs(:info)
    context.config.queue.default = 'builds.default'
    context.config.queues = [
      { queue: 'builds.rails', slug: 'rails/rails' },
      { queue: 'builds.mac_osx', os: 'osx' },
      { queue: 'builds.amd64-lxd', virt: 'lxd' },
      { queue: 'builds.gce', services: %w(docker) },
      { queue: 'builds.gce', dist: 'trusty' },
      { queue: 'builds.gce', dist: 'xenial' },
      { queue: 'builds.gce', resources: { gpu: true } },
      { queue: 'builds.cloudfoundry', owner: 'cloudfoundry' },
      { queue: 'builds.clojure', language: 'clojure' },
      { queue: 'builds.erlang', language: 'erlang' },
      { queue: 'builds.mac_stable', osx_image: 'stable' },
      { queue: 'builds.mac_beta', osx_image: 'beta' },
      { queue: 'builds.new-foo', language: 'foo', percentage: percent },
      { queue: 'builds.old-foo', language: 'foo' },
      { queue: 'builds.arm64-lxd', arch: 'arm64' },
      { queue: 'builds.power', arch: 'ppc64le' },
      { queue: 'builds.z', arch: 's390x' },
    ]
  end

  after do
    context.config.queues = nil
    context.redis.flushall
  end

  describe 'by default' do
    let(:slug) { 'travis-ci/travis-ci' }
    it { expect(queue).to eq 'builds.default' }
  end

  describe 'by app config' do
    describe 'by repo slug' do
      let(:slug) { 'rails/rails' }
      it { expect(queue).to eq 'builds.rails' }
    end

    describe 'by owner name' do
      let(:slug) { 'cloudfoundry/bosh' }
      it { expect(queue).to eq 'builds.cloudfoundry' }
    end
  end

  describe 'by job config' do
    describe 'by language' do
      let(:config) { { language: 'clojure' } }
      it { expect(queue).to eq 'builds.clojure' }
    end

    describe 'by language (passed as an array)' do
      let(:config) { { language: ['clojure'] } }
      it { expect(queue).to eq 'builds.clojure' }
    end
  end

  describe 'by educational status' do
    before { owner.stubs(:education?).returns(true) }

    describe 'on org' do
      describe 'returns the default queue for educational repositories, too' do
        it { expect(queue).to eq 'builds.default' }
      end

      describe 'returns the queue matching configuration for educational repository' do
        let(:config) { { os: 'osx' } }
        it { expect(queue).to eq 'builds.mac_osx' }
      end
    end

    describe 'on com' do
      before { context.config.host = 'travis-ci.com' }
      after  { context.config.host = 'travis-ci.org' }

      describe 'returns the default queue by default for educational repositories' do
        it { expect(queue).to eq 'builds.default' }
      end

      describe 'returns the queue matching configuration for educational repository' do
        let(:config) { { os: 'osx' } }
        it { expect(queue).to eq 'builds.mac_osx' }
      end
    end
  end

  describe 'by job config :os' do
    describe 'by os' do
      let(:config) { { :os => 'osx'} }
      it { expect(queue).to eq 'builds.mac_osx' }
    end

    describe 'by os (trumps language)' do
      let(:config) { { language: 'clojure', os: 'osx' } }
      it { expect(queue).to eq 'builds.mac_osx' }
    end
  end

  describe 'by job config :services' do
    describe 'by service' do
      let(:config) { { services: %w(redis docker postgresql) } }
      it { expect(queue).to eq 'builds.gce' }
    end

    describe 'by service (trumps language)' do
      let(:config) { { language: 'clojure', services: %w(redis docker postgresql) } }
      it { expect(queue).to eq 'builds.gce' }
    end
  end

  describe 'by job config :dist' do
    describe 'dist: trusty' do
      let(:config) { { dist: 'trusty' } }
      it { expect(queue).to eq 'builds.gce' }
    end

    describe 'dist: unknown' do
      let(:config) { { dist: 'unknown' } }
      it { expect(queue).to eq 'builds.default' }
    end
  end

  describe 'by job config osx_image' do
    describe 'osx_image: stable' do
      let(:config) { { osx_image: 'stable' } }
      it { expect(queue).to eq 'builds.mac_stable' }
    end

    describe 'osx_image: beta' do
      let(:config) { { osx_image: 'beta' } }
      it { expect(queue).to eq 'builds.mac_beta' }
    end
  end

  describe 'by job config :virt' do
    describe 'virt: lxd' do
      let(:config) { { virt: 'lxd' } }
      it { expect(queue).to eq 'builds.amd64-lxd' }
    end

    describe 'virt: vm' do
      let(:config) { { virt: 'vm' } }
      it { expect(queue).to eq 'builds.default' }
    end

    describe 'virt: vm, dist: xenial' do
      let(:config) { { virt: 'lxd', dist: 'xenial' } }
      it { expect(queue).to eq 'builds.amd64-lxd' }
    end

    describe 'no :virt config' do
      let(:config) { { services: %w(redis docker postgresql) } }
      it { expect(queue).to eq 'builds.gce' }
    end
  end


  describe 'by job config :arch' do
    describe 'arch: amd64' do
      let(:config) { { arch: 'amd64' } }
      it { expect(queue).to eq 'builds.default' }
    end

    describe 'arch: s390x' do
      let(:config) { { arch: 's390x' } }

      context 'when repo is public' do
        it { expect(queue).to eq 'builds.z' }
      end

      context 'when repo is private' do
        let(:job) { FactoryGirl.build(:job, config: config, owner: owner, repository: repo, private: true) }
        it { expect(queue).to eq 'builds.default' }
      end
    end

    describe 'arch: ppc64le' do
      let(:config) { { arch: 'ppc64le' } }
      it { expect(queue).to eq 'builds.power' }
    end

    describe 'arch: arm64' do
      let(:config) { { arch: 'arm64' } }

      context 'when repo is public' do
        it { expect(queue).to eq 'builds.arm64-lxd' }
      end

      context 'when repo is private' do
        let(:job) { FactoryGirl.build(:job, config: config, owner: owner, repository: repo, private: true) }
        it { expect(queue).to eq 'builds.default' }
      end
    end
  end

  describe 'given a percentage' do
    describe '0 percent' do
      let(:percent) { 0 }
      let(:config)  { { language: 'foo' } }
      it { expect(queue).to eq 'builds.old-foo' }
    end

    describe '100 percent' do
      let(:percent) { 100 }
      let(:config)  { { language: 'foo' } }
      it { expect(queue).to eq 'builds.new-foo' }
    end
  end

  describe 'resources.gpu: true routes to gce' do
    let(:config) { { resources: { gpu: true } } }
    before { Travis::Features.activate_repository(:vm_config, repo) }
    it { expect(queue).to eq 'builds.gce' }
  end

  describe 'pooled' do
    env TRAVIS_SITE: 'com',
        POOL_QUEUES: 'gce',
        POOL_SUFFIX: 'foo'

    let(:config) { { dist: 'trusty' } }

    it { expect(queue).to eq 'builds.gce-foo' }
  end
end
