
#
# Extension of Utils class but with UI dependance
#

module GtkUtils

    #
    # Generic methods to deal with the user
    #

    def self.show_message(msg, msg_type)
        dialog = Gtk::MessageDialog.new(nil, Gtk::Dialog::MODAL, msg_type, Gtk::MessageDialog::BUTTONS_OK, msg)
        dialog.title = 'Information'
        dialog.run # {|r| puts "response=%d" % [r]}
        dialog.destroy
    end

    def self.get_response(msg)
        dialog = Gtk::MessageDialog.new(nil, Gtk::Dialog::MODAL, Gtk::MessageDialog::WARNING,
                                        Gtk::MessageDialog::BUTTONS_OK_CANCEL, msg)
        dialog.title = 'Warning'
        response = dialog.run
        dialog.destroy
        return response
    end

    def self.select_source(action, default_dir = '')
        file = ''
        action == Gtk::FileChooser::ACTION_OPEN ? title = 'Select file' : title = 'Select directory'
        dialog = Gtk::FileChooserDialog.new(title, nil, action, nil,
                                            [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                            [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
        dialog.current_folder = default_dir.empty? ? Cfg.music_dir : default_dir
        file = dialog.filename if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
        dialog.destroy
        return file
    end


    #
    # Tree view builder for tags selector
    #

    def self.setup_tracks_tags_tv(tvt)
        tvt.model = Gtk::ListStore.new(TrueClass, String)

        arenderer = Gtk::CellRendererToggle.new
        arenderer.activatable = true
        arenderer.signal_connect(:toggled) do |w, path|
            iter = tvt.model.get_iter(path)
            iter[0] = !iter[0] if iter
        end
        srenderer = Gtk::CellRendererText.new

        tvt.append_column(Gtk::TreeViewColumn.new('Match', arenderer, :active => 0))
        tvt.append_column(Gtk::TreeViewColumn.new('Tag', srenderer, :text => 1))
        Qualifiers::TAGS.each do |tag|
            iter = tvt.model.append
            iter[0] = false
            iter[1] = tag
        end
    end

    def self.get_tags_mask(tvt)
        mask = 0
        i = 1
        tvt.model.each { |model, path, iter| mask |= i if iter[0]; i <<= 1 }
        return mask
    end


    #
    # Pix maps generator for button icons
    #
    def self.get_btn_icon(fname)
        return File.exists?(fname) ? GdkPixbuf::Pixbuf.new(file: fname, width: 22, height: 22) : GdkPixbuf::Pixbuf.new(file: Cfg.icons_dir+'default.svg', width: 22, height: 22)
    end


    #
    # Database utilities that may require user intervention
    #

    def self.import_played_tracks
        return if self.get_response('OK to import tracks from playedtracks.sql?') != Gtk::Dialog::RESPONSE_OK
        rlogtrack = DBUtils.get_last_id('logtrack')
        IO.foreach(Cfg.rsrc_dir+'playedtracks.sql') do |line|
            line = line.chomp
            if line.match(/^INSERT/)
                rlogtrack += 1
                #print "replacing @#{line}@ with "
                line.sub!(/\([0-9]*/, "(#{rlogtrack}")
                #puts line
            end
            DBUtils.log_exec(line)
        end
    end

    def self.delete_artist(rartist)
        msg = ''
        count = DBIntf.get_first_value("SELECT COUNT(rartist) FROM records WHERE rartist=#{rartist};")
        msg = "Error: #{count} reference(s) still in records table." if count > 0
        count = DBIntf.get_first_value("SELECT COUNT(rartist) FROM segments WHERE rartist=#{rartist};")
        if count > 0
            msg += "\n" if msg.length > 0
            msg += "Error: #{count} reference(s) still in segments table."
        end
        if msg.length > 0
            self.show_message(msg, Gtk::MessageDialog::ERROR)
        else
            DBUtils.client_sql("DELETE FROM artists WHERE rartist=#{rartist};")
            return 0
        end
        return 1
    end

    def self.delete_segment(rsegment)
        count = DBIntf.get_first_value("SELECT COUNT(rsegment) FROM tracks WHERE rsegment=#{rsegment};")
        if count > 0
            self.show_message("Error: #{count} reference(s) still in tracks table.", Gtk::MessageDialog::ERROR)
        else
            DBUtils.client_sql("DELETE FROM segments WHERE rsegment=#{rsegment};")
        end
        return count
    end

    def self.delete_record(rrecord)
        count = DBIntf.get_first_value("SELECT COUNT(rsegment) FROM segments WHERE rrecord=#{rrecord};")
        if count > 0
            self.show_message("Error: #{count} reference(s) still in segments table.", Gtk::MessageDialog::ERROR)
        else
            DBUtils.client_sql("DELETE FROM records WHERE rrecord=#{rrecord};")
        end
        return count
    end

    def self.delete_track(rtrack)
        count = DBIntf.get_first_value("SELECT COUNT(rpltrack) FROM pltracks WHERE rtrack=#{rtrack};")
        if count > 0
            self.show_message("Error: #{count} reference(s) still in play lists.", Gtk::MessageDialog::ERROR)
        else
            row = DBIntf.execute("SELECT rsegment, rrecord FROM tracks WHERE rtrack=#{rtrack}")
            count = DBIntf.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rsegment=#{row[0][0]}")
            del_seg = count == 1 && self.get_response("This is the last track of its segment. Remove it along?") == Gtk::Dialog::RESPONSE_OK
            count = DBIntf.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rrecord=#{row[0][1]}")
            del_rec = count == 1 && self.get_response('This is the last track of its record. Remove it along?') == Gtk::Dialog::RESPONSE_OK

            DBUtils.client_sql("DELETE FROM logtracks WHERE rtrack=#{rtrack};")
            DBUtils.client_sql("DELETE FROM tracks WHERE rtrack=#{rtrack};")

            delete_segment(row[0][0]) if del_seg
            delete_record(row[0][1]) if del_rec
        end
        return count
    end

end
