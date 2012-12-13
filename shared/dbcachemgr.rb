
# Data access helper for low level classes like the server

#
# DBCache stores DB rows in hashes whose key is the row primary key
#
# It automatically load rows from DB when the refered row is not already in cache.
#

class DBCache

    include Singleton

    def initialize
        @artists     = {}
        @records     = {}
        @segments    = {}
        @tracks      = {}
        @genres      = {}
        @labels      = {}
        @medias      = {}
        @collections = {}
    end

    def artist(rartist)
        @artists[rartist] = ArtistDBClass.new.ref_load(rartist) if @artists[rartist].nil?
        return @artists[rartist]
    end

    def record(rrecord)
        @records[rrecord] = RecordDBClass.new.ref_load(rrecord) if @records[rrecord].nil?
        return @records[rrecord]
    end

    def segment(rsegment)
        @segments[rsegment] = SegmentDBClass.new.ref_load(rsegment) if @segments[rsegment].nil?
        return @segments[rsegment]
    end

    def track(rtrack)
        @tracks[rtrack] = TrackDBClass.new.ref_load(rtrack) if @tracks[rtrack].nil?
        return @tracks[rtrack]
    end

    def genre(rgenre)
        @genres[rgenre] = GenreDBClass.new.ref_load(rgenre) if @genres[rgenre].nil?
        return @genres[rgenre]
    end

    def label(rlabel)
        @labels[rlabel] = LabelDBClass.new.ref_load(rlabel) if @labels[rlabel].nil?
        return @labels[rlabel]
    end

    def media(rmedia)
        @medias[rmedia] = MediaDBClass.new.ref_load(rmedia) if @medias[rmedia].nil?
        return @medias[rmedia]
    end

    def collection(rcollection)
        @collections[rcollection] = CollectionDBClass.new.ref_load(rcollection) if @collections[rcollection].nil?
        return @collections[rcollection]
    end
end


#
# This class keeps references to the primary key of its tables and makes
# load on demand into the cache.
#
class DBCacheLink

    def initialize
        reset
    end

    def reset
        @rtrack   = nil
        @rsegment = nil
        @rrecord  = nil
        @rartist  = nil # Consider it's the SEGMENT artist
        @rgenre   = nil

        return self
    end


    # Alias for DBCache.instance
    def cache
        return DBCache.instance
    end

    def track
        return cache.track(@rtrack)
    end

    def segment
        @rsegment = cache.segment(track.rsegment).rsegment if @rsegment.nil?
        return cache.segment(@rsegment)
    end

    def record
        @rrecord = cache.record(track.rrecord).rrecord if @rrecord.nil?
        return cache.record(@rrecord)
    end

    def segment_artist
        @rartist = cache.artist(segment.rartist).rartist if @rartist.nil? || @rartist != cache.segment(@rsegment).rartist
        return cache.artist(@rartist)
    end

    def record_artist
        @rartist = cache.artist(record.rartist).rartist if @rartist.nil? || @rartist != cache.record(@rrecord).rartist
        return cache.artist(@rartist)
    end

    alias :artist :segment_artist

    def genre
        @rgenre = cache.genre(record.rgenre).rgenre if @rgenre.nil?
        return cache.genre(@rgenre)
    end

#     def label
#         @rlabel = cache.label(record.rlabel).rlabel if @rlabel.nil?
#         return cache.label(@rlabel)
#     end



    def load_track(rtrack)
        @rtrack = rtrack
        return self
    end

    def load_segment(rsegment)
        @rsegment = rsegment
        return self
    end

    def load_record(rrecord)
        @rrecord = rrecord
        return self
    end

    def load_artist(rartist)
        @rartist = rartist
        return self
    end

    def load_genre(rgenre)
        @rgenre = rgenre
        return self
    end

#     def load_label(rlabel)
#         @rgenre = rlabel
#         return self
#     end

    def reload_track_cache
        cache.track(@rtrack).sql_load
        return self
    end

    def reload_record_cache
        cache.record(@rrecord).sql_load
        return self
    end

    def reload_segment_cache
        cache.segment(@rsegment).sql_load
        return self
    end
end

# Tags are back to life. BUT I should find a better way!
TagsData = Struct.new(:artist, :album, :title, :track, :length, :year, :genre)

#
# Provides audio files handling goodness
#
class AudioLink < DBCacheLink

    NOT_FOUND = 0 # Local audio file not found and/or not on server
    OK        = 1 # Local audio file found where expected to be
    MISPLACED = 2 # Local audio file found but NOT where it should be
    ON_SERVER = 3 # No local file but available from server
    UNKNOWN   = 4 # Should be default value, no check has been made

    attr_accessor :audio_file, :audio_status
    attr_reader   :tags

    def initialize
        super

        reset
    end

    def reset
        super

        @audio_file = ""
        @audio_status = UNKNOWN
        @tags = nil

        return self
    end

    def load_from_tags(file_name)
        @audio_file = file_name
        @audio_status = OK

        tags = TagLib::File.new(file_name)
        @tags = TagsData.new(tags.artist, tags.album, tags.title, tags.track,
                             tags.length*1000, tags.year, tags.genre)
        tags.close

        return self
    end

    # Force the audio file to a specific name. The status is set to OK
    # as we may guess the file really exists.
    def set_audio_file(file_name)
        @audio_file = file_name
        @audio_status = OK
    end

    # Builds the theoretical file name for a given track. Returns it WITHOUT extension.
    def build_audio_file_name
        # If we have a segment, find the intra-segment order. If segmented and isegorder is 0, then the track
        # is alone in its segment.
        track_pos = 0
        if record.segmented?
            track_pos = track.isegorder == 0 ? 1 : track.isegorder
        end
        # If we have a segment, prepend the title with the track position inside the segment
        title = track_pos == 0 ? track.stitle : track_pos.to_s+". "+track.stitle

        # If we have a compilation, the main dir is the record title as opposite to the standard case
        # where it's the artist name
        if record.compile?
            dir = File.join(record.stitle.clean_path, artist.sname.clean_path)
        else
            dir = File.join(artist.sname.clean_path, record.stitle.clean_path)
        end

        fname = sprintf("%02d - %s", track.iorder, title.clean_path)
#         genre = DBUtils::name_from_id(record.rgenre, DBIntf::TBL_GENRES)
        dir += "/"+segment.stitle.clean_path unless segment.stitle.empty?

#         @audio_file = Cfg::instance.music_dir+genre+"/"+dir+"/"+fname
        @audio_file = Cfg::instance.music_dir+genre.sname+"/"+dir+"/"+fname
    end

    def setup_audio_file
        return @audio_status unless @audio_file.empty?

        build_audio_file_name
        @audio_status = search_audio_file
Trace.log.debug("setup returns #{@audio_status}")
        return @audio_status
    end

    # Returns the file name without the music dir and genre
    def track_dir
        file = @audio_file.sub(Cfg::instance.music_dir, "")
        return file.sub(file.split("/")[0], "")
    end

    def full_dir
        return File.dirname(@audio_file)
    end

    def playable?
        return @audio_status == OK || @audio_status == MISPLACED
    end

    # Search the Music directory for a file matching the theoretical file name.
    # If no match at first attempt, search in each first level directory of the Music directory.
    # Returns the status of for the file.
    # If a matching file is found, set the full name to the match.
    def search_audio_file
Trace.log.debug("searching for file #{@audio_file}".cyan)
        Utils::AUDIO_EXTS.each { |ext|
            if File::exists?(@audio_file+ext)
                @audio_file += ext
# Trace.log.debug("found file #{@audio_file}")
                return OK
            end
        }

        # Remove the root dir & genre dir to get the appropriate sub dir
#         file = @audio_file.sub(Cfg::instance.music_dir, "")
#         file.sub!(file.split("/")[0], "")
        file = track_dir
# p file
        Dir[Cfg::instance.music_dir+"*"].each { |entry|
            next if !FileTest::directory?(entry)
            Utils::AUDIO_EXTS.each { |ext|
                if File::exists?(entry+file+ext)
                    @audio_file = entry+file+ext
                    return MISPLACED
                end
            }
        }
        return NOT_FOUND
    end

    def make_track_title(want_segment_title, want_track_number = true)
        title = ""
        if @tags.nil?
            title += track.iorder.to_s+". " unless track.iorder == 0 || !want_track_number
            if want_segment_title
                title += segment.stitle+" - " unless segment.stitle.empty?
                title += track.isegorder.to_s+". " unless track.isegorder == 0
            end
            title += track.stitle
        else
            title += @tags.track.to_s+". " if want_track_number
            title += @tags.title
        end
        return title
    end

    def tag_file(file_name)
        tags = TagLib::File.new(file_name)
        tags.artist = artist.sname
        tags.album  = record.stitle
        tags.title  = make_track_title(true, false) # Want segment title but no track number
        tags.track  = track.iorder
        tags.year   = record.iyear
        tags.genre  = genre.sname
        tags.save
        tags.close
    end

    def tag_and_move_file(file_name)
        # Re-tags the original file
        tag_file(file_name)

        # Build the new name since some data used to build it may have changed
        build_audio_file_name
        @audio_file += File::extname(file_name)

        # Move the original file to it's new location
        root_dir = Cfg::instance.music_dir+genre.sname+File::SEPARATOR
        FileUtils.mkpath(root_dir+File::dirname(track_dir))
        FileUtils.mv(file_name, @audio_file)
        Log.instance.info("Source #{file_name} tagged and moved to "+@audio_file)
        Utils::remove_dirs(File.dirname(file_name))
    end

    def tag_and_move_dir(dir)
        # Get track count
        trk_count = DBIntf::connection.get_first_value("SELECT COUNT(rtrack) FROM tracks WHERE rrecord=#{record.rrecord}")

        # Get recursivelly all music files from the selected dir
        files = []
        Find::find(dir) { |file|
            #puts file;
            files << [File::basename(file), File::dirname(file)] if Utils::AUDIO_EXTS.include?(File.extname(file).downcase)
        }

        # Check if track numbers contain a leading 0. If not rename the file with a leading 0.
        files.each { |file|
            if file[0] =~ /([^0-9]*)([0-9]+)(.*)/
                next if $2.length > 1
                nfile = $1+"0"+$2+$3
                FileUtils.mv(file[1]+File::SEPARATOR+file[0], file[1]+File::SEPARATOR+nfile)
                puts "File #{file[0]} renamed to #{nfile}"
                file[0] = nfile
            end
        }
        # It looks like the sort method sorts on the first array keeping the second one synchronized with it.
        files.sort! #.each { |file| puts "sorted -> file="+file[1]+" --- "+file[0] }

        # Checks if the track count matches both the database and the directory
        return [trk_count, files.size] if trk_count != files.size

        # Loops through each track
        i = 0
        DBIntf::connection.execute("SELECT rtrack FROM tracks WHERE rrecord=#{record.rrecord} ORDER BY iorder") do |row|
            load_track(row[0])
            tag_and_move_file(files[i][1]+File::SEPARATOR+files[i][0])
            i += 1
        end
        return [trk_count, files.size]
    end

end
