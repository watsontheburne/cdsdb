
class ArtistsBrowser < Gtk::TreeView

    # Initialize all top levels rows
    MB_TOP_LEVELS = [TreeProvider::Artists.new(1, "artists", 1, false, "", "All Artists"),
                     TreeProvider::Genres.new(2, "genres", 3, true, "records.rgenre", "Genres"),
                     TreeProvider::Origins.new(3, "origins", 3, true, "artists.rorigin", "Countries"),
                     TreeProvider::Tags.new(4, "tags", 3, true, "tracks.itags", "Tags"),
                     TreeProvider::Labels.new(5, "labels", 3, true, "records.rlabel", "Labels"),
                     TreeProvider::Ripped.new(6, "artists", 1, true, "records.rrecord", "Last ripped"),
                     TreeProvider::NeverPlayed.new(7, "tracks", 2, true, "tracks.iplayed", "Never played"),
                     TreeProvider::Ratings.new(8, "ratings", 3, true, "tracks.irating", "Rating"),
                     TreeProvider::PlayTime.new(9, "records", 3, true, "records.iplaytime", "Duration"),
                     TreeProvider::Records.new(10, "records", 1, true, "records.rrecord", "All Records")]

    ATV_REF   = 0
    ATV_NAME  = 1
    ATV_CLASS = 2
    ATV_SORT  = 3

    ROW_REF     = 0
    ROW_NAME    = 1

    attr_reader :artlnk

    def initialize
        super
        @artlnk = XIntf::Artist.new # Cache link for the current artist
        @seg_art = XIntf::Artist.new # Cache link used to update data when browsing a compilation
    end

    def setup(mc)
        @mc = mc
        GtkUI[GtkIDs::ARTISTS_TVC].add(self)
        self.visible = true
        self.enable_search = true
        self.search_column = 3

        selection.mode = Gtk::SELECTION_SINGLE

        name_renderer = Gtk::CellRendererText.new
#         if Cfg.admin
#             name_renderer.editable = true
#             name_renderer.signal_connect(:edited) { |widget, path, new_text| on_artist_edited(widget, path, new_text) }
#         end
        name_column = Gtk::TreeViewColumn.new("Views", name_renderer)
        name_column.set_cell_data_func(name_renderer) { |col, renderer, model, iter| renderer.markup = iter[ATV_NAME] }

        append_column(Gtk::TreeViewColumn.new("Ref.", Gtk::CellRendererText.new, :text => ATV_REF))
        append_column(name_column)

        columns[ATV_NAME].resizable = true

        self.model = Gtk::TreeStore.new(Integer, String, Class, String)

        @tvs = nil # Intended to be a shortcut to @tv.selection.selected. Set in selection change

        selection.signal_connect(:changed)  { |widget| on_selection_changed(widget) }
        signal_connect(:button_press_event) { |widget, event|
            if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 3 # left mouse button
                [GtkIDs::ART_POPUP_ADD, GtkIDs::ART_POPUP_DEL,
                 GtkIDs::ART_POPUP_EDIT, GtkIDs::ART_POPUP_INFOS].each { |item|
                    GtkUI[item].sensitive = @tvs && model.iter_depth(@tvs) == @tvs[2].max_level
                }
                GtkUI[GtkIDs::ART_POPUP_REFRESH].sensitive = @tvs && model.iter_depth(@tvs) < @tvs[2].max_level
                show_popup(widget, event, GtkIDs::ART_POPUP_MENU) if @tvs
            end
        }

        # This line has NO effect when incremental search fails to find a string. The selection is empty...
        # @tv.selection.mode = Gtk::SELECTION_BROWSE

        signal_connect(:row_expanded) { |widget, iter, path| on_row_expanded(widget, iter, path) }
#         @tv.signal_connect(:key_press_event) { |widget, event|
#             searching = !@tv.search_entry.nil?;
#             puts "searching=#{searching}";
#             false }
#         @tv.signal_connect(:start_interactive_search) { |tv, data| puts "search started...".green }
# puts "search entry=#{@tv.search_entry}"
#         @tv.set_search_equal_func { |model, columnm, key, iter| puts "searching #{key}"; true }
#         @tv.set_row_separator_func { |model, iter|
#             model.iter_depth(iter) < iter[2].max_level
#         }

        GtkUI[GtkIDs::ART_POPUP_ADD].signal_connect(:activate)     { on_art_popup_add   }
        GtkUI[GtkIDs::ART_POPUP_DEL].signal_connect(:activate)     { on_art_popup_del   }
        GtkUI[GtkIDs::ART_POPUP_EDIT].signal_connect(:activate)    { edit_artist        }
        GtkUI[GtkIDs::ART_POPUP_INFOS].signal_connect(:activate)   { show_artists_infos }
        GtkUI[GtkIDs::ART_POPUP_REFRESH].signal_connect(:activate) { reload_sub_tree    }

        return finalize_setup
    end

    def load_entries
        model.clear
        MB_TOP_LEVELS.each { |entry|
            iter = model.append(nil)
            iter[0] = entry.ref
            iter[1] = entry.title.to_html_bold
            iter[2] = entry
            iter[3] = entry.title
            entry.append_fake_child(model, iter)
            load_sub_tree(iter) if entry.ref == 1 # Load subtree if all artists
        }
        model.set_sort_column_id(3, Gtk::SORT_ASCENDING)

        return self
    end

    def reload
        load_entries
        @mc.no_selection if !@artlnk.valid_artist_ref? || position_to(@artlnk.artist.rartist).nil?
        return self
    end

    def reload_sub_tree
        return if @tvs.nil? || model.iter_depth(@tvs) == @tvs[2].max_level
        load_sub_tree(@tvs, true)

    end

    def edit_artist
        @artlnk.to_widgets if @artlnk.valid_artist_ref? && XIntf::Editors::Main.new(@mc, @artlnk, XIntf::Editors::ARTIST_PAGE).run == Gtk::Dialog::RESPONSE_OK
    end

    # Recursively search for rartist from iter. If iter is nil, search from tree root.
    # !!! iter.next! returns true if set to next iter and false if no next iter
    #     BUT iter itself is reset to iter_first => iter is NOT nil
    def select_artist(rartist, iter = nil)
        iter = model.iter_first unless iter
        if iter.has_child?
            if iter.first_child[0] != TreeProvider::FAKE_ID
                self.select_artist(rartist, iter.first_child)
            else
                self.select_artist(rartist, iter) if iter.next!
            end
        else
            while iter[0] != rartist
                return unless iter.next!
            end
            expand_row(iter.parent.path, false) unless row_expanded?(iter.parent.path)
            set_cursor(iter.path, nil, false)
        end
    end

    def map_sub_row_to_entry(row, iter)
        new_child = model.append(iter)
        if iter[0] == TreeProvider::SELECT_RECORDS
            new_child[0] = row[1]
            new_child[1] = row[0].to_html_bold+"\nby "+row[2].to_html_italic
            new_child[2] = iter[2]
            new_child[3] = row[0]+"@@@"+row[3].to_s # Magouille magouille...
        else
            new_child[0] = row[0]
            new_child[1] = row[1].to_html
            new_child[2] = iter[2]
            new_child[3] = row[1]
        end
        if model.iter_depth(new_child) < iter[2].max_level
            # The italic tag is hardcoded because to_hml has already been called and it sucks
            # when called twice on the same string
            new_child[1] = "<i>"+new_child[1]+"</i>" #.to_html_italic
            iter[2].append_fake_child(model, new_child)
        end
    end

    # Load children of iter. If it has childen and first child ref is not -10 the children
    # are already loaded, so do nothing except if force_reload is set to true.
    # If first child ref is -10, it's a fake entry so load the true children
    def load_sub_tree(iter, force_reload = false)

        return if iter.first_child && iter.first_child[0] != TreeProvider::FAKE_ID && !force_reload

        # Trace.debug("*** load new sub tree ***")
        # Making the first column the sort column greatly speeds up things AND makes sure that the
        # fake item is first in the store.
        model.set_sort_column_id(0)

        # Remove all children EXCEPT the first one, it's a gtk treeview requirement!!!
        # If not force_reload, we have just one child, the fake entry, so don't remove it now
        if force_reload
            model.remove(iter.nth_child(1)) while iter.nth_child(1)
            iter[1] = iter[1].gsub(/ - .*$/, "") # Remove the number of entries since it's re-set later
        end

        sql = iter[2].select_for_level(model.iter_depth(iter), iter, @mc, model)

        DBIntf.execute(sql) { |row| map_sub_row_to_entry(row, iter) } unless sql.empty?

        # Perform any post selection required action. By default, removes the first fake child
        iter[2].post_select(model, iter, @mc)

        # Called before the set sort column, so it's sorted by ref, not by name!
        iter[1] = iter[1]+" - (#{iter.n_children})" if iter.first_child[0] != TreeProvider::SELECT_RECORDS

        model.set_sort_column_id(3, Gtk::SORT_ASCENDING)
    end

    def on_row_expanded(widget, iter, path)
        load_sub_tree(iter)
    end

    def on_selection_changed(widget)
        @tvs = selection.selected
        return if @tvs.nil?
        # Trace.debug("artists selection changed".cyan)
        if @tvs.nil? || model.iter_depth(@tvs) < @tvs[2].max_level
            @artlnk.reset
        else
            @artlnk.set_artist_ref(@tvs[ATV_REF])
        end
        @artlnk.to_widgets
        @artlnk.valid_artist_ref? ? @mc.artist_changed : @mc.invalidate_tabs
    end

    # This method is called via the mastercontroller to get the current filter for
    # the records browser.
    def sub_filter
        if @tvs.nil? || @tvs[2].where_fields.empty? || model.iter_depth(@tvs) < @tvs[2].max_level
            return ""
        else
            return @tvs[2].sub_filter(@tvs)
        end
    end

    def on_art_popup_add
        @artlnk.artist.add_new
        load_entries.position_to(@artlnk.artist.rartist)
    end

    def on_art_popup_del
        model.remove(@tvs) if GtkUtils.delete_artist(@tvs[ATV_REF]) == 0 if !@tvs.nil? && GtkUtils.get_response("Sure to delete this artist?") == Gtk::Dialog::RESPONSE_OK
    end

    def on_art_popup_edit
        set_cursor(@tvs.path, columns[ATV_NAME], true) if @tvs
    end

    def on_artist_edited(widget, path, new_text)
        # TODO: should retag and move all audio files!
        if @tvs[ATV_NAME] != new_text
            @tvs[ATV_NAME] = new_text
            @artlnk.artist.sname = new_text
            @artlnk.artist.sql_update
        end
    end

    def update_segment_artist(rartist)
        @seg_art.set_artist_ref(rartist).to_widgets
    end

    def is_on_compile?
        return false if @tvs.nil? || model.iter_depth(@tvs) < @tvs[2].max_level
        return @tvs[0] == 0
    end

    def is_on_never_played?
        return @tvs.nil? ? false : @tvs[2].ref == 7
    end

    def never_played_iter
        iter = model.iter_first
        iter.next! while iter[2].ref != 7
        return !iter || iter.first_child[0] == TreeProvider::FAKE_ID ? nil : iter
    end

    def remove_artist(rartist)
        iter = never_played_iter
        return unless iter
        sub_iter = iter.first_child
        sub_iter.next! while sub_iter[0] != rartist
        if sub_iter[0] == rartist
            model.remove(sub_iter)
            iter[1] = iter[1].gsub(/\ -\ .*$/, "")
            iter[1] = iter[1]+" - (#{iter.n_children})"
        end
    end

    def update_never_played(rrecord, rsegment)
        return unless never_played_iter # Sub tree not loaded, nothing to do

        # If view compile, it's possible to play the last track from an artist that has full disks and
        # thus appears in both compilations and artists list.
        if @mc.view_compile?
            # Check if we can remove compilations or the artist from the list
            rartist = is_on_compile? ? 0 : DBClasses::Record.new.ref_load(rrecord).rartist
            sql = "SELECT COUNT(tracks.rtrack) FROM tracks " \
                    "INNER JOIN records ON records.rrecord=tracks.rrecord " \
                    "WHERE records.rartist=#{rartist}"
        else
            # Get artist from segment, we may be on a compile only artist
            rartist = DBClasses::Segment.new.ref_load(rsegment).rartist
            sql = "SELECT COUNT(tracks.rtrack) FROM tracks " \
                    "INNER JOIN segments ON segments.rsegment=tracks.rsegment " \
                    "WHERE segments.rartist=#{rartist}"
        end
        sql += " AND tracks.iplayed=0;"

p sql
        remove_artist(rartist) if DBIntf.get_first_value(sql) == 0
    end

    def show_artists_infos
        # TODO: the select on distinct playtime is or may be wrong if two rec/seg have the same length...
        recs_infos = DBIntf.get_first_row(
            %Q{SELECT COUNT(DISTINCT(records.rrecord)), SUM(DISTINCT(records.iplaytime)), COUNT(tracks.rtrack) FROM records
               INNER JOIN tracks ON tracks.rrecord=records.rrecord
               WHERE rartist=#{@tvs[0]};})
        comp_infos = DBIntf.get_first_row(
            %Q{SELECT COUNT(DISTINCT(records.rrecord)), SUM(DISTINCT(segments.iplaytime)), COUNT(tracks.rtrack) FROM records
               INNER JOIN segments ON segments.rrecord=records.rrecord
               INNER JOIN tracks ON tracks.rsegment=segments.rsegment
               WHERE segments.rartist=#{@tvs[0]} AND records.rartist=0;})

        GtkUI.load_window(GtkIDs::DLG_ART_INFOS)

        GtkUI[GtkIDs::ARTINFOS_LBL_RECS_COUNT].text = recs_infos[0].to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_RECS_TRKS].text  = recs_infos[2].to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_RECS_PT].text    = recs_infos[1].to_i.to_day_length

        GtkUI[GtkIDs::ARTINFOS_LBL_COMP_COUNT].text = comp_infos[0].to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_COMP_TRKS].text  = comp_infos[2].to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_COMP_PT].text    = comp_infos[1].to_i.to_day_length

        GtkUI[GtkIDs::ARTINFOS_LBL_TOT_COUNT].text = (recs_infos[0]+comp_infos[0]).to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_TOT_TRKS].text  = (recs_infos[2]+comp_infos[2]).to_s
        GtkUI[GtkIDs::ARTINFOS_LBL_TOT_PT].text    = (recs_infos[1].to_i+comp_infos[1].to_i).to_day_length

        GtkUI[GtkIDs::DLG_ART_INFOS].show.run
        GtkUI[GtkIDs::DLG_ART_INFOS].destroy
    end

end
