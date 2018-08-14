describe Travis::Scheduler::Jobs::Select do
  let(:org)      { FactoryGirl.create(:org, login: 'travis-ci') }
  let(:repo)     { FactoryGirl.create(:repo, owner: user) }
  let(:build)    { FactoryGirl.create(:build) }
  let(:user)     { FactoryGirl.create(:user, login: 'svenfuchs') }
  let(:owners)   { Travis::Owners.group({ owner_type: 'User', owner_id: user.id }, config.to_h) }
  let(:context)  { Travis::Scheduler.context }
  let(:redis)    { context.redis }
  let(:config)   { context.config }
  let(:select)   { described_class.new(context, owners) }
  let(:selected) { select.run; select.selected }
  let(:reports)   { select.run; select.reports }

  before { config[:limit][:trial] = nil }
  before { config[:limit][:public] = 3 }
  before { config[:limit][:default] = 1 }
  before { config[:plans] = { one: 1, two: 2, four: 4, seven: 7, ten: 10 } }
  before { config[:site] = 'com' }

  def create_jobs(count, attrs = {})
    defaults = {
      repository: repo,
      owner: user,
      source: build,
      state: :created,
      queueable: true,
      private: false
    }
    (1..count).map { FactoryGirl.create(:job, defaults.merge(attrs)) }
  end

  def subscribe(plan, owner = self.user)
    FactoryGirl.create(:subscription, selected_plan: plan, valid_to: Time.now.utc, owner_type: owner.class.name, owner_id: owner.id)
  end

  describe 'with a boost limit 2' do
    before { redis.set("scheduler.owner.limit.#{user.login}", 2) }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(5, private: true) }

      it { expect(selected.size).to eq 1 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, boost max=2' }
      it { expect(reports).to include 'user svenfuchs boost capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'repo svenfuchs/gem-release: queueable=5 running=1 selected=1 waiting=4' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=1 total_waiting=4 waiting_for_concurrency=4' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(5, private: false) }

      it { expect(selected.size).to eq 4 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, boost max=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs boost capacity: running=0 max=2 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=4 total_waiting=1 waiting_for_concurrency=1' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(2, private: true) + create_jobs(2, private: false) }

      it { expect(selected.size).to eq 3 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, boost max=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs boost capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=4 running=2 selected=3 total_waiting=1 waiting_for_concurrency=1' }
    end

    describe 'with no queueable jobs' do
      before { create_jobs(1, private: true, state: :started) }

      it { expect(selected.size).to eq 0 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, boost max=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=0 running=1 selected=0 total_waiting=0 waiting_for_concurrency=0' }
    end
  end

  describe 'with a two jobs plan' do
    before { subscribe(:two) }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(5, private: true) }

      it { expect(selected.size).to eq 1 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, plan max=2' }
      it { expect(reports).to include 'user svenfuchs plan capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=1 total_waiting=4 waiting_for_concurrency=4' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(5, private: false) }

      it { expect(selected.size).to eq 4 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, plan max=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs plan capacity: running=0 max=2 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=4 total_waiting=1 waiting_for_concurrency=1' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(2, private: false) + create_jobs(2, private: true) }

      it { expect(selected.size).to eq 3 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, plan max=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs plan capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=4 running=2 selected=3 total_waiting=1 waiting_for_concurrency=1' }
    end
  end

  describe 'with a trial' do
    before { config[:limit][:trial] = 2 }
    before { FactoryGirl.create(:trial, owner: user, status: :started) }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(5, private: true) }

      it { expect(selected.size).to eq 1 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, trial max=2' }
      it { expect(reports).to include 'user svenfuchs trial capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=1 total_waiting=4 waiting_for_concurrency=4' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(5, private: false) }

      it { expect(selected.size).to eq 4 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, trial max=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs trial capacity: running=0 max=2 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=4 total_waiting=1 waiting_for_concurrency=1' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(2, private: false) + create_jobs(2, private: true) }

      it { expect(selected.size).to eq 3 }
      it { expect(reports).to include 'user svenfuchs capacities: public max=3, trial max=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs trial capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=4 running=2 selected=3 total_waiting=1 waiting_for_concurrency=1' }
    end
  end

  describe 'with a custom config limit 1' do
    before { config[:limit][:by_owner][user.login] = 2 }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(5, private: true) }

      it { expect(selected.size).to eq 1 }
      it { expect(reports).to include 'user svenfuchs config capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=1 total_waiting=4 waiting_for_concurrency=4' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(5, private: false) }

      it { expect(selected.size).to eq 4 }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs config capacity: running=0 max=2 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=4 total_waiting=1 waiting_for_concurrency=1' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(2, private: false) + create_jobs(2, private: true) }

      it { expect(selected.size).to eq 3 }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs config capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=4 running=2 selected=3 total_waiting=1 waiting_for_concurrency=1' }
    end
  end

  describe 'with an educational status, allowing 2 educational jobs' do
    before { config[:limit][:education] = 2 }
    before { user.update_attributes!(education: true) }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(5, private: true) }

      it { expect(selected.size).to eq 1 }
      it { expect(reports).to include 'user svenfuchs education capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=1 total_waiting=4 waiting_for_concurrency=4' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(5, private: false) }

      it { expect(selected.size).to eq 4 }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs education capacity: running=0 max=2 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=4 total_waiting=1 waiting_for_concurrency=1' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(2, private: false) + create_jobs(2, private: true) }

      it { expect(selected.size).to eq 3 }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs education capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=4 running=2 selected=3 total_waiting=1 waiting_for_concurrency=1' }
    end
  end

  describe 'with a two jobs plan, and a trial, only the plan is being used' do
    before { subscribe(:two) }
    before { config[:limit][:trial] = 2 }
    before { context.redis.set("trial:#{user.login}", 5) }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(5, private: true) }

      it { expect(selected.size).to eq 1 }
      it { expect(reports).to include 'user svenfuchs plan capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=1 total_waiting=4 waiting_for_concurrency=4' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(5, private: false) }

      it { expect(selected.size).to eq 4 }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs plan capacity: running=0 max=2 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=4 total_waiting=1 waiting_for_concurrency=1' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(2, private: false) + create_jobs(2, private: true) }

      it { expect(selected.size).to eq 3 }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs plan capacity: running=1 max=2 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=4 running=2 selected=3 total_waiting=1 waiting_for_concurrency=1' }
    end
  end

  describe 'with a boost of 4, and a two jobs plan, only the boost is being used' do
    before { subscribe(:two) }
    before { redis.set("scheduler.owner.limit.#{user.login}", 4) }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(5, private: true) }

      it { expect(selected.size).to eq 3 }
      it { expect(reports).to include 'user svenfuchs boost capacity: running=1 max=4 selected=3' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=3 total_waiting=2 waiting_for_concurrency=2' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(5, private: false) }

      it { expect(selected.size).to eq 5 }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs boost capacity: running=0 max=4 selected=3' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=5 total_waiting=0 waiting_for_concurrency=0' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(2, private: false) + create_jobs(2, private: true) }

      it { expect(selected.size).to eq 4 }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs boost capacity: running=1 max=4 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=4 running=2 selected=4 total_waiting=0 waiting_for_concurrency=0' }
    end
  end

  describe 'with a boost of 5 and a repo settings limit 3' do
    before { redis.set("scheduler.owner.limit.#{user.login}", 5) }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 3) }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(5, private: true) }

      it { expect(selected.size).to eq 2 }
      it { expect(reports).to include 'repo svenfuchs/gem-release limited by repo settings: max=3 rejected=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs boost capacity: running=1 max=5 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=2 total_waiting=3 waiting_for_concurrency=0' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(5, private: false) }

      it { expect(selected.size).to eq 2 }
      it { expect(reports).to include 'repo svenfuchs/gem-release limited by repo settings: max=3 rejected=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=2 total_waiting=3 waiting_for_concurrency=0' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(2, private: false) + create_jobs(2, private: true) }

      it { expect(selected.size).to eq 1 }
      it { expect(reports).to include 'repo svenfuchs/gem-release limited by repo settings: max=3 rejected=3 selected=1' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=4 running=2 selected=1 total_waiting=3 waiting_for_concurrency=0' }
    end
  end

  describe 'with a boost of 4, a two jobs plan, and a repo setting of 3' do
    before { subscribe(:two) }
    before { redis.set("scheduler.owner.limit.#{user.login}", 4) }
    before { repo.settings.update_attributes!(maximum_number_of_builds: 3) }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(5, private: true) }

      it { expect(selected.size).to eq 2 }
      it { expect(reports).to include 'repo svenfuchs/gem-release limited by repo settings: max=3 rejected=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs boost capacity: running=1 max=4 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=2 total_waiting=3 waiting_for_concurrency=0' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(5, private: false) }

      it { expect(selected.size).to eq 2 }
      it { expect(reports).to include 'repo svenfuchs/gem-release limited by repo settings: max=3 rejected=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=5 running=1 selected=2 total_waiting=3 waiting_for_concurrency=0' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(2, private: false) + create_jobs(2, private: true) }

      it { expect(selected.size).to eq 1 }
      it { expect(reports).to include 'repo svenfuchs/gem-release limited by repo settings: max=3 rejected=3 selected=1' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=1' }
      it { expect(reports).to include 'user svenfuchs: queueable=4 running=2 selected=1 total_waiting=3 waiting_for_concurrency=0' }
    end
  end

  describe 'with a ten jobs plan and a by_queue limit of 3 for the owner' do
    env BY_QUEUE_NAME: 'builds.osx'
    env BY_QUEUE_LIMIT: 'svenfuchs=3'

    before { subscribe(:ten) }

    describe 'with private jobs only' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: true, state: :started, queue: 'builds.osx') }
      before { create_jobs(9, private: true, queue: 'builds.osx') }
      before { create_jobs(1, private: true) }

      it { expect(selected.size).to eq 3 }
      it { expect(reports).to include 'user svenfuchs limited by queue builds.osx: max=3 rejected=7 selected=2' }
      it { expect(reports).to include 'user svenfuchs plan capacity: running=2 max=10 selected=3' }
      it { expect(reports).to include 'user svenfuchs: queueable=10 running=2 selected=3 total_waiting=7 waiting_for_concurrency=0' }
    end

    describe 'with public jobs only' do
      before { create_jobs(1, private: false, state: :started) }
      before { create_jobs(1, private: false, state: :started, queue: 'builds.osx') }
      before { create_jobs(9, private: false, queue: 'builds.osx') }
      before { create_jobs(1, private: false) }

      it { expect(selected.size).to eq 3 }
      it { expect(reports).to include 'user svenfuchs limited by queue builds.osx: max=3 rejected=7 selected=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=2 max=3 selected=1' }
      it { expect(reports).to include 'user svenfuchs plan capacity: running=0 max=10 selected=2' }
      it { expect(reports).to include 'user svenfuchs: queueable=10 running=2 selected=3 total_waiting=7 waiting_for_concurrency=0' }
    end

    describe 'for mixed public and private jobs' do
      before { create_jobs(1, private: true, state: :started) }
      before { create_jobs(1, private: true, queue: 'builds.osx', state: :started) }
      before { create_jobs(4, private: true, queue: 'builds.osx') }
      before { create_jobs(1, private: true) }
      before { create_jobs(4, private: false, queue: 'builds.osx') }
      before { create_jobs(1, private: false) }

      it { expect(selected.size).to eq 4 }
      it { expect(reports).to include 'user svenfuchs limited by queue builds.osx: max=3 rejected=6 selected=2' }
      it { expect(reports).to include 'user svenfuchs public capacity: running=0 max=3 selected=1' }
      it { expect(reports).to include 'user svenfuchs plan capacity: running=2 max=10 selected=3' }
      it { expect(reports).to include 'user svenfuchs: queueable=10 running=2 selected=4 total_waiting=6 waiting_for_concurrency=0' }
    end
  end

  describe 'stages' do
    before { config[:limit][:by_owner][user.login] = 10 }

    describe 'with private jobs only' do
      let(:one) { FactoryGirl.create(:stage, number: 1) }
      let(:two) { FactoryGirl.create(:stage, number: 2) }
      let(:three) { FactoryGirl.create(:stage, number: 3) }

      before { create_jobs(1, private: true, stage: one, stage_number: '1.1', state: :started) }
      before { create_jobs(1, private: true, stage: one, stage_number: '1.2') }
      before { create_jobs(1, private: true, stage: one, stage_number: '1.3') }
      before { create_jobs(1, private: true, stage: two, stage_number: '2.1') }
      before { create_jobs(1, private: true, stage: three, stage_number: '10.1') }

      describe 'queueing' do
        it { expect(selected.size).to eq 2 }
        it { expect(reports).to include "repo #{repo.slug} limited by stage on build_id=#{build.id}: rejected=2 selected=2" }
        it { expect(reports).to include 'user svenfuchs config capacity: running=1 max=10 selected=2' }
        it { expect(reports).to include 'user svenfuchs: queueable=4 running=1 selected=2 total_waiting=2 waiting_for_concurrency=0' }
      end

      describe 'ordering' do
        before { one.jobs.update_all(state: :passed) }
        before { Queueable.where(job_id: one.jobs.pluck(:id)).delete_all }
        it { expect(selected[0].id).to eq Job.where(stage_number: '2.1').first.id }
      end
    end

    describe 'with public jobs only' do
      let(:one) { FactoryGirl.create(:stage, number: 1) }
      let(:two) { FactoryGirl.create(:stage, number: 2) }
      let(:three) { FactoryGirl.create(:stage, number: 3) }

      before { create_jobs(1, stage: one, stage_number: '1.1', state: :started) }
      before { create_jobs(1, stage: one, stage_number: '1.2') }
      before { create_jobs(1, stage: one, stage_number: '1.3') }
      before { create_jobs(1, stage: two, stage_number: '2.1') }
      before { create_jobs(1, stage: three, stage_number: '10.1') }

      describe 'queueing' do
        it { expect(selected.size).to eq 2 }
        it { expect(reports).to include "repo #{repo.slug} limited by stage on build_id=#{build.id}: rejected=2 selected=2" }
        it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=2' }
        it { expect(reports).to include 'user svenfuchs: queueable=4 running=1 selected=2 total_waiting=2 waiting_for_concurrency=0' }
      end

      describe 'ordering' do
        before { one.jobs.update_all(state: :passed) }
        before { Queueable.where(job_id: one.jobs.pluck(:id)).delete_all }
        it { expect(selected[0].id).to eq Job.where(stage_number: '2.1').first.id }
      end
    end

    describe 'for mixed public and private jobs' do
      let(:one) { FactoryGirl.create(:stage, number: 1) }
      let(:two) { FactoryGirl.create(:stage, number: 2) }
      let(:three) { FactoryGirl.create(:stage, number: 3) }

      before { create_jobs(1, private: false, stage: one, stage_number: '1.1', state: :started) }
      before { create_jobs(1, private: true,  stage: one, stage_number: '1.2') }
      before { create_jobs(1, private: false, stage: one, stage_number: '1.3') }
      before { create_jobs(1, private: true,  stage: two, stage_number: '2.1') }
      before { create_jobs(1, private: false, stage: three, stage_number: '10.1') }

      describe 'queueing' do
        it { expect(selected.size).to eq 2 }
        it { expect(reports).to include "repo #{repo.slug} limited by stage on build_id=#{build.id}: rejected=2 selected=2" }
        it { expect(reports).to include 'user svenfuchs public capacity: running=1 max=3 selected=1' }
        it { expect(reports).to include 'user svenfuchs config capacity: running=0 max=10 selected=1' }
        it { expect(reports).to include 'user svenfuchs: queueable=4 running=1 selected=2 total_waiting=2 waiting_for_concurrency=0' }
      end

      describe 'ordering' do
        before { one.jobs.update_all(state: :passed) }
        before { Queueable.where(job_id: one.jobs.pluck(:id)).delete_all }
        it { expect(selected[0].id).to eq Job.where(stage_number: '2.1').first.id }
      end
    end
  end
end
