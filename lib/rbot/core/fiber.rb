#-- vim:sw=2:et
#++
#
# :title: Fiber coroutine plugin
#
# Author:: apoc (Matthias Hecker) <http://apoc.cc>
#
# This plugin provides the wait_for method for plugin actions that
# are mapped with :fiber set to true:
#   
#   plugin.map 'do_something', :fiber => true
#
# Plugin actions are enveloped in a fiber block and might call the
# wait_for method:
#
#   def do_something(m, params)
#     # ...
#     m, params = wait_for 'page_to :page'
#     # ...
#   end
#
# wait_for accepts the same arguments as Plugin#map and Plugin#map!
# except that it adds a :source variable to the mapping options.
# :source can be used to describe the user that should be able to
# resume the fiber.
#
# Implementation Detail:
# It is important to know that all wait_for instances share the
# same message callback that is only differenciated by the template
# that means that you cannot have two wait_for's running using the
# same message templates. Imagine this:
# <user-a> flights tokyo nyc
# <bot> flight 1) ... 2) ... 3) ... (14 more flights, say %more 
#   for more flights)
# <user-b> bookings
# <bot> your bookings: 1) ... 2) ... 3) ... (42 more bookings, say
#   %more for more bookings)
# <user-a> more
# <bot> more bookings: 4) ... 5) ... 6) ...
#
# wait_for waits for user interaction before returning. It accepts
# the same arguments as #map including parameters that are returned
# by wait_for in the second element of the array its returning, the
# first element is the message itself.
#
# wait_for needs a source as first parameter, this specifies the context
# in which the message should be given, for instance only by a user
# (in the same channel or in query)
# by default wait_for reacts for all messages
# wait_for only reacts for messages that are given in the same context,
# that is from the same user in query or in the same channel the original
# message was given
#
#

require 'fiber'

class FiberPlugin < CoreBotModule

  @@root_fiber = Fiber.current

  def initialize
    super

    @resume_condition = {}
  end

  # Yields a fiber, called from within a plugin action.
  #
  # Pauses execution, awaits template command to resume the fiber.
  # Takes the same arguments as Plugin#map and Plugin#map!.
  #
  # source:: Irc::User or Irc::Channel instance, defines which
  #   users can trigger the resuming of the fiber.
  # template:: Message template string, see #map for more
  #   information.
  # opts:: The same options that #map accepts. Except you can
  #   specify an :invalidate option specifing how the fiber should
  #   invalidate.
  #
  # invalidate:: Defaults to :timed, this will invalidate the
  #   fiber after a certain amount of time (customizable by
  #   fiber.invalidate_after)
  #   :next_message This will invalidate the fiber after the
  #   first message received from source, if it doesn't match
  #   the template.
  #
  # Except: no
  #   :fiber or :threaded should be given, a 
  #
  def wait_for(source, template, opts={})
    fiber = Fiber.current
    raise 'tried to yield root fiber!' if fiber == @@root_fiber

    debug 'wait_for yields fiber, register template %s' % template

    debug 'adding resume condition, fiber=%s, source=%s' % [fiber.inspect, source.inspect]

    @resume_condition[[source, template]] = fiber
    if not @handler.has_template? template
      map! template, opts.merge(:fiber => false, 
                                :threaded => false,
                                :action => :fiber_callback)
    end

    Fiber.yield
  end

  def get_resume_fiber(m)
    @resume_condition[[m.channel, m.template.template]] or
      @resume_condition[[m.source, m.template.template]]
  end

  def remove_resume_fiber(fiber)
    @resume_condition.delete_if { |key, value| value == fiber }
  end

  def unmap_template(template)
    @handler.remove_template! template
  end

  # Resumes a fiber if resume conditions are met.
  def fiber_callback(m, params)
    if m.template
      fiber = get_resume_fiber(m)
      if fiber
        m.reply 'fiber found: ' + fiber.inspect
        remove_resume_fiber fiber
        unmap_template(m.template)


        if fiber.alive?
          m.reply 'fiber is also alive, resuming fiber'
          fiber.resume([m, params])
        else
          m.reply 'fiber is not alive'
        end
      elsif   
        #if m.template.options[:invalidate] == :next_message
      else
        m.reply 'fiber not found :('
      end
    end
  end

  # run block in a new fiber
  # also hooks plugin to listen for pattern, this way only plugins
  # that have a action with activated fibers listen to all messages
  #
  def new_fiber
    fiber = Fiber.new { yield }
    fiber.resume
  end

end

FiberPlugin.new

