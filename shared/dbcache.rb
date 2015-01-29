
module DBCache

    #
    # Cache stores DB rows in hashes whose key is the row primary key
    #
    # It automatically load rows from DB when the refered row is not already in cache.
    #

    module Cache

        TrackState = Struct.new(:status, :file)

        TRACE_CACHE = false

        class << self

            def init
                @artists     = {}
                @records     = {}
                @segments    = {}
                @tracks      = {}
                @genres      = {}
                @labels      = {}
                @medias      = {}
                @collections = {}
                @origins     = {}

                # Keep tracks of audio file status for a track, avoiding to
                # repeatedly ask to the server if the track exists in client mode.
                # Closely related to the track cache.
                @audio = {}
            end

            def artist(rartist)
                if @artists[rartist].nil?
                    @artists[rartist] = DBClass::Artist.new.ref_load(rartist)
                    Trace.debug("Artist cache MISS for key #{rartist}, size=#{@artists.size}") if TRACE_CACHE
                else
                    Trace.debug("Artist cache HIT for key #{rartist}, size=#{@artists.size}") if TRACE_CACHE
                end
                return @artists[rartist]
            end

            def record(rrecord)
                if @records[rrecord].nil?
                    @records[rrecord] = DBClass::Record.new.ref_load(rrecord)
                    Trace.debug("Record cache MISS for key #{rrecord}, size=#{@records.size}") if TRACE_CACHE
                else
                    Trace.debug("Record cache HIT for key #{rrecord}, size=#{@records.size}") if TRACE_CACHE
                end
                return @records[rrecord]
            end

            def segment(rsegment)
                if @segments[rsegment].nil?
                    @segments[rsegment] = DBClass::Segment.new.ref_load(rsegment)
                    Trace.debug("Segment cache MISS for key #{rsegment}, size=#{@segments.size}") if TRACE_CACHE
                else
                    Trace.debug("Segment cache HIT for key #{rsegment}, size=#{@segments.size}") if TRACE_CACHE
                end
                return @segments[rsegment]
            end

            def track(rtrack)
                if @tracks[rtrack].nil?
                    @tracks[rtrack] = DBClass::Track.new.ref_load(rtrack)
                    @audio[rtrack] = TrackState.new(Audio::Status::UNKNOWN, nil)
                    Trace.debug("Track cache MISS for key #{rtrack}, size=#{@tracks.size}") if TRACE_CACHE
                else
                    Trace.debug("Track cache HIT for key #{rtrack}, size=#{@tracks.size}") if TRACE_CACHE
                end
                return @tracks[rtrack]
            end

            def genre(rgenre)
                @genres[rgenre] = DBClass::Genre.new.ref_load(rgenre) if @genres[rgenre].nil?
                return @genres[rgenre]
            end

            def label(rlabel)
                @labels[rlabel] = DBClass::Label.new.ref_load(rlabel) if @labels[rlabel].nil?
                return @labels[rlabel]
            end

            def media(rmedia)
                @medias[rmedia] = DBClass::Media.new.ref_load(rmedia) if @medias[rmedia].nil?
                return @medias[rmedia]
            end

            def collection(rcollection)
                @collections[rcollection] = DBClass::Collection.new.ref_load(rcollection) if @collections[rcollection].nil?
                return @collections[rcollection]
            end

            def origin(rorigin)
                @origins[rorigin] = DBClass::Origin.new.ref_load(rorigin) if @origins[rorigin].nil?
                return @origins[rorigin]
            end

            def audio(rtrack)
                return @audio[rtrack]
            end

            def set_audio_file(rtrack, file_name)
                @audio[rtrack].file = file_name
            end

            def set_audio_status(rtrack, status)
                @audio[rtrack].status = status
            end

            def audio_status(rtrack)
                track(rtrack) unless @audio[rtrack]
                @audio[rtrack].status = Audio::Status::UNKNOWN unless @audio[rtrack] # Unknown status if not in cache
                return @audio[rtrack].status
            end

            def reset_audio(rtrack)
                @audio[rtrack].status = Audio::Status::NOT_FOUND
                @audio[rtrack].file   = nil
            end

            def clear
                # instance_variables.each { |cache| cache.clear } # Marche pas!!!???
                [@artists, @records, @segments, @tracks, @audio,
                @genres, @labels, @medias, @collections, @origins].each { |cache| cache.clear }
                Trace.debug("ALL CACHES cleared") if TRACE_CACHE
            end

            # Set audio status from a status to another
            # Primary use is when switching from local mode to client mode (not found -> unknown)
            # and from client to local mode (on server -> not found)
            def set_audio_status_from_to(from_value, to_value)
                @audio.each { |key, value| value.status = to_value if value.status == from_value }
            end

            def dump_infos
                Trace.debug("--- Cache infos ---")
                Trace.debug("Artist cache size=#{@artists.size}")
                Trace.debug("Record cache size=#{@records.size}")
                Trace.debug("Segment cache size=#{@segments.size}")
                Trace.debug("Track cache size=#{@tracks.size}")
                Trace.debug("Genre cache size=#{@genres.size}")
                Trace.debug("Label cache size=#{@labels.size}")
                Trace.debug("Media cache size=#{@medias.size}")
                Trace.debug("Collection cache size=#{@collections.size}")
                Trace.debug("Origin cache size=#{@origins.size}")
                Trace.debug("Audio infos cache size=#{@audio.size}")
            end
        end
    end
end

DBCache::Cache.init