module Dpl
  module Providers
    class Render < Provider
      register :render

      status :dev

      full_name 'Render'

      description sq(<<-str)
        tbd
      str

      gem 'json'

      env :render

      opt '--service SERVICE', 'Render service name'
      opt '--api_key KEY', 'Render API key', required: true, secret: true

      msgs invalid_credentials: 'Invalid credentials (%s)',
           unknown_error: 'Error: %s (%s)',
           preparing: 'Retrieving service_id from Render',
           deploying: 'Triggering Render deployment',
           created: 'Render deployment started',
           build_in_progress: 'Render build is in progress',
           update_in_progress: 'Render update is in progress',
           invalid_service: 'Render could not find the requested service',
           failed: 'Render deployment failed'

      attr_reader :data, :service_id

      def prepare
        find_service_id
      end

      def deploy
        trigger_deploy
        verify_deploy
      end

      private

        def find_service_id
          info :preparing
          res = handle_response(get("/v1/services?name=#{service}"))
          error :invalid_service if res.size != 1
          error :invalid_service if res[0][:service][:name] != service
          @service_id = res[0][:service][:id]
        end

        def trigger_deploy
          @data = handle_response(post("/v1/services/#{service_id}/deploys"))
        end

        def build_status
          res = handle_response(get("/v1/services/#{service_id}/deploys/#{deploy_id}"))
          res[:status]
        end

        def verify_deploy
          loop do
            case build_status
            when 'created'
              info :created
              sleep 5
            when 'build_in_progress'
              info :build_in_progress
              sleep 5
            when 'update_in_progress'
              info :update_in_progress
              sleep 5
            when 'live'
              break
            else
              error :failed
            end
          end
        end

        def deploy_id
          data[:id]
        end

        def http
          http = Net::HTTP.new('api.render.com', 443)
          http.use_ssl = true
          http
        end

        def post(path, body = nil)
          req = Net::HTTP::Post.new(path)
          req['Accept'] = "application/json"
          req['Authorization'] = "Bearer #{api_key}"
          req.set_form_data(body) unless body.nil?
          http.request(req)
        end

        def get(path)
          req = Net::HTTP::Get.new(path)
          req['Accept'] = "application/json"
          req['Authorization'] = "Bearer #{api_key}"
          http.request(req)
        end

        def handle_response(res)
          error :invalid_credentials, res.code if res.code == '401'
          error :unknown_error, res.body, res.code unless res.kind_of?(Net::HTTPSuccess)
          symbolize(JSON.parse(res.body))
        end
    end
  end
end
