import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id')
  ];

  /// Title of the settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Section header for theme appearance options
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Theme option that follows the system theme
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsFollowSystem;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsLight;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDark;

  /// Section header for accent color picker
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccentColor;

  /// Accent color name purple
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get settingsAccentPurple;

  /// Accent color name blue
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get settingsAccentBlue;

  /// Accent color name teal
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get settingsAccentTeal;

  /// Accent color name green
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get settingsAccentGreen;

  /// Accent color name orange
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get settingsAccentOrange;

  /// Accent color name red
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get settingsAccentRed;

  /// Accent color name dark purple
  ///
  /// In en, this message translates to:
  /// **'Deep purple'**
  String get settingsAccentDeepPurple;

  /// Accent color name pink
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get settingsAccentPink;

  /// Accent color name cyan
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get settingsAccentCyan;

  /// Accent color name light green
  ///
  /// In en, this message translates to:
  /// **'Light green'**
  String get settingsAccentLightGreen;

  /// Section header for playback options
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// Crossfade toggle title
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get settingsCrossfade;

  /// Crossfade toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Seamless transition between songs (3 seconds)'**
  String get settingsCrossfadeSubtitle;

  /// Section header for equalizer presets
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get settingsEqualizer;

  /// Honest disclaimer that EQ presets are visual only
  ///
  /// In en, this message translates to:
  /// **'These presets are only a visual preview and do not change the actual sound. Your choice is saved between sessions.'**
  String get settingsEqualizerNote;

  /// Section header for library actions
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsLibrary;

  /// Title for scanning device music files
  ///
  /// In en, this message translates to:
  /// **'Scan music files'**
  String get settingsScanFiles;

  /// Subtitle for scanning device music files
  ///
  /// In en, this message translates to:
  /// **'Check for new or removed music files on this device (offline)'**
  String get settingsScanFilesSubtitle;

  /// Title for scanning only missing metadata
  ///
  /// In en, this message translates to:
  /// **'Scan missing metadata'**
  String get settingsScanMissing;

  /// Subtitle for scanning only missing metadata
  ///
  /// In en, this message translates to:
  /// **'Fetch title/artist/cover from the internet for new songs'**
  String get settingsScanMissingSubtitle;

  /// Progress text while bulk metadata scan runs
  ///
  /// In en, this message translates to:
  /// **'Processing {progress}/{total}...'**
  String settingsScanProgress(int progress, int total);

  /// Title for rescanning all metadata
  ///
  /// In en, this message translates to:
  /// **'Rescan all metadata'**
  String get settingsRescanAll;

  /// Subtitle for rescanning all metadata
  ///
  /// In en, this message translates to:
  /// **'Fetch again from the internet for ALL songs'**
  String get settingsRescanAllSubtitle;

  /// Section header for about info
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// App version and author credit
  ///
  /// In en, this message translates to:
  /// **'v1.6.0 · by Niko'**
  String get settingsAboutVersion;

  /// Confirmation dialog title for rescan all
  ///
  /// In en, this message translates to:
  /// **'Rescan all'**
  String get settingsRescanTitle;

  /// Confirmation message for rescan all
  ///
  /// In en, this message translates to:
  /// **'Fetch metadata again for all {count} songs from the internet? This takes longer.'**
  String settingsRescanMessage(int count);

  /// Confirm button to start rescan all
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get settingsRescanStart;

  /// Section header for language selection
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// Subtitle for the language section
  ///
  /// In en, this message translates to:
  /// **'Application language'**
  String get languageSubtitle;

  /// Label for the English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Label for the Indonesian language option
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get languageIndonesian;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get empty;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @corePlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play'**
  String get corePlayFailed;

  /// No description provided for @coreScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get coreScanFailed;

  /// No description provided for @coreUpdateFavoritesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update favorites'**
  String get coreUpdateFavoritesFailed;

  /// No description provided for @coreSongAlreadyInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'This song is already in the playlist'**
  String get coreSongAlreadyInPlaylist;

  /// No description provided for @coreRemoveFromPlaylistFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the song from the playlist'**
  String get coreRemoveFromPlaylistFailed;

  /// No description provided for @coreSavePlaylistOrderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the playlist order'**
  String get coreSavePlaylistOrderFailed;

  /// No description provided for @corePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Music access permission was denied'**
  String get corePermissionDenied;

  /// No description provided for @coreSongs.
  ///
  /// In en, this message translates to:
  /// **'songs'**
  String get coreSongs;

  /// No description provided for @playlistLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlist: {error}'**
  String playlistLoadFailed(String error);

  /// No description provided for @playlistReorderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save order: {error}'**
  String playlistReorderFailed(String error);

  /// No description provided for @playlistRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove song: {error}'**
  String playlistRemoveFailed(String error);

  /// No description provided for @playlistSortCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom order'**
  String get playlistSortCustom;

  /// No description provided for @playlistSortTitleAZ.
  ///
  /// In en, this message translates to:
  /// **'Title A-Z'**
  String get playlistSortTitleAZ;

  /// No description provided for @playlistSortTitleZA.
  ///
  /// In en, this message translates to:
  /// **'Title Z-A'**
  String get playlistSortTitleZA;

  /// No description provided for @playlistSortArtistAZ.
  ///
  /// In en, this message translates to:
  /// **'Artist A-Z'**
  String get playlistSortArtistAZ;

  /// No description provided for @playlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'This playlist is still empty'**
  String get playlistEmpty;

  /// No description provided for @playlistSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} songs - {duration}'**
  String playlistSummary(int count, String duration);

  /// No description provided for @playlistSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search in this playlist...'**
  String get playlistSearchHint;

  /// No description provided for @playlistPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playlistPlay;

  /// No description provided for @playlistShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playlistShuffle;

  /// No description provided for @playlistReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Press and drag to reorder'**
  String get playlistReorderHint;

  /// No description provided for @playlistNoResults.
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get playlistNoResults;

  /// No description provided for @historyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history: {error}'**
  String historyLoadFailed(String error);

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playback history yet'**
  String get historyEmpty;

  /// No description provided for @dashboardLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dashboard'**
  String get dashboardLoadFailedTitle;

  /// No description provided for @dashboardRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get dashboardRetry;

  /// No description provided for @dashboardEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty dashboard'**
  String get dashboardEmptyTitle;

  /// No description provided for @dashboardEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Listening stats will appear after you start playing songs.'**
  String get dashboardEmptySubtitle;

  /// No description provided for @dashboardTotalSongsLibrary.
  ///
  /// In en, this message translates to:
  /// **'Total songs in library'**
  String get dashboardTotalSongsLibrary;

  /// No description provided for @dashboardTotalSongs.
  ///
  /// In en, this message translates to:
  /// **'Total songs'**
  String get dashboardTotalSongs;

  /// No description provided for @dashboardTotalListened.
  ///
  /// In en, this message translates to:
  /// **'Total listened'**
  String get dashboardTotalListened;

  /// No description provided for @dashboardThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get dashboardThisMonth;

  /// No description provided for @dashboardHoursValue.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours'**
  String dashboardHoursValue(String hours);

  /// No description provided for @dashboardListeningWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Listening Hours in the Last 7 Days'**
  String get dashboardListeningWeekTitle;

  /// No description provided for @dashboardWeekTotal.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours total'**
  String dashboardWeekTotal(String hours);

  /// No description provided for @dashboardTopSongs.
  ///
  /// In en, this message translates to:
  /// **'Top 5 Songs'**
  String get dashboardTopSongs;

  /// No description provided for @dashboardUnknownSong.
  ///
  /// In en, this message translates to:
  /// **'Song #{id}'**
  String dashboardUnknownSong(int id);

  /// No description provided for @dashboardPlayCount.
  ///
  /// In en, this message translates to:
  /// **'{count}x played'**
  String dashboardPlayCount(int count);

  /// No description provided for @dashboardPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to play song: {error}'**
  String dashboardPlayFailed(String error);

  /// No description provided for @dashboardTopArtists.
  ///
  /// In en, this message translates to:
  /// **'Top 5 Artists'**
  String get dashboardTopArtists;

  /// No description provided for @dashboardGenreTitle.
  ///
  /// In en, this message translates to:
  /// **'Genre Distribution'**
  String get dashboardGenreTitle;

  /// No description provided for @dashboardGenreCount.
  ///
  /// In en, this message translates to:
  /// **'{count} genres'**
  String dashboardGenreCount(int count);

  /// No description provided for @dashboardNeverPlayedTitle.
  ///
  /// In en, this message translates to:
  /// **'Never Played'**
  String get dashboardNeverPlayedTitle;

  /// No description provided for @dashboardSongCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String dashboardSongCount(int count);

  /// No description provided for @dashboardNeverPlayedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} songs in your library have never been played.'**
  String dashboardNeverPlayedSubtitle(int count);

  /// No description provided for @dashboardPlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play All'**
  String get dashboardPlayAll;

  /// No description provided for @dashboardWeekActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'This Week Activity'**
  String get dashboardWeekActivityTitle;

  /// No description provided for @dashboardNoWeekActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity this week yet.'**
  String get dashboardNoWeekActivity;

  /// No description provided for @dashboardActiveDays.
  ///
  /// In en, this message translates to:
  /// **'{count} of 7 days actively listening'**
  String dashboardActiveDays(int count);

  /// No description provided for @dashboardNeverPlayedSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} songs never played'**
  String dashboardNeverPlayedSheetTitle(int count);

  /// No description provided for @dashboardDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get dashboardDaySun;

  /// No description provided for @dashboardDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dashboardDayMon;

  /// No description provided for @dashboardDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dashboardDayTue;

  /// No description provided for @dashboardDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dashboardDayWed;

  /// No description provided for @dashboardDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dashboardDayThu;

  /// No description provided for @dashboardDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dashboardDayFri;

  /// No description provided for @dashboardDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get dashboardDaySat;

  /// No description provided for @dashboardTooltipMinutes.
  ///
  /// In en, this message translates to:
  /// **'{mins}m'**
  String dashboardTooltipMinutes(int mins);

  /// No description provided for @dashboardTooltipHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String dashboardTooltipHours(String hours);

  /// No description provided for @editMetadataValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Title, artist, and album cannot be empty'**
  String get editMetadataValidationEmpty;

  /// No description provided for @editMetadataSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String editMetadataSaveFailed(String error);

  /// No description provided for @editMetadataRescanTitle.
  ///
  /// In en, this message translates to:
  /// **'Rescan from the Internet?'**
  String get editMetadataRescanTitle;

  /// No description provided for @editMetadataRescanMessage.
  ///
  /// In en, this message translates to:
  /// **'Data from the internet will overwrite your manual edits in this form. Continue?'**
  String get editMetadataRescanMessage;

  /// No description provided for @editMetadataRescanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, Overwrite'**
  String get editMetadataRescanConfirm;

  /// No description provided for @editMetadataRescanFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rescan: {error}'**
  String editMetadataRescanFailed(String error);

  /// No description provided for @editMetadataRescanSuccess.
  ///
  /// In en, this message translates to:
  /// **'Metadata updated from the internet'**
  String get editMetadataRescanSuccess;

  /// No description provided for @editMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get editMetadataTitle;

  /// No description provided for @editMetadataFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching data...'**
  String get editMetadataFetching;

  /// No description provided for @editMetadataRescanButton.
  ///
  /// In en, this message translates to:
  /// **'Rescan from the Internet'**
  String get editMetadataRescanButton;

  /// No description provided for @editMetadataFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get editMetadataFieldTitle;

  /// No description provided for @editMetadataFieldArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get editMetadataFieldArtist;

  /// No description provided for @editMetadataFieldAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get editMetadataFieldAlbum;

  /// No description provided for @editMetadataFieldGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get editMetadataFieldGenre;

  /// No description provided for @editMetadataFieldRegion.
  ///
  /// In en, this message translates to:
  /// **'Region Origin'**
  String get editMetadataFieldRegion;

  /// No description provided for @editMetadataEditLyricsButton.
  ///
  /// In en, this message translates to:
  /// **'Edit Lyrics (separate page)'**
  String get editMetadataEditLyricsButton;

  /// No description provided for @editMetadataSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get editMetadataSaveButton;

  /// No description provided for @editLyricsClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty, no text to paste'**
  String get editLyricsClipboardEmpty;

  /// No description provided for @editLyricsPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste Lyrics'**
  String get editLyricsPasteTitle;

  /// No description provided for @editLyricsPasteMessage.
  ///
  /// In en, this message translates to:
  /// **'There are already lyrics here. Overwrite them (start over) or append to the existing lyrics?'**
  String get editLyricsPasteMessage;

  /// No description provided for @editLyricsAppend.
  ///
  /// In en, this message translates to:
  /// **'Append'**
  String get editLyricsAppend;

  /// No description provided for @editLyricsOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get editLyricsOverwrite;

  /// No description provided for @editLyricsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save lyrics: {error}'**
  String editLyricsSaveFailed(String error);

  /// No description provided for @editLyricsTruncated.
  ///
  /// In en, this message translates to:
  /// **'Lyrics exceeded 100KB and were trimmed when saved'**
  String get editLyricsTruncated;

  /// No description provided for @editLyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Lyrics: {title}'**
  String editLyricsTitle(String title);

  /// No description provided for @editLyricsPasteButton.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get editLyricsPasteButton;

  /// No description provided for @editLyricsSearchWeb.
  ///
  /// In en, this message translates to:
  /// **'Search on Web'**
  String get editLyricsSearchWeb;

  /// No description provided for @editLyricsHint.
  ///
  /// In en, this message translates to:
  /// **'No lyrics yet. Paste from clipboard, search the web, or type manually here.'**
  String get editLyricsHint;

  /// No description provided for @editLyricsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Lyrics'**
  String get editLyricsSaveButton;

  /// No description provided for @songOptionsPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get songOptionsPlayNext;

  /// No description provided for @songOptionsAddedPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Added to play next'**
  String get songOptionsAddedPlayNext;

  /// No description provided for @songOptionsAddToQueueEnd.
  ///
  /// In en, this message translates to:
  /// **'Add to End of Queue'**
  String get songOptionsAddToQueueEnd;

  /// No description provided for @songOptionsAddedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get songOptionsAddedToQueue;

  /// No description provided for @songOptionsAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get songOptionsAddFavorite;

  /// No description provided for @songOptionsRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get songOptionsRemoveFavorite;

  /// No description provided for @songOptionsFavoriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update favorite: {error}'**
  String songOptionsFavoriteFailed(String error);

  /// No description provided for @songOptionsAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get songOptionsAddToPlaylist;

  /// No description provided for @songOptionsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename Song'**
  String get songOptionsRename;

  /// No description provided for @songOptionsEditMetadata.
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get songOptionsEditMetadata;

  /// No description provided for @songOptionsRemoveFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from This Playlist'**
  String get songOptionsRemoveFromPlaylist;

  /// No description provided for @songOptionsRemoveFromPlaylistFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove from playlist: {error}'**
  String songOptionsRemoveFromPlaylistFailed(String error);

  /// No description provided for @songOptionsRemovedFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Removed from this playlist only'**
  String get songOptionsRemovedFromPlaylist;

  /// No description provided for @songOptionsDeleteFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Delete from Library'**
  String get songOptionsDeleteFromLibrary;

  /// No description provided for @songOptionsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Song'**
  String get songOptionsDeleteTitle;

  /// No description provided for @songOptionsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\" from All Songs, Folders, Favorites, and Playlists? The original file on your phone is kept - it will appear again if the folder is rescanned.'**
  String songOptionsDeleteConfirm(String title);

  /// No description provided for @songOptionsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete song: {error}'**
  String songOptionsDeleteFailed(String error);

  /// No description provided for @songOptionsRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename: {error}'**
  String songOptionsRenameFailed(String error);

  /// No description provided for @songOptionsCreatePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create New Playlist'**
  String get songOptionsCreatePlaylist;

  /// No description provided for @songOptionsPlaylistNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get songOptionsPlaylistNameTitle;

  /// No description provided for @songOptionsAddToPlaylistFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add to playlist: {error}'**
  String songOptionsAddToPlaylistFailed(String error);

  /// No description provided for @songOptionsPlaylistCreated.
  ///
  /// In en, this message translates to:
  /// **'Playlist \"{name}\" created and song added'**
  String songOptionsPlaylistCreated(String name);

  /// No description provided for @songOptionsPlaylistExists.
  ///
  /// In en, this message translates to:
  /// **'Playlist \"{name}\" already exists, pick it from the list'**
  String songOptionsPlaylistExists(String name);

  /// No description provided for @songOptionsCreatePlaylistFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create playlist: {error}'**
  String songOptionsCreatePlaylistFailed(String error);

  /// No description provided for @librarySortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get librarySortBy;

  /// No description provided for @librarySortTitleAsc.
  ///
  /// In en, this message translates to:
  /// **'Title ↑'**
  String get librarySortTitleAsc;

  /// No description provided for @librarySortTitleDesc.
  ///
  /// In en, this message translates to:
  /// **'Title ↓'**
  String get librarySortTitleDesc;

  /// No description provided for @librarySortArtistAsc.
  ///
  /// In en, this message translates to:
  /// **'Artist ↑'**
  String get librarySortArtistAsc;

  /// No description provided for @librarySortArtistDesc.
  ///
  /// In en, this message translates to:
  /// **'Artist ↓'**
  String get librarySortArtistDesc;

  /// No description provided for @librarySortAlbumAsc.
  ///
  /// In en, this message translates to:
  /// **'Album ↑'**
  String get librarySortAlbumAsc;

  /// No description provided for @librarySortAlbumDesc.
  ///
  /// In en, this message translates to:
  /// **'Album ↓'**
  String get librarySortAlbumDesc;

  /// No description provided for @librarySortDateNewest.
  ///
  /// In en, this message translates to:
  /// **'Date ↑'**
  String get librarySortDateNewest;

  /// No description provided for @librarySortDateOldest.
  ///
  /// In en, this message translates to:
  /// **'Date ↓'**
  String get librarySortDateOldest;

  /// No description provided for @librarySortGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre ↑'**
  String get librarySortGenre;

  /// No description provided for @libraryCreatePlaylistFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a playlist first in the Collections tab'**
  String get libraryCreatePlaylistFirst;

  /// No description provided for @libraryChoosePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Choose playlist'**
  String get libraryChoosePlaylist;

  /// No description provided for @libraryAddedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'{count} songs added to {name}'**
  String libraryAddedToPlaylist(int count, String name);

  /// No description provided for @librarySelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String librarySelectedCount(int count);

  /// No description provided for @libraryAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get libraryAddToPlaylist;

  /// No description provided for @libraryAddToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get libraryAddToFavorites;

  /// No description provided for @librarySongCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String librarySongCount(int count);

  /// No description provided for @librarySongCountDuration.
  ///
  /// In en, this message translates to:
  /// **'{count} songs · {duration}'**
  String librarySongCountDuration(int count, String duration);

  /// No description provided for @libraryScanMetadata.
  ///
  /// In en, this message translates to:
  /// **'Scan metadata'**
  String get libraryScanMetadata;

  /// No description provided for @libraryStartPlaying.
  ///
  /// In en, this message translates to:
  /// **'Start playing'**
  String get libraryStartPlaying;

  /// No description provided for @libraryShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get libraryShuffle;

  /// No description provided for @libraryScanningMusic.
  ///
  /// In en, this message translates to:
  /// **'Scanning music...'**
  String get libraryScanningMusic;

  /// No description provided for @libraryNoMusic.
  ///
  /// In en, this message translates to:
  /// **'No music yet'**
  String get libraryNoMusic;

  /// No description provided for @libraryScanMusic.
  ///
  /// In en, this message translates to:
  /// **'Scan Music'**
  String get libraryScanMusic;

  /// No description provided for @libraryScanMissing.
  ///
  /// In en, this message translates to:
  /// **'Scan missing metadata'**
  String get libraryScanMissing;

  /// No description provided for @libraryRescanAll.
  ///
  /// In en, this message translates to:
  /// **'Rescan all'**
  String get libraryRescanAll;

  /// No description provided for @libraryRescanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Fetch metadata again for {count} songs?'**
  String libraryRescanConfirm(int count);

  /// No description provided for @libraryStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get libraryStart;

  /// No description provided for @libraryPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to play song: {error}'**
  String libraryPlayFailed(String error);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search music...'**
  String get searchHint;

  /// No description provided for @searchFilterSong.
  ///
  /// In en, this message translates to:
  /// **'Song'**
  String get searchFilterSong;

  /// No description provided for @searchFilterAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get searchFilterAlbum;

  /// No description provided for @searchFilterArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get searchFilterArtist;

  /// No description provided for @searchFilterFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get searchFilterFolder;

  /// No description provided for @searchFilterGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get searchFilterGenre;

  /// No description provided for @searchPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Search your music'**
  String get searchPromptTitle;

  /// No description provided for @searchPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type a title, artist, album, or more'**
  String get searchPromptSubtitle;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResults;

  /// No description provided for @searchNotFound.
  ///
  /// In en, this message translates to:
  /// **'\"{query}\" not found'**
  String searchNotFound(String query);

  /// No description provided for @searchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String searchResultCount(int count);

  /// No description provided for @searchOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get searchOther;

  /// No description provided for @albumsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No album data yet.'**
  String get albumsEmpty;

  /// No description provided for @albumsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} albums'**
  String albumsCount(int count);

  /// No description provided for @collectionsNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New Playlist'**
  String get collectionsNewPlaylist;

  /// No description provided for @collectionsPlaylistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get collectionsPlaylistNameHint;

  /// No description provided for @collectionsDeletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get collectionsDeletePlaylist;

  /// No description provided for @collectionsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String collectionsDeleteConfirm(String name);

  /// No description provided for @collectionsDeletePlaylistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist \"{name}\"?'**
  String collectionsDeletePlaylistConfirm(String name);

  /// No description provided for @collectionsFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get collectionsFavorites;

  /// No description provided for @collectionsRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get collectionsRecentlyAdded;

  /// No description provided for @collectionsRecentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get collectionsRecentlyPlayed;

  /// No description provided for @collectionsMostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get collectionsMostPlayed;

  /// No description provided for @collectionsRecentlyAddedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get collectionsRecentlyAddedTitle;

  /// No description provided for @collectionsRecentlyPlayedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get collectionsRecentlyPlayedTitle;

  /// No description provided for @collectionsMostPlayedTitle.
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get collectionsMostPlayedTitle;

  /// No description provided for @collectionsSortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name ↑'**
  String get collectionsSortNameAsc;

  /// No description provided for @collectionsSortNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Name ↓'**
  String get collectionsSortNameDesc;

  /// No description provided for @collectionsPlaylistCount.
  ///
  /// In en, this message translates to:
  /// **'{count} playlists'**
  String collectionsPlaylistCount(int count);

  /// No description provided for @collectionsPlaylistCountAlt.
  ///
  /// In en, this message translates to:
  /// **'{count} playlists'**
  String collectionsPlaylistCountAlt(int count);

  /// No description provided for @collectionsNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get collectionsNoPlaylists;

  /// No description provided for @collectionsCreatePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get collectionsCreatePlaylist;

  /// No description provided for @collectionsFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get collectionsFavoritesEmpty;

  /// No description provided for @collectionsFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on a song to add it'**
  String get collectionsFavoritesHint;

  /// No description provided for @collectionsRecentlyAddedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No songs added yet.'**
  String get collectionsRecentlyAddedEmpty;

  /// No description provided for @collectionsMostPlayedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playback data yet'**
  String get collectionsMostPlayedEmpty;

  /// No description provided for @collectionsMostPlayedHint.
  ///
  /// In en, this message translates to:
  /// **'Play songs to see statistics'**
  String get collectionsMostPlayedHint;

  /// No description provided for @foldersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load folders: {error}'**
  String foldersLoadFailed(String error);

  /// No description provided for @foldersShownAgain.
  ///
  /// In en, this message translates to:
  /// **'Folder shown again'**
  String get foldersShownAgain;

  /// No description provided for @foldersHidden.
  ///
  /// In en, this message translates to:
  /// **'Folder hidden from library'**
  String get foldersHidden;

  /// No description provided for @foldersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No music folders detected yet.'**
  String get foldersEmpty;

  /// No description provided for @foldersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} folders'**
  String foldersCount(int count);

  /// No description provided for @foldersSortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name ↑'**
  String get foldersSortNameAsc;

  /// No description provided for @foldersSortNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Name ↓'**
  String get foldersSortNameDesc;

  /// No description provided for @foldersSortCount.
  ///
  /// In en, this message translates to:
  /// **'Song count'**
  String get foldersSortCount;

  /// No description provided for @foldersSortCountShort.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get foldersSortCountShort;

  /// No description provided for @foldersHideHidden.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden folders'**
  String get foldersHideHidden;

  /// No description provided for @foldersShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden folders'**
  String get foldersShowHidden;

  /// No description provided for @foldersNoSongs.
  ///
  /// In en, this message translates to:
  /// **'No songs'**
  String get foldersNoSongs;

  /// No description provided for @foldersAllScanned.
  ///
  /// In en, this message translates to:
  /// **'All songs in this folder have already been scanned'**
  String get foldersAllScanned;

  /// No description provided for @foldersScanDone.
  ///
  /// In en, this message translates to:
  /// **'Finished scanning this folder\'s metadata'**
  String get foldersScanDone;

  /// No description provided for @foldersSortTitleAsc.
  ///
  /// In en, this message translates to:
  /// **'Title ↑'**
  String get foldersSortTitleAsc;

  /// No description provided for @foldersSortTitleDesc.
  ///
  /// In en, this message translates to:
  /// **'Title ↓'**
  String get foldersSortTitleDesc;

  /// No description provided for @foldersSortArtistAsc.
  ///
  /// In en, this message translates to:
  /// **'Artist ↑'**
  String get foldersSortArtistAsc;

  /// No description provided for @foldersSortDate.
  ///
  /// In en, this message translates to:
  /// **'Date ↑'**
  String get foldersSortDate;

  /// No description provided for @artistsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No artist data yet.'**
  String get artistsEmpty;

  /// No description provided for @artistsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} artists'**
  String artistsCount(int count);

  /// No description provided for @genresEmpty.
  ///
  /// In en, this message translates to:
  /// **'No genre data yet.'**
  String get genresEmpty;

  /// No description provided for @genresCount.
  ///
  /// In en, this message translates to:
  /// **'{count} genres'**
  String genresCount(int count);

  /// No description provided for @homeLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get homeLibrary;

  /// No description provided for @homeCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get homeCollection;

  /// No description provided for @homeDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get homeDashboard;

  /// No description provided for @homeTabSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get homeTabSongs;

  /// No description provided for @homeTabAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get homeTabAlbums;

  /// No description provided for @homeTabArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get homeTabArtists;

  /// No description provided for @homeTabFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get homeTabFolders;

  /// No description provided for @homeTabGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get homeTabGenres;

  /// No description provided for @homeTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Tab settings'**
  String get homeTabSettings;

  /// No description provided for @homeTabReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag tabs to reorder'**
  String get homeTabReorderHint;

  /// No description provided for @homeReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get homeReset;

  /// No description provided for @homeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get homeApply;

  /// No description provided for @homeMinOneTab.
  ///
  /// In en, this message translates to:
  /// **'At least 1 tab must be active'**
  String get homeMinOneTab;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeLoadLibraryFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load library: {error}'**
  String homeLoadLibraryFailed(String error);

  /// No description provided for @homePressAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press again to exit'**
  String get homePressAgainToExit;

  /// No description provided for @playerPlaybackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playerPlaybackSpeed;

  /// No description provided for @playerCannotOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Cannot open the browser'**
  String get playerCannotOpenBrowser;

  /// No description provided for @playerSearchOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open search'**
  String get playerSearchOpenFailed;

  /// No description provided for @playerLyricsFound.
  ///
  /// In en, this message translates to:
  /// **'Lyrics found!'**
  String get playerLyricsFound;

  /// No description provided for @playerLyricsNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Lyrics still not found, try adding them manually'**
  String get playerLyricsNotFoundHint;

  /// No description provided for @playerSongsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} more songs'**
  String playerSongsRemaining(int count);

  /// No description provided for @playerEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No song is playing yet'**
  String get playerEmptyState;

  /// No description provided for @playerTapToReturnToCover.
  ///
  /// In en, this message translates to:
  /// **'Tap to return to the cover'**
  String get playerTapToReturnToCover;

  /// No description provided for @playerEditLyrics.
  ///
  /// In en, this message translates to:
  /// **'Edit Lyrics'**
  String get playerEditLyrics;

  /// No description provided for @playerLyricsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Lyrics not found'**
  String get playerLyricsNotFound;

  /// No description provided for @playerTapHereToReturnToCover.
  ///
  /// In en, this message translates to:
  /// **'Tap here to return to the cover'**
  String get playerTapHereToReturnToCover;

  /// No description provided for @playerSearchOnGoogle.
  ///
  /// In en, this message translates to:
  /// **'Search on Google'**
  String get playerSearchOnGoogle;

  /// No description provided for @playerAutoSearch.
  ///
  /// In en, this message translates to:
  /// **'Auto Search'**
  String get playerAutoSearch;

  /// No description provided for @playerAddManually.
  ///
  /// In en, this message translates to:
  /// **'Add Manually'**
  String get playerAddManually;

  /// No description provided for @playerPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get playerPrevious;

  /// No description provided for @playerNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get playerNext;

  /// No description provided for @playerFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get playerFavorite;

  /// No description provided for @playerAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get playerAddToPlaylist;

  /// No description provided for @playerSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get playerSleepTimer;

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Play Queue'**
  String get queueTitle;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueEmpty;

  /// No description provided for @queueReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to reorder - swipe left to remove'**
  String get queueReorderHint;

  /// No description provided for @sleepTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTitle;

  /// No description provided for @sleepSetTimeAboveZero.
  ///
  /// In en, this message translates to:
  /// **'Set a time greater than 0'**
  String get sleepSetTimeAboveZero;

  /// No description provided for @sleepRemaining.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get sleepRemaining;

  /// No description provided for @sleepFinishLastSong.
  ///
  /// In en, this message translates to:
  /// **'Finish the last song'**
  String get sleepFinishLastSong;

  /// No description provided for @sleepSongsRemaining.
  ///
  /// In en, this message translates to:
  /// **'songs remaining'**
  String get sleepSongsRemaining;

  /// No description provided for @sleepStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get sleepStop;

  /// No description provided for @sleepTimeMode.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get sleepTimeMode;

  /// No description provided for @sleepSongMode.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get sleepSongMode;

  /// No description provided for @sleepStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get sleepStart;

  /// No description provided for @sleepSongUnit.
  ///
  /// In en, this message translates to:
  /// **'songs'**
  String get sleepSongUnit;

  /// No description provided for @sleepTimerStopped.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer stopped'**
  String get sleepTimerStopped;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
