# Kodi saves plugin views per folder path, so every new YouTube page (channel, search, feed)
# would fall back to the skin's list view. Switch YouTube video lists to Estuary's Wall view
# (thumbnail grid). Lightweight: only a few info-label reads every 0.5 s, nothing else.
import xbmc

PREFIX = 'plugin://plugin.video.youtube/'
WALL_VIEW_ID = 500        # Estuary View_500_Wall (poster / thumbnail grid)
CONTENT = ('videos', 'episodes', 'movies', 'tvshows')

xbmc.log('[htpc.youtubeview] started', xbmc.LOGINFO)
monitor = xbmc.Monitor()
done_path = None
while not monitor.abortRequested():
    if monitor.waitForAbort(0.5):
        break
    path = xbmc.getInfoLabel('Container.FolderPath')
    if not path.startswith(PREFIX):
        done_path = None
        continue
    if path == done_path or not xbmc.getCondVisibility('Window.IsActive(videos)'):
        continue
    content = xbmc.getInfoLabel('Container.Content')
    if not content or not xbmc.getInfoLabel('Container.NumItems'):
        continue                      # still loading: check again on the next tick
    if content in CONTENT and not xbmc.getCondVisibility('Control.IsVisible(%d)' % WALL_VIEW_ID):
        xbmc.executebuiltin('Container.SetViewMode(%d)' % WALL_VIEW_ID)
        xbmc.log('[htpc.youtubeview] wall view: ' + path, xbmc.LOGINFO)
    done_path = path
