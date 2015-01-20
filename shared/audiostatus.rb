
# A name space for audio files status

module AudioStatus
    NOT_FOUND = 0 # Local audio file not found and/or not on server
    OK        = 1 # Local audio file found where expected to be
    MISPLACED = 2 # Local audio file found but NOT where it should be
    ON_SERVER = 3 # No local file but available from server
    UNKNOWN   = 4 # Should be default value, no check has been made
end