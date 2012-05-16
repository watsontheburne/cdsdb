
#
#
# The master controller class is responsible for handling events from the main menu.
#
# It defers the execution of events to the treeviews when possible doing it itself otherwise.
#
# It passes itself as parameter to the treeviews and permanent windows giving them
# access to needed attributes, mainly glade and main_filter.
#
# It has messages to get the reference to each browser current selection thus acting
# as a pivot for inter-browser dialogs.
#
#

class MasterController

    attr_reader   :glade, :plists, :pqueue, :tasks, :filter, :main_filter
    attr_accessor :filter_receiver


    def initialize(path_or_data, root, domain)
        #@glade = GladeXML.new(path_or_data, root, domain, nil, GladeXML::FILE) { |handler| method(handler) }
        @glade = GTBld.main


        @st_icon = Gtk::StatusIcon.new
        @st_icon.stock = Gtk::Stock::CDROM
        if @st_icon.respond_to?(:has_tooltip=) # To keep compat with gtk2 < 2.16
            @st_icon.has_tooltip = true
            #@st_icon.signal_connect('activate'){|icon| icon.blinking=!(icon.blinking?)}
            @st_icon.signal_connect(:query_tooltip) { |si, x, y, is_kbd, tool_tip| show_tooltip(si, x, y, is_kbd, tool_tip); true }
        end
        @st_icon.signal_connect(:popup_menu) { |tray, button, time|
            @glade[UIConsts::TTPM_MENU].popup(nil, nil, button, time) { |menu, x, y, push_in| @st_icon.position_menu(menu) }
        }

        # SQL AND/OR clause reflecting the filter settings that must be appended to the sql requests
        # if view is filtered
        @main_filter = ""

        # Var de merde pour savoir d'ou on a clique pour avoir le popup contenant tags ou rating
        # L'owner est donc forcement le treeview des records ou celui des tracks
        # ... En attendant de trouver un truc plus elegant
        @pm_owner = nil


        # Set cd image to default image
        @glade[UIConsts::REC_IMAGE].pixbuf = IconsMgr::instance.get_cover(0, 0, 0, 128)

        Gtk::IconTheme.add_builtin_icon("player_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"player.png"))
        Gtk::IconTheme.add_builtin_icon("pqueue_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"pqueue.png"))
        Gtk::IconTheme.add_builtin_icon("plists_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"plists.png"))
        Gtk::IconTheme.add_builtin_icon("charts_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"charts.png"))
        @glade[UIConsts::MW_TBBTN_PLAYER].icon_name = "player_icon"
        @glade[UIConsts::MW_TBBTN_PQUEUE].icon_name = "pqueue_icon"
        @glade[UIConsts::MW_TBBTN_PLISTS].icon_name = "plists_icon"
        @glade[UIConsts::MW_TBBTN_CHARTS].icon_name = "charts_icon"

        Gtk::IconTheme.add_builtin_icon("information_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"information.png"))
        Gtk::IconTheme.add_builtin_icon("tasks_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"tasks.png"))
        Gtk::IconTheme.add_builtin_icon("filter_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"filter.png"))
        Gtk::IconTheme.add_builtin_icon("memos_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"document-edit.png"))
#         Gtk::IconTheme.add_builtin_icon("audio_cd_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"audio-cd.png"))
#         Gtk::IconTheme.add_builtin_icon("import_sql_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"import-sql.png"))
#         Gtk::IconTheme.add_builtin_icon("import_audio_icon", 22, UIUtils::get_btn_icon(Cfg::instance.icons_dir+"import-audio.png"))
        @glade[UIConsts::MW_TBBTN_APPFILTER].icon_name  = "information_icon"
        @glade[UIConsts::MW_TBBTN_TASKS].icon_name  = "tasks_icon"
        @glade[UIConsts::MW_TBBTN_FILTER].icon_name = "filter_icon"
        @glade[UIConsts::MW_TBBTN_MEMOS].icon_name  = "memos_icon"


        # Connect signals needed to restore windows positions
        @glade[UIConsts::MW_PLAYER_ACTION].signal_connect(:activate) { toggle_window_visibility(@player) }
        @glade[UIConsts::MW_PQUEUE_ACTION].signal_connect(:activate) { toggle_window_visibility(@pqueue) }
        @glade[UIConsts::MW_PLISTS_ACTION].signal_connect(:activate) { toggle_window_visibility(@plists) }
        @glade[UIConsts::MW_CHARTS_ACTION].signal_connect(:activate) { toggle_window_visibility(@charts) }
        @glade[UIConsts::MW_TASKS_ACTION].signal_connect(:activate)  { toggle_window_visibility(@tasks ) }
        @glade[UIConsts::MW_FILTER_ACTION].signal_connect(:activate) { toggle_window_visibility(@filter) }
        @glade[UIConsts::MW_MEMOS_ACTION].signal_connect(:activate)  { toggle_window_visibility(@memos)  }

        # Action called from the memos window, equivalent to File/Save of the main window
        @glade[UIConsts::MW_MEMO_SAVE_ACTION].signal_connect(:activate) { on_save_item  }

        # Load view menu before instantiating windows (plists case)
        Prefs::instance.load_menu_state(self, @glade[UIConsts::VIEW_MENU])

        # For filter, force it to be unchecked and connect signal after
#         @glade[UIConsts::MW_APPFILTER_ACTION].active = false
#         @glade[UIConsts::MW_APPFILTER_ACTION].signal_connect(:activate)  { set_main_filter }
        
        #
        # Create never destroyed windows
        #
        @pqueue   = PQueueWindow.new(self)
        @player   = PlayerWindow.new(self)
        @plists   = PListsWindow.new(self)
        @charts   = ChartsWindow.new(self)
        @tasks    = TasksWindow.new(self)
        @filter   = FilterWindow.new(self)
        @memos    = MemosWindow.new(self)

        # Set windows icons
        @pqueue.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"pqueue.png")
        @player.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"player.png")
        @plists.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"plists.png")
        @charts.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"charts.png")
        @tasks.window.icon  = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"tasks.png")
        @filter.window.icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"filter.png")
        @memos.window.icon  = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"document-edit.png")

        # Reload windows state from the last session BEFORE connecting signals
        Prefs::instance.load_menu_state(self, @glade[UIConsts::MM_WIN_MENU])


        #
        # Toute la plomberie incombant au master controller...
        #
        @glade[UIConsts::MM_FILE_CHECKCD].signal_connect(:activate)     { CDEditorWindow.new.edit_record }
        @glade[UIConsts::MM_FILE_IMPORTSQL].signal_connect(:activate)   { import_sql_file }
        @glade[UIConsts::MM_FILE_IMPORTAUDIO].signal_connect(:activate) { on_import_audio_file }
        #@glade[UIConsts::MM_FILE_SAVE].signal_connect(:activate)        { on_save_item }
        @glade[UIConsts::MM_FILE_QUIT].signal_connect(:activate)        { clean_up; Gtk.main_quit }

        @glade[UIConsts::MM_EDIT_SEARCH].signal_connect(:activate)      { SearchDialog.new(self).run }
        @glade[UIConsts::MM_EDIT_PREFS].signal_connect(:activate)       { PrefsDialog.new.run; @tasks.check_config }


        @glade[UIConsts::MM_VIEW_BYRATING].signal_connect(:activate) { record_changed   }
        @glade[UIConsts::MM_VIEW_COMPILE].signal_connect(:activate)  { change_view_mode }
        @glade[UIConsts::MM_VIEW_DBREFS].signal_connect(:activate)   { set_dbrefs_visibility }

        @glade[UIConsts::MM_WIN_RECENT].signal_connect(:activate) { RecentRecordsDialog.new(self, 0).run }
        @glade[UIConsts::MM_WIN_RIPPED].signal_connect(:activate) { RecentRecordsDialog.new(self, 1).run }
        @glade[UIConsts::MM_WIN_PLAYED].signal_connect(:activate) { RecentTracksDialog.new(self, 0).run }
        @glade[UIConsts::MM_WIN_OLDEST].signal_connect(:activate) { RecentTracksDialog.new(self, 1).run }

        @glade[UIConsts::MM_TOOLS_SEARCH_ORPHANS].signal_connect(:activate)     {
            Utils::search_for_orphans(UIUtils::select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER) {
                Gtk.main_iteration while Gtk.events_pending?
            } )
        }
        @glade[UIConsts::MM_TOOLS_TAG_GENRE].signal_connect(:activate)          { on_tag_dir_genre }
        @glade[UIConsts::MM_TOOLS_SCANAUDIO].signal_connect(:activate)          { Utils::scan_for_audio_files(@glade["main_window"]) }
        @glade[UIConsts::MM_TOOLS_IMPORTPLAYEDTRACKS].signal_connect(:activate) { UIUtils::import_played_tracks }
        @glade[UIConsts::MM_TOOLS_SYNCSRC].signal_connect(:activate)            { on_update_sources }
        @glade[UIConsts::MM_TOOLS_SYNCDB].signal_connect(:activate)             { on_update_db }
        @glade[UIConsts::MM_TOOLS_SYNCRES].signal_connect(:activate)            { on_update_resources }
        @glade[UIConsts::MM_TOOLS_EXPORTDB].signal_connect(:activate)           { Utils::export_to_xml }
        @glade[UIConsts::MM_TOOLS_GENREORDER].signal_connect(:activate)         { DBReorderer.new.run }
        @glade[UIConsts::MM_TOOLS_RATINGSTEST].signal_connect(:activate)        { Utils::test_ratings }
        @glade[UIConsts::MM_TOOLS_FULLSTATS].signal_connect(:activate)          { Stats.new(self).generate_stats }
        @glade[UIConsts::MM_TOOLS_DBSTATS].signal_connect(:activate)            { Stats.new(self).db_stats }
        @glade[UIConsts::MM_TOOLS_CHARTS].signal_connect(:activate)             { Stats.new(self).top_charts }
        @glade[UIConsts::MM_TOOLS_PLAYHISTORY].signal_connect(:activate)        { Stats.new(self).play_history }
        @glade[UIConsts::MM_TOOLS_RATINGS].signal_connect(:activate)            { Stats.new(self).ratings_stats }

        @glade[UIConsts::MM_ABOUT].signal_connect(:activate) { Credits::show_credits }

        @glade[UIConsts::REC_VP_IMAGE].signal_connect("button_press_event") { zoom_rec_image }

#        @glade[UIConsts::MW_TBBTN_INFOS].signal_connect(:clicked)      { show_informations }
#         @glade[UIConsts::MW_TBBTN_CHECKCD].signal_connect(:clicked)    { CDEditorWindow.new.edit_record }
#         @glade[UIConsts::MW_TBBTN_IMPORTSQL].signal_connect(:clicked)  { @glade[UIConsts::MM_FILE_IMPORTSQL].send(:activate) }
#         @glade[UIConsts::MW_TBBTN_IMPORTFILE].signal_connect(:clicked) { @glade[UIConsts::MM_FILE_IMPORTAUDIO].send(:activate) }


        @glade[UIConsts::MAIN_WINDOW].signal_connect(:destroy)      { Gtk.main_quit }
        @glade[UIConsts::MAIN_WINDOW].signal_connect(:delete_event) { clean_up; false }
        @glade[UIConsts::MAIN_WINDOW].signal_connect(:show)         { Prefs::instance.load_main(@glade, UIConsts::MAIN_WINDOW) }

        # It took me ages to research this (copied as it from a pyhton forum!!!! me too!!!!)
        @glade[UIConsts::MAIN_WINDOW].add_events( Gdk::Event::FOCUS_CHANGE) # It took me ages to research this
        @glade[UIConsts::MAIN_WINDOW].signal_connect("focus_in_event") { |widget, event| @filter_receiver = self; false }
        
        # Status icon popup menu
        @glade[UIConsts::TTPM_ITEM_PLAY].signal_connect(:activate)  { @glade[UIConsts::PLAYER_BTN_START].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_PAUSE].signal_connect(:activate) { @glade[UIConsts::PLAYER_BTN_START].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_STOP].signal_connect(:activate)  { @glade[UIConsts::PLAYER_BTN_STOP].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_PREV].signal_connect(:activate)  { @glade[UIConsts::PLAYER_BTN_PREV].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_NEXT].signal_connect(:activate)  { @glade[UIConsts::PLAYER_BTN_NEXT].send(:clicked) }
        @glade[UIConsts::TTPM_ITEM_QUIT].signal_connect(:activate)  { @glade[UIConsts::MM_FILE_QUIT].send(:activate) }


        dragtable = [ ["text/uri-list", Gtk::Drag::TargetFlags::OTHER_APP, 105] ] #, #DragType::URI_LIST],
                      #["image/jpeg", Gtk::Drag::TargetFlags::OTHER_APP, 106] ] #DragType::URI_LIST] ]
        @ri = @glade[UIConsts::REC_VP_IMAGE]
        Gtk::Drag::dest_set(@ri, Gtk::Drag::DEST_DEFAULT_ALL, dragtable, Gdk::DragContext::ACTION_COPY)
        @ri.signal_connect(:drag_data_received) { |widget, context, x, y, data, info, time| on_urls_received(widget, context, x, y, data, info, time) }

        #
        # Generate the submenus for the tags and ratings of the records and tracks popup menus
        # One of worst piece of code ever seen!!!
        #
        #UIConsts::RATINGS.each { |rating| iter = @glade[UIConsts::TRK_CMB_RATING].model.append; iter[0] = rating }

        rating_sm = Gtk::Menu.new
        UIConsts::RATINGS.each { |rating|
            item = Gtk::MenuItem.new(rating, false)
            item.signal_connect(:activate) { |widget| on_set_rating(widget) }
            rating_sm.append(item)
        }
        @glade[UIConsts::REC_POPUP_RATING].submenu = rating_sm
        @glade[UIConsts::TRK_POPUP_RATING].submenu = rating_sm
        rating_sm.show_all

        @tags_handlers = []
        tags_sm = Gtk::Menu.new
        UIConsts::TAGS.each { |tag|
            item = Gtk::CheckMenuItem.new(tag, false)
            @tags_handlers << item.signal_connect(:activate) { |widget| on_set_tags(widget) }
            tags_sm.append(item)
        }
        @glade[UIConsts::REC_POPUP_TAGS].submenu = tags_sm
        @glade[UIConsts::TRK_POPUP_TAGS].submenu = tags_sm
        tags_sm.show_all

        # Disable sensible controls if not in admin mode
        UIConsts::ADMIN_CTRLS.each { |control| @glade[control].sensitive = false } unless Cfg::instance.admin?

        #
        # Setup the treeviews
        #
        @art_browser = ArtistsBrowser.new(self).setup
        @rec_browser = RecordsBrowser.new(self).setup
        @trk_browser = TracksBrowser.new(self).setup

        # Load artists entries
        @art_browser.load_entries

        # At least, we're ready to go!
        @glade[UIConsts::MAIN_WINDOW].icon = Gdk::Pixbuf.new(Cfg::instance.icons_dir+"audio-cd.png")
        @glade[UIConsts::MAIN_WINDOW].show
    end

    #
    # Save windows positions, windows states and clean up the client music cache
    #
    def clean_up
        @player.stop if @player.playing? || @player.paused?
        Prefs::instance.save_window(@glade[UIConsts::MAIN_WINDOW])
        Prefs::instance.save_menu_state(self, @glade[UIConsts::VIEW_MENU])
        Prefs::instance.save_menu_state(self, @glade[UIConsts::MM_WIN_MENU])
        [@plists, @player, @pqueue, @charts, @filter, @tasks, @memos].each { |tw| tw.hide if tw.window.visible? }
        #system("rm -f ../mfiles/*")
    end

    #
    # Set the check item to false to really close the window
    #
    def notify_closed(window)
        @glade[UIConsts::MM_WIN_PLAYER].active = false if window == @player
        @glade[UIConsts::MM_WIN_PLAYQUEUE].active = false if window == @pqueue
        @glade[UIConsts::MM_WIN_PLAYLISTS].active = false if window == @plists
        @glade[UIConsts::MM_WIN_CHARTS].active = false if window == @charts
        @glade[UIConsts::MM_WIN_FILTER].active = false if window == @filter
        @glade[UIConsts::MM_WIN_TASKS].active = false if window == @tasks
        @glade[UIConsts::MM_WIN_MEMOS].active = false if window == @memos
    end

    def reset_filter_receiver
        @filter_receiver = self # A revoir s'y a une aute fenetre censee recevoir le focus
    end

    def on_urls_received(widget, context, x, y, data, info, time)
        is_ok = false
        is_ok = Utils::set_cover(data.uris[0], artist.rartist, record.rartist, record.rrecord, track.rtrack) if info == 105 #DragType::URI_LIST
        Gtk::Drag.finish(context, is_ok, false, Time.now.to_i)
        return true
    end

    #
    # The fucking thing! Don't know how to change the check mark of an item without
    # calling the callback associated!
    #
    def update_tags_menu(pm_owner, menu_item)
        #@trk_browser.iter_first.nil? ? tags = 0 : tags = @track.itags
        @pm_owner = pm_owner
        tags = track.itags
        i = 1
        c = 0
        menu_item.submenu.each { |child|
            child.signal_handler_block(@tags_handlers[c])
            child.active = tags & i != 0
            child.signal_handler_unblock(@tags_handlers[c])
            i <<= 1
            c += 1
        }
    end

    #
    # Send the value of tags selection to the popup owner so it can do what it wants of it
    #
    def on_set_tags(widget)
        tags = 0
        i = 1
        widget.parent.each { |child| tags |= i if child.active?; i <<= 1 }
        track.itags = tags
        @pm_owner.send(:set_tags, tags)
    end

    #
    # Send the value of rating selection to the popup owner so it can do what it wants of it
    #
    def on_set_rating(widget)
        @pm_owner.send(:set_rating, UIConsts::RATINGS.index(widget.child.label))
    end


    def toggle_window_visibility(top_window)
        top_window.window.visible? ? top_window.hide : top_window.show
    end

    def show_tooltip(si, x, y, is_kbd, tool_tip)
        @player.playing? ? @player.show_tooltip(si, tool_tip) : tool_tip.set_markup("\n<b>Not playing</b>\n")
    end


    def show_segment_title?
        return @glade[UIConsts::MM_VIEW_SEGTITLE].active?
    end

    #
    # The following methods allow the browsers to get informations about the current
    # selection of the other browsers and notify the mc when a selection has changed.
    #
    def artist
        return @art_browser.artist
    end

    def record
        return @rec_browser.record
    end

    def segment
        return @rec_browser.segment
    end

    def is_on_record
        return @rec_browser.is_on_record
    end

    def track
        return @trk_browser.track
    end

    def artist_changed
        @rec_browser.load_entries_select_first
    end

    def record_changed
        @trk_browser.load_entries_select_first
    end

    def invalidate_tabs
        @rec_browser.invalidate
        @trk_browser.invalidate
    end
    
    def sub_filter
        return @art_browser.sub_filter
    end

    def view_compile?
        return @glade[UIConsts::MM_VIEW_COMPILE].active?
    end

    def change_view_mode
        lrtrack = @trk_browser.track.rtrack
        @art_browser.reload
        select_track(lrtrack) unless lrtrack == -1
    end

    def set_dbrefs_visibility
        [@art_browser, @rec_browser, @trk_browser, @plists].each { |receiver|
            receiver.set_ref_column_visibility(@glade[UIConsts::MM_VIEW_DBREFS].active?)
        }
    end

    # This method is called by the tracks browser when the record is a compile
    # or is segmented in order to keep the artist/segment in sync with the track.
    def change_segment(rsegment)
        @rec_browser.load_segment(rsegment)
    end

    def change_segment_artist(rartist)
        @art_browser.update_segment_artist(rartist)
    end

    def no_selection
        @trk_browser.clear
        @rec_browser.clear
    end

    def update_track_icon(rtrack)
        @trk_browser.update_track_icon(rtrack)
    end

    #
    # Filter management
    #
    def set_main_filter
        # Condition is inverted because the signal is received before the action takes place
        @main_filter = @glade[UIConsts::MW_APPFILTER_ACTION].active? ? @filter.generate_filter(false) : ""

        # Try to reposition on the same track
        lrtrack = @trk_browser.track.rtrack
        #@must_join_logtracks = must_join_logtracks
        @art_browser.reload
        select_track(lrtrack) unless lrtrack == -1
    end

    def set_filter(where_clause, must_join_logtracks)
        if (where_clause != @main_filter)
            lrtrack = @trk_browser.track.rtrack
            @must_join_logtracks = must_join_logtracks
            @main_filter = where_clause
            @art_browser.reload
            select_track(lrtrack) unless lrtrack == -1
        end
    end

    def reload_plists
        @plists.reload
    end

    def on_show_main_filter
        flt_gen = FilterGeneratorDialog.new
        set_main_filter(flt_gen.get_filter) unless flt_gen.show(FilterGeneratorDialog::MODE_FILTER) == Gtk::Dialog::RESPONSE_CANCEL
        flt_gen.destroy
    end


    def import_sql_file
        IO.foreach(SQLGenerator::RESULT_SQL_FILE) { |line| DBUtils::client_sql(line.chomp) }
        @art_browser.reload
        select_record(record.get_last_id) # The best guess to find the imported record
    end


    def select_dialog(tbl_id, dbclass, dbfield)
        value = DBSelectorDialog.new.run(tbl_id)
        unless value == -1
            dbclass.send(dbfield, value)
            dbclass.sql_update.to_widgets
        end
        return value != -1
    end

    def enqueue_record
        @trk_browser.get_tracks_list.each { |rtrack| @pqueue.enqueue(rtrack) }
    end

    def get_drag_tracks
        return @trk_browser.get_drag_tracks
    end

#     def show_informations
#         case @glade[UIConsts::NB_NOTEBOOK].page
#             when 0 then @rec_browser.edit_record
#             when 1 then @rec_browser.edit_segment
#             when 2 then @trk_browser.edit_track
#             when 3 then @art_browser.edit_artist
#         end
#     end

    def on_save_item
#         case @glade[UIConsts::NB_NOTEBOOK].page
#             when 0 then record.from_widgets.sql_update.field_to_widget("mnotes")
#             when 1 then segment.from_widgets.sql_update.field_to_widget("mnotes")
#             when 2 then track.from_widgets.sql_update.field_to_widget("mnotes")
#             when 3 then artist.from_widgets.sql_update.field_to_widget("mnotes")
#         end
        # If there's no change the db is not updated so we can do it in batch
puts "*** save memos called"        
        [record, segment, track, artist].each { |uiclass| uiclass.from_widgets.sql_update }
    end

    def on_import_audio_file
        file = UIUtils::select_source(Gtk::FileChooser::ACTION_OPEN)
        CDEditorWindow.new.edit_audio_file(file) unless file.empty?
    end

    def on_tag_dir_genre
        value = DBSelectorDialog.new.run(DBIntf::TBL_GENRES)
        unless value == -1
            dir = UIUtils::select_source(Gtk::FileChooser::ACTION_SELECT_FOLDER)
            Utils::tag_full_dir_to_genre(DBUtils::name_from_id(value, DBIntf::TBL_GENRES), dir) unless dir.empty?
        end
    end

    def notify_played(rtrack, host = "")
        return if rtrack == 0 # If rtrack is 0 the track has been dropped into the pq from the file system

        # This line would be more efficient but i'm afraid of threading problems that could arise...
        #ltrack = track.rtrack == track ? track : TrackDBClass.new.ref_load(rtrack)
        ltrack = TrackDBClass.new.ref_load(rtrack)
        return if ltrack.banned?

        # Update local database AND remote database if in client mode
        host = Socket::gethostname if host == ""
        DBUtils::update_track_stats(rtrack, host)
        MusicClient.new.update_stats(rtrack) if Cfg::instance.remote?
        #Thread.new { @charts.live_update(rtrack) } if Cfg::instance.live_charts_update? && @charts.window.visible?
        @charts.live_update(rtrack) if Cfg::instance.live_charts_update? && @charts.window.visible?
        # Update gui if the played track is currently selected. Dangerous if user is modifying the track panel!!!
        track.ref_load(rtrack).to_widgets if track.rtrack == rtrack
    end

    def select_artist(rartist, force_reload = false)
        #@art_browser.position_to(rartist) if self.artist.rartist != rartist || force_reload
        @art_browser.select_artist(rartist) if self.artist.rartist != rartist || force_reload
    end

    def select_record(rrecord, force_reload = false)
        lrecord = RecordDBClass.new.ref_load(rrecord)
        select_artist(lrecord.rartist)
        @rec_browser.select_record(rrecord) if self.record.rrecord != rrecord || force_reload
    end

    def select_segment(rsegment, force_reload = false)
        lsegment = SegmentDBClass.new.ref_load(rsegment)
        select_record(lsegment.rrecord)
        @rec_browser.select_segment_from_record_selection(rsegment) # if self.segment.rsegment != rsegment || force_reload
    end

    def select_track(rtrack, force_reload = false)
        ltrack = TrackDBClass.new.ref_load(rtrack)
        lrecord = RecordDBClass.new.ref_load(ltrack.rrecord)
        rartist = lrecord.rartist == 0 && !view_compile? ? SegmentDBClass.new.ref_load(ltrack.rsegment).rartist : lrecord.rartist
        select_artist(rartist)
        @rec_browser.select_record(ltrack.rrecord) if self.record.rrecord != ltrack.rrecord || force_reload
        @trk_browser.position_to(rtrack) if self.track.rtrack != rtrack || force_reload
    end

    def zoom_rec_image
        cover_name = Utils::get_cover_file_name(record.rrecord, track.rtrack, record.irecsymlink)
        return if cover_name.empty?
        dlg = Gtk::Dialog.new("Cover", nil, Gtk::Dialog::MODAL, [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT])
        dlg.vbox.add(Gtk::Image.new(cover_name))
        dlg.show_all
        dlg.run
        dlg.destroy
    end


    #
    # Messages sent by the player to get a track provider
    #
    def get_next_track(is_next)
        meth = is_next ? :get_next_track : :get_prev_track
        return @pqueue.send(meth) if @pqueue.window.visible?
        return @plists.send(meth) if @plists.window.visible?
        return @trk_browser.send(meth)
    end


    #
    # Download database from the server
    #
    #
    def on_update_db
        if Socket::gethostname.match("madD510|192.168.1.14")
            UIUtils::show_message("T'es VRAIMENT TROP CON mon gars!!!", Gtk::MessageDialog::ERROR)
            return
        end
        srv_db_version = MusicClient.new.get_server_db_version
        file = File::basename(DBIntf::build_db_name(srv_db_version)+".dwl")
        @tasks.new_file_download(self, "db"+Cfg::FILE_INFO_SEP+file+Cfg::FILE_INFO_SEP+"0", -1)
    end

    # Still unused but should re-enable all browsers when updating the database.
    def dwl_file_name_notification(user_ref, file_name)
         # Database update: rename the db as db.back and set the downloaded file as the new database.
        if user_ref == -1
            file = DBIntf::build_db_name
            File.unlink(file+".back") if File.exists?(file+".back")
            srv_db_version = MusicClient.new.get_server_db_version
puts("new db version=#{srv_db_version}")
            DBIntf::disconnect
            if srv_db_version == Cfg::instance.db_version
                FileUtils.mv(file, file+".back")
            else
                Prefs::instance.save_db_version(srv_db_version)
            end
            FileUtils.mv(file_name, DBIntf::build_db_name)
        end
    end

    #
    def on_update_resources
        MusicClient.new.synchronize_resources.each { |file| @tasks.new_file_download(self, file, 0) } if Cfg::instance.remote?
    end

    def on_update_sources
        MusicClient.new.synchronize_sources.each { |file| @tasks.new_file_download(self, file, 1) } if Cfg::instance.remote?
    end
end
