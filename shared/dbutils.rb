
class DBUtils

    def DBUtils::name_from_id(field_val, tbl_name)
        return "" if field_val.nil?
        return CDSDB.get_first_value("SELECT sname FROM #{tbl_name}s WHERE r#{tbl_name}=#{field_val};")
    end

    def DBUtils::ref_from_name(name, tbl_name, field = "stitle")
        return CDSDB.get_first_value("SELECT r#{tbl_name} FROM #{tbl_name}s WHERE LOWER(#{field})=LOWER(#{name.to_sql})")
    end

    def DBUtils::log_exec(sql, host = "localhost")
        CDSDB.execute(sql)
        LOG.info(sql+" [#{host}]")
    end

    #
    # Execute an sql statements on the local AND remote database if in client mode
    #
    #
    def DBUtils::client_sql(sql)
        DBUtils::log_exec(sql)
        MusicClient.new.exec_sql(sql) if CFG.remote?
    end

    def DBUtils::threaded_client_sql(sql)
        DBUtils::log_exec(sql)
        Thread.new { MusicClient.new.exec_sql(sql) } if CFG.remote?
    end

    def DBUtils::exec_batch(sql, host)
        CDSDB.transaction { |db|
            db.execute_batch(sql)
            LOG.info(sql+" [#{host}]")
        }
        MusicClient.new.exec_batch(sql) if CFG.remote?
        # May be dangerous to spawn a thread... if request made on the record being inserted,
        # don't know what happen...
#         Thread.new { MusicClient.new.exec_batch(sql) } if CFG.remote?
    end

    def DBUtils::get_last_id(short_tbl_name)
        id = CDSDB.get_first_value("SELECT MAX(r#{short_tbl_name}) FROM #{short_tbl_name}s")
        return id.nil? ? 0 : id
    end

#     def DBUtils::update_track_stats(dblink, hostname)
#         return if dblink.track.rtrack <= 0 # Possible when files are dropped into the play queue
#
#         dblink.track.iplayed += 1
#         dblink.track.ilastplayed = Time.now.to_i
#         self.log_exec(dblink.track.generate_update)
#
#         LogDBClass.new.log_track(dblink.track.rtrack, dblink.track.ilastplayed, hostname)
#         sql1 = "UPDATE tracks SET iplayed=iplayed+1, ilastplayed=#{Time::now.to_i} WHERE rtrack=#{rtrack};"
#         CDSDB.execute(sql1)
#         rlogtrack = DBUtils::get_last_id("logtrack")+1
        #sql2 = "INSERT INTO logtracks VALUES (#{rlogtrack}, #{rtrack}, #{Time::now.to_i}, #{hostname.gsub(/\..*/, "").to_sql});"
#         sql2 = "INSERT INTO logtracks VALUES (#{rlogtrack}, #{rtrack}, #{Time::now.to_i}, #{hostname.to_sql});"
#         sql3 = ""
#         rhost = CDSDB.get_first_value("SELECT rhostname FROM hostnames WHERE sname=#{hostname.to_sql};")
#         if rhost.nil?
#             rhost = DBUtils::get_last_id("hostname")+1
#             sql3 = "INSERT INTO hostnames VALUES(#{rhost}, #{hostname.to_sql});"
#             DBUtils::log_exec(sql3)
#         end
#         sql2 = "INSERT INTO logtracks VALUES (#{dblink.track.rtrack}, #{dblink.track.ilastplayed}, #{rhost});"
#         CDSDB.execute(sql2)
        #log_exec(sql)
#         File.open("../playedtracks.sql", "a+") { |file|
#             file.puts(sql1)
#             file.puts(sql3) unless sql3.empty?
#             file.puts(sql2)
#         } if CFG.log_played_tracks?
#     end

    def DBUtils::update_record_playtime(rrecord)
        len = CDSDB.get_first_value("SELECT SUM(iplaytime) FROM segments WHERE rrecord=#{rrecord};")
        DBUtils::client_sql("UPDATE records SET iplaytime=#{len} WHERE rrecord=#{rrecord};")
    end

    def DBUtils::update_segment_playtime(rsegment)
        len = CDSDB.get_first_value("SELECT SUM(iplaytime) FROM tracks WHERE rsegment=#{rsegment};")
        DBUtils::client_sql("UPDATE segments SET iplaytime=#{len} WHERE rsegment=#{rsegment};")
    end

    def DBUtils::renumber_play_list(rplist)
        i = 1
        sql = ""
        CDSDB.execute(%Q{SELECT rpltrack FROM pltracks WHERE rplist=#{rplist} ORDER BY iorder;}) do |row|
            sql << "UPDATE pltracks SET iorder=#{i} WHERE rpltrack=#{row[0]};\n"
            i += 1
        end
        CDSDB.transaction { |db| db.execute_batch(sql) }
        DBUtils::log_exec("UPDATE plists SET idatemodified=#{Time.now.to_i} WHERE rplist=#{rplist};")
    end

end
