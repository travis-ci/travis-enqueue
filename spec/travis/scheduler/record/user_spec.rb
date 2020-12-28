describe User do
  let(:user) { FactoryGirl.create(:user) }
  let(:repo) { FactoryGirl.create(:repository) }
  let(:authorize_build_url) { "http://localhost:9292/users/#{user.id}/authorize_build" }

  describe "constants" do
    # It isn't often that we see tests for constants, but these are special.
    #   Changing these values for worker timeout limits impacts our infra teams,
    #   and should only be adjusted after consulting with them.
    #
    it "has correct values for default timeouts" do
      expect(User::DEFAULT_SPONSORED_TIMEOUT).to eq 3000
      expect(User::DEFAULT_SUBSCRIBED_TIMEOUT).to eq 7200
    end
  end

  describe "#educational?" do
    context "education = true" do
      before do
        user.education = true
      end

      it "returns true" do
        expect(user.educational?).to be_truthy
      end
    end

    context "education = false" do
      before do
        user.education = false
      end

      it "returns true" do
        expect(user.educational?).to be_falsey
      end
    end

    context "education = nil" do
      before do
        user.education = nil
      end

      it "returns true" do
        expect(user.educational?).to be_falsey
      end
    end
  end

  describe "#default_worker_timeout" do
    context "subscribed? == true" do
      before do
        user.stubs(:subscribed?).returns(true)
      end

      it "returns the DEFAULT_SUBSCRIBED_TIMEOUT" do
        expect(user.default_worker_timeout(repo)).to eq User::DEFAULT_SUBSCRIBED_TIMEOUT
      end
    end

    context "educational? == true" do
      before do
        user.stubs(:educational?).returns(true)
      end

      it "returns the DEFAULT_SUBSCRIBED_TIMEOUT" do
        expect(user.default_worker_timeout(repo)).to eq User::DEFAULT_SUBSCRIBED_TIMEOUT
      end
    end

    context "active_trial? == true" do
      before do
        user.stubs(:active_trial?).returns(true)
      end

      it "returns the DEFAULT_SUBSCRIBED_TIMEOUT" do
        expect(user.default_worker_timeout(repo)).to eq User::DEFAULT_SUBSCRIBED_TIMEOUT
      end
    end

    context "#subscribed?, #active_trial?, #educational? == false" do
      before do
        user.stubs(:subscribed?).returns(false)
        user.stubs(:active_trial?).returns(false)
        user.stubs(:educational?).returns(false)
        stub_request(:post, authorize_build_url).to_return(
          body: MultiJson.dump(allowed: false, rejection_code: nil)
        )
      end

      it "returns the DEFAULT_SUBSCRIBED_TIMEOUT" do
        expect(user.default_worker_timeout(repo)).to eq User::DEFAULT_SPONSORED_TIMEOUT
      end
    end
  end
end
