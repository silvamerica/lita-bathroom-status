module Lita
  module Handlers
    class BathroomStatus < Handler
      http.post('/bathroom/:id/:state', :update_state)
      http.get('/bathrooms', :bathroom_state_endpoint)

      route('show bathrooms', :reply_with_bathroom_state, command: true, help: {
        "bathrooms" => "Shows the state of bathrooms."
        })
      route('pin bathrooms here', :reply_and_save_message_location, command: true)

      def reply_and_save_message_location(response)
        room = response.message.source.room
        @adapter ||= robot.send :adapter
        @api ||= Lita::Adapters::Slack::API.new(@adapter.config)
        outgoing_params = {:channel => room, :text => "Bathroom Status:\n" + states, :as_user => true}
        message = @api.send :call_api, 'chat.postMessage', outgoing_params

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

      def bathroom_state_endpoint(request, response)
        response.write("Bathroom Status as of #{now}:\n" + states)
      end

      def reply_with_bathroom_state(response)
        response.reply("Bathroom Status as of #{now}:\n" + states)
      end

      def states
        states = redis.hgetall(:doors) # {"1" => "open", "2" => "closed"}
        string = states.map{|k, v| [(v == "open" ? ':green_circle:' : ':red_circle:'), k + 'F']}.join(' ')
      end

      def now
        Time.now.strftime('%r')
      end
    end

    Lita.register_handler(BathroomStatus)
  end
end
