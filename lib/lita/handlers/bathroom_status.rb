module Lita
  module Handlers
    class BathroomStatus < Handler
      http.get('/bathroom/:id/:state', :update_state)
      route('show bathrooms', :post_state, command: true, help: {
        "bathrooms" => "Shows the state of bathrooms."
        })
      route('pin bathrooms here', :post_fixed_state, command: true)

      def post_fixed_state(response)
        room = response.message.source.room
        @adapter ||= robot.send :adapter
        @api ||= Lita::Adapters::Slack::API.new(@adapter.config)
        outgoing_params = {:channel => room, :text => states, :as_user => true}
        message = @api.send :call_api, 'chat.postMessage', outgoing_params

        Lita.logger.info(message.inspect)
        redis.hmset(:pinned_message, :channel, room, :ts, message["ts"])
      end

      def update_state(request, response)
        state = request.env["router.params"][:state]
        id = request.env["router.params"][:id]

        redis.hmset(:doors, id, state)

        @adapter ||= robot.send :adapter
        @api ||= Lita::Adapters::Slack::API.new(@adapter.config)
        pinned_message = redis.hgetall(:pinned_message)

        if (pinned_message)
          outgoing_params = pinned_message.merge({
            :text => states
          })
          @message = @api.send :call_api, 'chat.update', outgoing_params
        end
      end

      def post_state(response)
        response.reply(string)
      end

      def states
        states = redis.hgetall(:doors) # {"1" => "open", "2" => "closed"}
        string = states.map{|k, v| [(v == "open" ? ':green_circle:' : ':red_circle:'), 'F' + k]}.join(' ')
      end
    end

    Lita.register_handler(BathroomStatus)
  end
end
