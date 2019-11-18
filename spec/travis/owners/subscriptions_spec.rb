describe Travis::Owners::Subscriptions do
  let!(:travis)  { FactoryGirl.create(:org,  login: 'travis') }
  let!(:sinatra) { FactoryGirl.create(:org,  login: 'sinatra') }

  let(:plans)    { { five: 5, ten: 10 } }
  let(:limits)   { {} }
  let(:attrs)    { { owner_type: 'Organization', owner_id: travis.id } }
  let(:config)   { { limit: limits, plans: plans } }
  let(:owners)   { Travis::Owners.group(attrs, config) }

  subject { described_class.new(owners, plans).max_jobs }

  # Note that all plans are 1 higher than their original values due to our "free
  #   1-job private repo" plan project, expected to be launched in December,
  #   2018.
  #
  # https://github.com/travis-ci/product/issues/97
  #

  describe 'a single org with a five jobs plan' do
    before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
    it { should eq 5 }
  end

  describe 'with a delegation' do
    let(:limits) { { delegate: { sinatra: 'travis' } } }

    describe 'with a subscription on a delegatee' do
      before { FactoryGirl.create(:subscription, owner: sinatra, selected_plan: :five) }
      it { should eq 5 }
    end

    describe 'with a subscription on a delegate' do
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
      it { should eq 5 }
    end

    describe 'with an invalid subscription on a delegatee' do
      before { FactoryGirl.create(:subscription, owner: travis, selected_plan: :five) }
      before { FactoryGirl.create(:subscription, owner: sinatra) }
      it { should eq 5 }
    end

    describe 'with an invalid subscription on a delegate' do
      before { FactoryGirl.create(:subscription, owner: travis) }
      before { FactoryGirl.create(:subscription, owner: sinatra, selected_plan: :five) }
      it { should eq 5 }
    end
  end
end
