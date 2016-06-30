require "pp"
require "rack"
require 'open-uri'
require "logger"

$stdout.sync = true


module Ruboty module Lingr
	def self.log
		
	end

	class Client
		attr_accessor :bot_name, :bot_key

		def initialize options = {}
			options.each do |key, value|
			  instance_variable_set("@#{key}", value)
			end
			yield(self) if block_given?
		end

		def post room, text
			param = {
				room: room,
				bot:  bot_name,
				text: text,
				bot_verifier: bot_key
			}.tap {|p| p[:bot_verifier] = Digest::SHA1.hexdigest(p[:bot] + p[:bot_verifier]) }

			query_string = param.map {|e|
				e.map {|s| ERB::Util.url_encode s.to_s }.join '='
			}.join '&'
			p query_string
			open "http://lingr.com/api/room/say?#{query_string}"
		end
	end
end end

require "json"

module Ruboty module Adapters
	class Lingr < Base
		env :RUBOTY_LINGR_BOT_KEY,  "Lingr bot key."
		env :RUBOTY_LINGR_BOT_NAME, "Lingr bot name."
		env :RUBOTY_LINGR_ENDPOINT, "Lingr bot endpoint(Callback URL). (e.g. '/ruboty/lingr'"

		def run
			Ruboty.logger.info "=== Linger#run ==="
			start_server
		end

		def say msg
			Ruboty.logger.info "=== Linger#say ==="
			Ruboty.logger.info "message : #{msg[:body]}"

			client.post(msg[:original][:message]["room"], msg[:body])
		end

		private
		def start_server
			Rack::Handler::WEBrick.run(Proc.new{ |evn|
				Ruboty.logger.info "=== Linger access ==="
				Ruboty.logger.debug "env : #{env}"

				request = Rack::Request.new(evn)
				result = on_post request
				[200, {"Content-Type" => "text/plain"}, [result]]
			}, { Port: ENV["PORT"] })
		end

		def on_post req
			Ruboty.logger.info "=== Linger#on_post ==="
			Ruboty.logger.debug "request : #{req}"

			return "OK" unless req.post? && req.fullpath == ENV["RUBOTY_LINGR_ENDPOINT"]
			params = JSON.parse req.body.read

			Ruboty.logger.debug "POST params : #{req}"

			return "" unless params.has_key?("events") && params["events"].kind_of?(Array)

			params["events"].select {|e| e['message'] }.map {|e|
				on_message e["message"]
			}
			return ""
		end

		def on_message msg
			Ruboty.logger.info "=== Linger#on_message ==="
			Ruboty.logger.debug "message : #{msg}"

			Thread.start {
				robot.receive(body: msg["text"], message: msg)
			}
		end

		def client
			@client ||= ::Ruboty::Lingr::Client.new({
				bot_name: ::ENV["RUBOTY_LINGR_BOT_NAME"],
				bot_key:  ::ENV["RUBOTY_LINGR_BOT_KEY"],
			})
		end
	end
end end
