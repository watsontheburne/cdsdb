
PlayerData = Struct.new(:owner, :internal_ref, :uilink)

class PlayerWindow < TopWindow

    LEVEL_ELEMENT_NAME = "my_level_meter"
    MIN_LEVEL = -80.0  # The scale range will be from this value to 0 dB, has to be negative
    POS_MIN_LEVEL = -1 * MIN_LEVEL
#     INTERVAL = 50000000    # How often update the meter? (in nanoseconds) - 20 times/sec in this case
    INTERVAL = 40000000    # How often update the meter? (in nanoseconds) - 25 times/sec in this case

    METER_WIDTH = 449.0 # Offset start 10 pixels idem end
    IMAGE_WIDTH = 469.0

    ELAPSED   = 0
    REMAINING = 1

    PLAY_STATE_BTN = { false => Gtk::Stock::MEDIA_PLAY, true => Gtk::Stock::MEDIA_PAUSE }

    PREFETCH_SIZE = 2

    Y_OFFSETS = [16, 28]

    LEFT_CHANNEL  = 0
    RIGHT_CHANNEL = 1

    DIGIT_HEIGHT = 20
    DIGIT_WIDTH  = 12


    def initialize(mc)
        super(mc, UIConsts::PLAYER_WINDOW)

        window.signal_connect(:delete_event) do
            stop if playing?
            @mc.notify_closed(self)
            true
        end

        @meter = @mc.glade[UIConsts::PLAYER_IMG_METER]
        @meter.signal_connect(:realize) { |widget| meter_setup }

        @counter = @mc.glade[UIConsts::PLAYER_IMG_COUNTER]
        @counter.signal_connect(:realize) { |widget| counter_setup }

        @mc.glade[UIConsts::PLAYER_BTN_START].signal_connect(:clicked) { on_btn_play }
        @mc.glade[UIConsts::PLAYER_BTN_STOP].signal_connect(:clicked)  { on_btn_stop }
        @mc.glade[UIConsts::PLAYER_BTN_NEXT].signal_connect(:clicked)  { on_btn_next }
        @mc.glade[UIConsts::PLAYER_BTN_PREV].signal_connect(:clicked)  { on_btn_prev }

#         @mc.glade[UIConsts::PLAYER_BTN_SWITCH].signal_connect(:clicked) { on_change_time_view }

#         pstr = '<span font="Pixel LCD7" background="#000000" foreground="#00FF00" size="12288"/>' #12:34-56:78</span>'
#         pfd = Pango::FontDescription.new# ("[FAMILY-LIST]Digital-7 Mono[SIZE]16")
#         pfd.set_family("Digital-7 Mono").set_size(16384)
#         pfd.set_family("Pixel LCD7").set_size(12*1024)
#         pfd.set_family("TPF Display").set_size(14336)
# p pfd
#         @mc.glade[UIConsts::PLAYER_LABEL_POS].modify_font(pfd).queue_resize
#         @mc.glade[UIConsts::PLAYER_LABEL_POS].set_text("12:34-56:78")
#         @mc.glade[UIConsts::PLAYER_LABEL_POS].modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(0, 0, 0))
#         @mc.glade[UIConsts::PLAYER_LABEL_POS].modify_text(Gtk::STATE_NORMAL, Gdk::Color.new(0, 255, 0))
#         @mc.glade[UIConsts::PLAYER_LABEL_POS].modify_text(Gtk::STATE_NORMAL, Gdk::Color.new(0, 255, 0))
#         @mc.glade[UIConsts::PLAYER_LABEL_DURATION].modify_font(pfd).set_text("00:00").queue_resize # markup = '<span font="Digital-7 Mono" size="16384">00:00</span>'
#         @mc.glade[UIConsts::PLAYER_LABEL_POS].set_markup("12:34-56:78").set_attributes(Pango.parse_markup(pstr)[0]).queue_resize
        @mc.glade[UIConsts::PLAYER_LABEL_TITLE].label = ""

        # Intended to be a PlayerData array to pre-fetch tracks to play
        @queue = []

        @file_prefetched = false

        @slider = @mc.glade[UIConsts::PLAYER_HSCALE]

        @time_view_mode = ELAPSED
        @total_time = 0

        # Tooltip cache. Inited when a new track starts.
        @tip_pix = nil

        init_player
    end

    # Build the backgroud image of the level meter when the GTK image is realized
    def meter_setup
        # Get the pixmap from the gtk image on the meter window
        @mpix = Gdk::Pixmap.new(@meter.window, IMAGE_WIDTH, 52, -1) # 52 = 16*2+8*2+1*4

        # Get the image graphic context and set the foreground color to white
        @gc = Gdk::GC.new(@meter.window)

        @std_peak_color = Gdk::Color.new(0xffff, 0xffff, 0xffff)
        @ovr_peak_color = Gdk::Color.new(0xffff, 0x0000, 0x0000)

        # Get the meter image, unlit and lit images from their files
        scale   = Gdk::Pixbuf.new(CFG.icons_dir+"k14-scaleH.png")
        @dark   = Gdk::Pixbuf.new(CFG.icons_dir+"k14-meterH0.png")
        @bright = Gdk::Pixbuf.new(CFG.icons_dir+"k14-meterH1.png")

        # Start splitting the meter image to build the definitive bitmap as the scale image
        # is not the final image onto which we draw
        # draw_pixbuf(gc, pixbuf, src_x, src_y, dest_x, dest_y, width, height, dither, x_dither, y_dither)
        @mpix.draw_pixbuf(nil, scale, 0, 4, 0, 0, 469, 16, Gdk::RGB::DITHER_NONE, 0, 0)

        @mpix.draw_pixbuf(nil, @dark, 0, 0, 0, 16, 469, 8, Gdk::RGB::DITHER_NONE, 0, 0)

        @mpix.draw_pixbuf(nil, scale, 0, 0, 0, 24, 469, 4, Gdk::RGB::DITHER_NONE, 0, 0)

        @mpix.draw_pixbuf(nil, @dark, 0, 0, 0, 28, 469, 8, Gdk::RGB::DITHER_NONE, 0, 0)

        @mpix.draw_pixbuf(nil, scale, 0, 0, 0, 36, 469, 16, Gdk::RGB::DITHER_NONE, 0, 0)
        # At this point, @mpix contains the definitive bitmap

        # Draw the bitmap on screen
        @meter.set(@mpix, nil)
    end

    def reset_counter
        11.times do |i|
            if i == 2 || i == 8
                @dpix.draw_pixbuf(nil, @digits[11], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            elsif i == 5
                @dpix.draw_pixbuf(nil, @digits[12], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            else
                @dpix.draw_pixbuf(nil, @digits[10], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            end
        end
        @counter.set(@dpix, nil)
    end

    def time_to_digits(stime)
        i = 0
        stime.each_byte do |ch|
            if i == 2 || i == 8
                @dpix.draw_pixbuf(nil, @digits[11], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            elsif i == 5
                @dpix.draw_pixbuf(nil, @digits[12], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            elsif (i == 0 || i == 6 || i == 7) && ch == 48
                @dpix.draw_pixbuf(nil, @digits[10], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            else
                @dpix.draw_pixbuf(nil, @digits[ch-48], 0, 0, i*DIGIT_WIDTH, 0, DIGIT_WIDTH, DIGIT_HEIGHT, Gdk::RGB::DITHER_NONE, 0, 0)
            end
            i += 1
        end
        @counter.set(@dpix, nil)
    end

    def counter_setup
        @dpix = Gdk::Pixmap.new(@counter.window, 11*DIGIT_WIDTH, DIGIT_HEIGHT, -1)

        @digits = []
        10.times { |i| @digits[i] = Gdk::Pixbuf.new(CFG.icons_dir+"#{i}digit.png", DIGIT_WIDTH, DIGIT_HEIGHT) }
        @digits[10] = Gdk::Pixbuf.new(CFG.icons_dir+"unlitdigit.png", DIGIT_WIDTH, DIGIT_HEIGHT)
        @digits[11] = Gdk::Pixbuf.new(CFG.icons_dir+"colondigit.png", DIGIT_WIDTH, DIGIT_HEIGHT)
        @digits[12] = Gdk::Pixbuf.new(CFG.icons_dir+"minusdigit.png", DIGIT_WIDTH, DIGIT_HEIGHT)

        reset_counter
        @counter.set(@dpix, nil)
    end

    def on_change_time_view
        @time_view_mode = @time_view_mode == ELAPSED ? REMAINING : ELAPSED
        update_hscale
    end

    def set_window_title
        msg = case @playbin.get_state[1]
            when Gst::STATE_PLAYING then "Playing"
            when Gst::STATE_PAUSED  then "Paused"
            else "Stopped"
        end
        window.title = "Player - [#{msg}]"
    end

    def reset_player(notify)
        @tip_pix = nil

        if notify
            TRACE.debug("[nil]".red)
            if CFG.notifications?
                system("notify-send -t #{(CFG.notif_duration*1000).to_s} -i #{IMG_CACHE.default_record_file} 'CDs DB' 'End of play list'")
            end
        end

        # Reset button states
        @mc.glade[UIConsts::PLAYER_BTN_START].stock_id = Gtk::Stock::MEDIA_PLAY
        @seeking = false
        set_window_title
        @mc.glade[UIConsts::TTPM_ITEM_PLAY].sensitive = true
        @mc.glade[UIConsts::TTPM_ITEM_PAUSE].sensitive = false
        @mc.glade[UIConsts::TTPM_ITEM_STOP].sensitive = false

        # Clear level meter
        @mpix.draw_pixbuf(nil, @dark, 0, 0, 0, 16, 469, 8, Gdk::RGB::DITHER_NONE, 0, 0)
        @mpix.draw_pixbuf(nil, @dark, 0, 0, 0, 28, 469, 8, Gdk::RGB::DITHER_NONE, 0, 0)
        @meter.set(@mpix, nil)

        # Clear title, time and slider
        reset_counter
        @mc.glade[UIConsts::PLAYER_LABEL_TITLE].label = ""
#         @mc.glade[UIConsts::PLAYER_LABEL_POS].set_text("00:00-00:00")
#         @mc.glade[UIConsts::PLAYER_LABEL_POS].modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(0, 0, 0))
#         @mc.glade[UIConsts::PLAYER_LABEL_POS].modify_text(Gtk::STATE_NORMAL, Gdk::Color.new(0, 255, 0))
        @slider.value = 0.0
    end

    def on_btn_play
        if playing? || paused?
            playing? ? @playbin.pause : @playbin.play
            @mc.glade[UIConsts::PLAYER_BTN_START].stock_id = PLAY_STATE_BTN[playing?]
            @mc.glade[UIConsts::TTPM_ITEM_PLAY].sensitive = paused?
            @mc.glade[UIConsts::TTPM_ITEM_PAUSE].sensitive = playing?
            @mc.glade[UIConsts::TTPM_ITEM_STOP].sensitive = true
        else
            new_track(:start)
        end
        set_window_title
    end

    def on_btn_stop
        return unless playing? || paused?
        stop
        @queue[0].owner.notify_played(@queue[0], :stop)
        reset_player(false)
        @queue.clear
        @file_prefetched = false
    end

    def on_btn_next
        return if !playing? || paused? || !@queue[1]
        stop
        new_track(:next)
    end

    def on_btn_prev
        return if !playing? || paused? || !@queue[0].owner.has_track(@queue[0], :prev)
        stop
        new_track(:prev)
    end

    def play_track(player_data)
        # The status cache prevent the file name to be reloaded when selection is changed
        # in the track browser. So, from now, we may receive an empty file name but the
        # status is valid. If audio link is OK, we just have to find the file name for the track.

        # Not sure it's still true... Anyway, the caller MUST give a valid file to play, that's all!
        if player_data.uilink.audio_file.empty? #&& player_data.uilink.playable?
            player_data.uilink.setup_audio_file
            # player_data.uilink.search_audio_file
TRACE.debug("Player audio file was empty!".red)
        end

        # Restart player as soon as possible

        # Can't use replay gain if track has been dropped.
        # Replay gain should work if tags are set in the audio file
        if player_data.uilink.tags.nil?
            if player_data.uilink.use_record_gain? && @mc.glade[UIConsts::MM_PLAYER_USERECRG].active?
                @rgain.fallback_gain = player_data.uilink.record.fgain
TRACE.debug("RECORD gain: #{player_data.uilink.record.fgain}".brown)
            elsif @mc.glade[UIConsts::MM_PLAYER_USETRKRG].active?
                @rgain.fallback_gain = player_data.uilink.track.fgain
TRACE.debug("TRACK gain #{player_data.uilink.track.fgain}".brown)
            else
                @rgain.fallback_gain = 0.0
            end
        end

        @playbin.clear
        @playbin.add(@source, @decoder, @convertor, @level, @rgain, @sink)

        @source >> @decoder

        @source.location = player_data.uilink.audio_file
        @playbin.play

        @was_playing = false # Probably useless


        # Debug info
        info = player_data.uilink.tags.nil? ? "[#{player_data.uilink.track.rtrack}" : "[dropped"
        TRACE.debug((info+", #{player_data.uilink.audio_file}]").cyan)

        # UI operations may be delayed
        @tip_pix = nil
        setup_hscale

        player_data.owner.started_playing(player_data)

        @mc.glade[UIConsts::PLAYER_LABEL_TITLE].label = player_data.uilink.html_track_title_no_track_num(false, " ")
        @mc.glade[UIConsts::PLAYER_BTN_START].stock_id = Gtk::Stock::MEDIA_PAUSE
        @mc.glade[UIConsts::TTPM_ITEM_PLAY].sensitive = false
        @mc.glade[UIConsts::TTPM_ITEM_PAUSE].sensitive = true
        @mc.glade[UIConsts::TTPM_ITEM_STOP].sensitive = true
        if CFG.notifications?
            file_name = player_data.uilink.cover_file_name
            system("notify-send -t #{(CFG.notif_duration*1000).to_s} -i #{file_name} 'CDs DB now playing' \"#{player_data.uilink.html_track_title(true)}\"")
        end
    end

    def debug_queue
        puts("Queue: #{@queue.size} entries:")
        @queue.each { |entry| puts("  "+entry.uilink.track.stitle) }
    end

    def new_track(msg)
start = Time.now.to_f

        if msg == :stream_ended
            @queue[1] ? play_track(@queue[1]) : reset_player(true)
TRACE.debug("Elapsed: #{Time.now.to_f-start}")
            @queue[0].owner.notify_played(@queue[0], @queue[1].nil? ? :finish : :next)
            @mc.notify_played(@queue[0].uilink)
            @queue.shift # Remove first entry, no more needed
        else
            case msg
                when :next
                    # We know it's not the last track because :next is not sent if no more track
                    @queue[0].owner.notify_played(@queue[0], :next)
                    @queue.shift
                when :prev
                    @queue[0] = @queue[0].owner.get_track(@queue[0], :prev)
                    @queue.slice!(1, PREFETCH_SIZE) # Remove all entries after the first one
                when :start
                    @queue[0] = @mc.get_track(nil, :start)
            end

            # queue[0] may be nil only if play button is pressed while there's nothing to play
            play_track(@queue[0]) if @queue[0]
        end

        @queue.compact! # Remove nil entries
        @queue[0].owner.prefetch_tracks(@queue, PREFETCH_SIZE) if @queue[0]

        @file_prefetched = false
    end

    # Called by mc if any change made in the provider track list
    def refetch(track_provider)
        if @queue[0] && track_provider == @queue[0].owner
            @queue.slice!(1, PREFETCH_SIZE) # Remove all entries after the first one
            track_provider.prefetch_tracks(@queue, PREFETCH_SIZE)
        end
    end

    # Provider has been closed so remove all its remaining entries
    def unfetch(track_provider)
        @queue.slice!(1, PREFETCH_SIZE) if @queue[0] && track_provider == @queue[0].owner
    end

    def draw_level(msg_struct, channel)
        rms  = msg_struct["rms"][channel]
        peak = msg_struct["decay"][channel]


        rms = rms > MIN_LEVEL ? (METER_WIDTH*rms / POS_MIN_LEVEL).to_i+METER_WIDTH : 0

        peak = peak > MIN_LEVEL ? (METER_WIDTH*peak / POS_MIN_LEVEL).to_i+METER_WIDTH : 0
        if peak >= METER_WIDTH
            peak = METER_WIDTH-1
            @gc.set_rgb_fg_color(@ovr_peak_color)
        else
            @gc.set_rgb_fg_color(@std_peak_color)
        end

        # draw_pixbuf Proto:
        #       draw_pixbuf(gc, copied pixbuf,
        #                   copied pixbuf src_x, copied pixbuf src_y,
        #                   dest (self) dest_x, dest (self) dest_y,
        #                   width, height, dither, x_dither, y_dither)

        # Draws the lit part from zero upto the rms level
        @mpix.draw_pixbuf(nil, @bright,
                          10,  0,
                          10,  Y_OFFSETS[channel],
                          rms, 8,
                          Gdk::RGB::DITHER_NONE, 0, 0)
        # Draws the unlit part from rms level to the end
        @mpix.draw_pixbuf(nil, @dark,
                          rms+11,            0,
                          rms+11,            Y_OFFSETS[channel],
                          METER_WIDTH-rms+1, 8,
                          Gdk::RGB::DITHER_NONE, 0, 0)

        @mpix.draw_rectangle(@gc, true, peak+9, Y_OFFSETS[channel], 2, 8) if peak > 9
    end

    def init_player
        @seeking = false

        @playbin = Gst::Pipeline.new("levelmeter")

        @playbin.bus.add_watch do |bus, message|
            case message.type
                when Gst::Message::Type::ELEMENT
                    if message.source.name == LEVEL_ELEMENT_NAME
                        draw_level(message.structure, LEFT_CHANNEL)
                        draw_level(message.structure, RIGHT_CHANNEL)

                        @meter.set(@mpix, nil)
                    end
                when Gst::Message::EOS
                    stop
                    new_track(:stream_ended)
                when Gst::Message::ERROR
                    stop
            end
            true
        end

        @track_pos = Gst::QueryPosition.new(Gst::Format::TIME)
        @slider.signal_connect(:button_press_event) do
            @seeking = true
            @was_playing = playing?
            @playbin.pause if playing?
            false # Means the parent handler has to be called
        end
        @slider.signal_connect(:button_release_event) do
            @seeking = false
            seek_set
            @playbin.play if @was_playing
            false # Means the parent handler has to be called
        end
        @seek_handler = @slider.signal_connect(:value_changed) { seek if @seeking; false }
            #seek((@slider.value * Gst::MSECOND).to_i)
            #false
        #}
        #@seek_handler = @slider.signal_connect(:value_changed) { puts @slider.value.to_s; seek_set; seek; }

        @convertor = Gst::ElementFactory.make("audioconvert")

        @level = Gst::ElementFactory.make("level", LEVEL_ELEMENT_NAME)
        @level.interval = INTERVAL
        @level.message = true
        @level.peak_falloff = 100
        @level.peak_ttl = 200000000

        @rgain = Gst::ElementFactory.make("rgvolume")

        @sink = Gst::ElementFactory.make("autoaudiosink")

        @decoder = Gst::ElementFactory.make("decodebin")
        @decoder.signal_connect(:new_decoded_pad) { |dbin, pad, is_last|
            pad.link(@convertor.get_pad("sink"))
            if @mc.glade[UIConsts::MM_PLAYER_LEVELBEFORERG].active?
                @convertor >> @level >> @rgain >> @sink
            else
                @convertor >> @rgain >> @level >> @sink
            end
        }

        @source = Gst::ElementFactory.make("filesrc")
    end

    def setup_hscale
        sleep(0.01) while not playing? # We're threaded and async

        track_len = Gst::QueryDuration.new(Gst::Format::TIME)
        @playbin.query(track_len)
        @total_time = track_len.parse[1].to_f/Gst::MSECOND
        @slider.set_range(0.0, @total_time)
        @total_time = @total_time.to_i
#         @mc.glade[UIConsts::PLAYER_LABEL_DURATION].label = format_time(@total_time)

        @playbin.query(@track_pos)
        #@mc.glade[UIConsts::PLAYER_HSCALE].set_range(0.0, track_len.parse[1].to_f/Gst::MSECOND)
        #@slider.update_policy = Gtk::UPDATE_DISCONTINUOUS
#        duration = track_len.parse[1].to_f/Gst::MSECOND
#         @mc.glade[UIConsts::PLAYER_HSCALE].adjustment = Gtk::Adjustment.new(0.0,
#                                                                             0.0, duration,
#                                                                             duration/100.0,
#                                                                             duration/10.0, duration/1000.0)
#         @mc.glade[UIConsts::PLAYER_HSCALE].adjustment = Gtk::Adjustment.new(0.0,
#                                                                             0.0, duration,
#                                                                             0.0, # step inc duration/100.0,
#                                                                             duration/10.0, # page inc
#                                                                             0.0) # page size

        @timer = Gtk::timeout_add(500) { update_hscale; true }
    end

    def update_hscale
        return if @seeking || (!playing? && !paused?)

        @playbin.query(@track_pos)

        itime = (@track_pos.parse[1].to_f/Gst::MSECOND).to_i
        #@slider.signal_handler_block(@seek_handler)
        @slider.value = itime #@track_pos.parse[1].to_f/Gst::MSECOND
        #@slider.signal_handler_unblock(@seek_handler)

        show_time(itime)

        @queue[0].owner.timer_notification(itime)

        # If there's a next playable track in queue, read the whole file in an attempt to make
        # it cached by the system and lose less time when skipping to it
        if @queue[1] && !@file_prefetched && @total_time-itime < 10000 && @queue[1].uilink.playable?
            IO.read(@queue[1].uilink.audio_file)
            @file_prefetched = true
            TRACE.debug("Prefetch of #{@queue[1].uilink.audio_file}".brown)
        end
    end

    def seek_set
        @playbin.seek(1.0, Gst::Format::Type::TIME,
                      Gst::Seek::FLAG_FLUSH.to_i |
                      Gst::Seek::FLAG_KEY_UNIT.to_i,
                      Gst::Seek::TYPE_SET,
                      (@slider.value * Gst::MSECOND).to_i,
                      Gst::Seek::TYPE_NONE, -1)
        # Wait at most 100 miliseconds for a state changes, this throttles the seek
        # events to ensure the playbin can keep up
        @playbin.get_state(100 * Gst::MSECOND)
    end

    def seek
        show_time(@slider.value)
    end

    def show_time(itime)
        if @time_view_mode == ELAPSED
            time_to_digits(format_time(@total_time)+"-"+format_time(itime))
#             @mc.glade[UIConsts::PLAYER_LABEL_POS].set_text(format_time(@total_time)+"-"+format_time(itime))
#             @mc.glade[UIConsts::PLAYER_LABEL_POS].label = format_time(itime)
#             @mc.glade[UIConsts::PLAYER_LABEL_POS].markup = '<span font="Digital-7 Mono" size="16384">00:00</span>'.sub(/00:00/, format_time(itime))

        else
            @mc.glade[UIConsts::PLAYER_LABEL_POS].label = "-"+format_time(@total_time-itime)
        end
    end

    def format_time(itime)
        return sprintf("%02d:%02d", itime/60000, (itime % 60000)/1000)
    end

    def stop
        @playbin.stop
        Gtk::timeout_remove(@timer)
    end

    def show_tooltip(si, tool_tip)
        @tip_pix = @queue[0].uilink.large_track_cover if @tip_pix.nil?
        tool_tip.set_icon(@tip_pix)
        text = @queue[0].uilink.html_track_title(true)+"\n\n"+format_time(@slider.value)+" / "+@mc.glade[UIConsts::PLAYER_LABEL_DURATION].label
        tool_tip.set_markup(text)
    end

    def playing?
        @playbin.get_state[1] == Gst::STATE_PLAYING
    end

    def paused?
        @playbin.get_state[1] == Gst::STATE_PAUSED
    end

end
