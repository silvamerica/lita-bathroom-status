module Lita
  module Handlers
    class BathroomStatus < Handler
      EMOJI_STATES = {
        'open'    => ':green_circle:',
        'closed'  => ':red_circle:',
        'warning' => ':warning:'
      }

      http.post('/bathroom/:id/:state', :handle_post_webhook)
      http.get('/bathrooms', :bathroom_state_endpoint)

      route(/show bathrooms/i, :reply_with_bathroom_state, command: true, help: {
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

      def handle_post_webhook(request, response)
        state = request.env["router.params"][:state]
        id = request.env["router.params"][:id]

        if (state == 'open')
          closed_time = redis.hget(:door_times, id) || Time.now.to_s
          if (Time.now - Time.parse(closed_time)) > 600
            update_state(id, 'warning')
            after(300) { update_state(id, state) }
          else
            update_state(id, state)
          end
        else
          update_state(id, state)
        end


        @adapter ||= robot.send :adapter
        @api ||= Lita::Adapters::Slack::API.new(@adapter.config)
        pinned_message = redis.hgetall(:pinned_message)

        if (!pinned_message.empty?)
          outgoing_params = pinned_message.merge({
            :text => "Bathroom Status:\n" + states
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

      def update_state(id, state)
        redis.hmset(:doors, id, state)
        redis.hmset(:door_times, id, Time.now)
      end

      def states
        states = redis.hgetall(:doors) # {"1" => "open", "2" => "closed"}
        states.map{|k, v| [EMOJI_STATES[v], k + 'F']}.join(' ')
      end

      def now
        Time.now.strftime('%r')
      end
    end

    Lita.register_handler(BathroomStatus)
  end
end
