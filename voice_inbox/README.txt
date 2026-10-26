voice_inbox/ - recordings from the cast (UPDATE 06 B4, T-101). EVERYTHING IN HERE EXCEPT THIS FILE IS
GIT-IGNORED AND NEVER PUSHED: raw recordings are personal data.

Layout (one folder per actor id from data/voice/cast.json, lowercase):
  voice_inbox/<actor>/consent.txt          REQUIRED before anything of theirs ships into the game. Their "I agree"
                                           to voice_scripts/VOICE_RELEASE.txt with the date, e.g.:
                                               I agree.
                                               name: Paul
                                               date: 2026-10-30
                                               ai_voice_cloning: no
                                           Only "ai_voice_cloning: yes" allows tools/voice/elevenlabs.py to clone.
                                           To remove someone: write "withdrawn" in it (or delete it) and re-run import.
  voice_inbox/<actor>/<actor>_session1.wav any audio (wav, m4a, flac, ogg, mp3...); any number of files.

Then:  tools/voice.sh import            (or: tools/voice.sh import --actor=paul)
       tools/voice.sh review            (opens the review page)

Google Drive: if friends upload to a shared Drive folder, sync it here with Google Drive for desktop (point a folder
at voice_inbox/<actor>/) or download the folder and unzip it into voice_inbox/<actor>/. Not required.
