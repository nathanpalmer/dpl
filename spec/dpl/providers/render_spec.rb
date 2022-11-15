describe Dpl::Providers::Render do
  let(:args) { |e| %w(--api_key key) + args_from_description(e) }
  let(:services) { JSON.dump([{ service: { id: "srv-id", name: "service" }}]) }
  before { stub_request(:get, 'https://api.render.com/v1/services?name=service').and_return(body: services) }
  before { stub_request(:get, 'https://api.render.com/v1/services?name=invalid_service').and_return(body: JSON.dump([])) }
  before { stub_request(:post, 'https://api.render.com/v1/services/srv-id/deploys').and_return(body: JSON.dump({id: "dpl-1"})) }
  before { stub_request(:get, 'https://api.render.com/v1/services/srv-id/deploys/dpl-1').and_return(body: JSON.dump({status: "live"})) }
  before { |c| subject.run if run?(c) }

  describe 'given --service service', record: true do
    it { should have_run '[info] Retrieving service_id from Render' }
    it { should have_run_in_order }

    it { should have_requested :get, 'https://api.render.com/v1/services?name=service' }
    it { should have_requested :post, 'https://api.render.com/v1/services/srv-id/deploys' }
    it { should have_requested :get, 'https://api.render.com/v1/services/srv-id/deploys/dpl-1' }
  end

  describe 'given --service invalid_service', run: false do
    it { expect { subject.run }.to raise_error 'Render could not find the requested service' }
  end

  describe 'with credentials in env vars given --service service', run: false do
    let(:args) { |e| %w() + args_from_description(e) }
    env RENDER_API_KEY: 'key'
    it { expect { subject.run }.to_not raise_error }
  end
end
