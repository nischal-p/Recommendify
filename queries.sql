-- Query 1: Avg mood of songs in users playlist
SELECT p.name, AVG(mood) as avg_mood
FROM Playlists p
JOIN Songs s
ON p.song_id = s.spotify_id
WHERE email = 'test@email.com'
GROUP BY p.name

-- Query 2: search for song based on its mood/tempo being > some amount given
SELECT spotify_id, title, artist
FROM Songs 
WHERE tempo > 200 AND mood > 0.8
ORDER BY title
LIMIT 20


-- Query 3: find attributes of song based on some given name (search for song)
SELECT title, artist, mood, tempo, danceability
FROM Songs
WHERE title = 'After Hours'
ORDER BY title
LIMIT 10


-- Query 4: get mood of saved songs for a particular user
SELECT ss.song_id, title, artist, mood
FROM SavedSongs ss
JOIN Songs s
ON s.spotify_id = ss.song_id
WHERE ss.email = 'adam30@yahoo.com'
ORDER BY mood DESC, title

-- Query 5: get avg sentiment of each decade (DECADE: decade function)
SELECT floor(year(release_year)/10)*10 as decade, AVG(mood) as avg_mood
FROM Songs s
GROUP BY floor(year(release_year)/10)*10
ORDER BY floor(year(release_year)/10)*10;


-- Query 6: max danceability of a song from 2000s which use explicit words and are positive?
SELECT spotify_id, title, artist, MAX(danceability) as max_danceability
FROM Songs
WHERE explicit AND mood > 0.7 AND YEAR(release_year) >= 2000 AND YEAR(release_year) <= 2009
GROUP BY spotify_id 



-- Query 7: find "best songs" (songs who have higher popularity compared to their decade)
WITH DesiredSongs AS (
      SELECT spotify_id, title, artist, popularity
      FROM Songs s
      WHERE YEAR(release_year) >= 2000 AND YEAR(release_year) <= 2009
), AvgPopularityDecade AS (
    SELECT AVG(popularity) as avg_popularity
    FROM DesiredSongs
)
SELECT *
FROM DesiredSongs ds, AvgPopularityDecade apd
WHERE ds.popularity > apd.avg_popularity
LIMIT 10

-- Query 8: only select songs whose mood/popularity > avg within your saved playlists (recommendations)
WITH AllUserSavedSongs AS (
  SELECT spotify_id, ss.email, mood, popularity
  FROM Songs s
  JOIN SavedSongs ss
  ON s.spotify_id  = ss.song_id
  WHERE ss.email = 'test@email.com'
), AllUserSongs AS (
  SELECT s.spotify_id, au.email, s.mood, s.popularity
  FROM AllUserSavedSongs au
  JOIN Playlists p
  ON au.email = p.email
  JOIN Songs s
  ON au.spotify_id = s.spotify_id
), AvgMoodPopularitySongs AS (
	SELECT AVG(mood) as avg_mood, AVG(popularity) as avg_popularity
	FROM AllUserSongs
)
SELECT spotify_id, title, artist
FROM Songs s, AvgMoodPopularitySongs amp
WHERE s.mood > amp.avg_mood AND s.popularity > amp.avg_popularity
ORDER BY title
LIMIT 10



-- Query 9: avg tempo of saved songs from people born in a particular decade
WITH PeopleInDecade AS (
	SELECT email, spotify_id, dob as birth_date
	FROM Users
	WHERE dob between '1990-01-01' and '1999-12-30'
),
PeopleInDecadeSavedSongs AS (
	SELECT u.email, s.spotify_id, artist as artist, title as title, tempo, mood
	FROM PeopleInDecade u
	JOIN SavedSongs ss
	ON ss.email = u.email
	JOIN Songs s
	ON ss.song_id = s.spotify_id
)
SELECT email, AVG(tempo) as avg_tempo, AVG(mood) as avg_mood
FROM PeopleInDecadeSavedSongs
GROUP BY email


-- Query 10: for songs in playlists of people born after December 1990 with above average loudness for that decade (1990 - 1999), what is the average danceability of the songs?
WITH DesiredUsersPlaylistSongs AS (
	SELECT u.email, u.dob, p.song_id, s.title, s.artist, s.loudness
	FROM Users u
	JOIN Playlists p
	ON u.email = p.email
	JOIN Songs s
	ON s.spotify_id = p.song_id 
	WHERE u.dob >= '1990-12-01'
), AvgLoudnessDecade AS (
   SELECT AVG(loudness) as avg_loudness
   FROM Songs s
   WHERE YEAR(s.release_year) >= 1990 AND YEAR(s.release_year) <= 1999
), DesiredSongs AS (
   SELECT song_id, title, artist, loudness
   FROM DesiredUsersPlaylistSongs dps, AvgLoudnessDecade
   WHERE loudness > avg_loudness
)
SELECT * FROM DesiredSongs





-- Actual queries being used ---

/* genre recommendation unoptimized: 122.734 sec WITHOUT INDEX ON SS EMAIL*/
WITH user_saved_songs_genres AS (
	SELECT ss.song_id, ag.genre, CEIL(s.acousticness * 10) AS mood_bucket, s.popularity 
	FROM SavedSongs ss
	JOIN ArtistsSongs ats ON ats.song_id = ss.song_id
	JOIN ArtistsGenres ag ON ag.artist_id = ats.artist_id 
	JOIN Songs s ON s.spotify_id = ats.song_id 
	WHERE ss.email = "aoconnell@pfeffer.com"
),
songs_per_top_mood_bucket AS (
	SELECT ussg0.mood_bucket, COUNT(ussg0.song_id) AS num_songs
	FROM user_saved_songs_genres ussg0
	GROUP BY ussg0.mood_bucket
	ORDER BY num_songs DESC 
	LIMIT 2
),
average_saved_songs_popularity AS (
	SELECT AVG(popularity) AS avg_popularity
	FROM user_saved_songs_genres
),
unknown_genres AS (
	SELECT DISTINCT ag2.genre 
	FROM ArtistsGenres ag2 
	WHERE ag2.genre NOT IN (
		SELECT DISTINCT ussg.genre 
		FROM user_saved_songs_genres ussg
	)
),
unknown_genre_mood_range AS (
	SELECT ug.genre, CEIL(AVG(s2.acousticness) * 10) AS mood_bucket, COUNT(s2.spotify_id) AS num_songs, AVG(s2.popularity) AS genre_popularity 
	FROM ArtistsGenres ag3 
	JOIN unknown_genres ug ON ug.genre = ag3.genre 
	JOIN ArtistsSongs as2 ON as2.artist_id = ag3.artist_id 
	JOIN Songs s2 ON s2.spotify_id = as2.song_id
	GROUP BY ag3.genre 
)
SELECT ugmr.genre, ugmr.mood_bucket, ugmr.num_songs 
FROM unknown_genre_mood_range ugmr
JOIN average_saved_songs_popularity assp
JOIN songs_per_top_mood_bucket sptmb ON sptmb.mood_bucket = ugmr.mood_bucket
WHERE ugmr.genre_popularity >= assp.avg_popularity
ORDER BY num_songs DESC
LIMIT 10;

/* genre recommendation optimized: 0.015 sec WITH INDEX AND AVG GENRE INFO*/
WITH user_saved_songs_genres AS (
        SELECT ss.song_id, ag.genre, CEIL(s.acousticness * 10) AS mood_bucket, s.popularity 
        FROM SavedSongs ss
        JOIN ArtistsSongs ats ON ats.song_id = ss.song_id
        JOIN ArtistsGenres ag ON ag.artist_id = ats.artist_id 
        JOIN Songs s ON s.spotify_id = ats.song_id 
        WHERE ss.email = "${user_email}"
    ),
    songs_per_top_mood_bucket AS (
        SELECT ussg0.mood_bucket, COUNT(ussg0.song_id) AS num_songs
        FROM user_saved_songs_genres ussg0
        GROUP BY ussg0.mood_bucket
        ORDER BY num_songs DESC 
        LIMIT 2
    ),
    average_saved_songs_popularity AS (
        SELECT AVG(popularity) AS avg_popularity
        FROM user_saved_songs_genres
    ),
    unknown_genres AS (
        SELECT DISTINCT ag2.genre 
        FROM ArtistsGenres ag2 
        WHERE ag2.genre NOT IN (
            SELECT DISTINCT ussg.genre 
            FROM user_saved_songs_genres ussg
        )
    ),
    unknown_genre_mood_range AS (
        SELECT ug.genre, CEIL((g.acousticness) * 10) AS mood_bucket, g.popularity, g.num_songs
        FROM unknown_genres ug
        JOIN Genres g ON g.genre = ug.genre
    )
    SELECT ugmr.genre, ugmr.mood_bucket, ugmr.popularity
    FROM unknown_genre_mood_range ugmr
    JOIN songs_per_top_mood_bucket sptmb ON sptmb.mood_bucket = ugmr.mood_bucket
    JOIN average_saved_songs_popularity assp
    WHERE ugmr.popularity >= assp.avg_popularity
    ORDER BY ugmr.num_songs DESC
    LIMIT 10;

/* artist recommendation unoptimized (based on artists user hasn't listened to) 6.359 Sec WITHOUT INDEX ON ss.email */
WITH top_genres AS (
	SELECT ag.genre, count(ss.song_id) AS savedsongs_in_genre
	FROM SavedSongs ss 
	JOIN ArtistsSongs ats ON ats.song_id = ss.song_id
	JOIN ArtistsGenres ag ON ag.artist_id = ats.artist_id 
	WHERE ss.email = "aoconnell@pfeffer.com"
	GROUP BY ag.genre 
	ORDER BY savedsongs_in_genre DESC 
	LIMIT 20
),
unknown_artists AS (
	SELECT a.artist_id, a.name
	FROM Artists a
	WHERE a.artist_id NOT IN (
		SELECT ats2.artist_id FROM ArtistsSongs ats2
		JOIN SavedSongs ss2 ON ss2.song_id = ats2.song_id 
		WHERE ss2.email = "aoconnell@pfeffer.com"
	)
),
unknown_artists_in_top_genres AS (
	SELECT uka.artist_id, uka.name
	FROM ArtistsGenres ag2 
	JOIN top_genres tg ON tg.genre = ag2.genre
	JOIN unknown_artists uka ON uka.artist_id = ag2.artist_id
)
SELECT uatg.artist_id, uatg.name, AVG(s.popularity) AS artist_popularity 
FROM unknown_artists_in_top_genres uatg
JOIN ArtistsSongs ats3 ON ats3.artist_id = uatg.artist_id
JOIN Songs s ON s.spotify_id = ats3.song_id 
GROUP BY uatg.artist_id, uatg.name
ORDER BY artist_popularity DESC 
LIMIT 20;


/* artist recommendation: optimized (based on artists user hasn't listened to) 0.375 sec WITH INDEXES AND ArtistTable Averages*/
WITH savedsongs_genre_artist AS (
	SELECT ss.song_id, ag.genre, ats.artist_id 
	FROM SavedSongs ss 
	JOIN ArtistsSongs ats ON ats.song_id = ss.song_id
	JOIN ArtistsGenres ag ON ag.artist_id = ats.artist_id 
	WHERE ss.email = "aoconnell@pfeffer.com"
),
top_genres AS (
	SELECT genre, COUNT(*) AS songs_in_genre
	FROM savedsongs_genre_artist sga
	GROUP BY sga.genre
	ORDER BY songs_in_genre DESC 
	LIMIT 20
),
unknown_artists AS (
	SELECT a.artist_id, a.name, a.avg_popularity
	FROM Artists a
	WHERE a.artist_id NOT IN (
		SELECT DISTINCT artist_id 
		FROM savedsongs_genre_artist sga2
	)
),
unknown_artists_in_top_genres AS (
	SELECT uka.artist_id, uka.name, uka.avg_popularity
	FROM ArtistsGenres ag2 
	JOIN top_genres tg ON tg.genre = ag2.genre
	JOIN unknown_artists uka ON uka.artist_id = ag2.artist_id
)
SELECT DISTINCT uatg.artist_id, uatg.name, uatg.avg_popularity AS artist_popularity 
FROM unknown_artists_in_top_genres uatg
JOIN ArtistsSongs ats3 ON ats3.artist_id = uatg.artist_id
ORDER BY artist_popularity DESC 
LIMIT 20;


/* distribution of moods of saved songs unoptimized: 0.422 sec WITHOUT INDEX ON SS.EMAIL OR S.MOOD*/
SELECT count(ss.song_id), CEIL((mm.mood * 10)) AS mood_bucket
FROM SavedSongs ss 
JOIN Songs s ON s.spotify_id = ss.song_id 
JOIN MoodMetrics mm ON mm.song_id = ss.song_id 
WHERE ss.email = "aoconnell@pfeffer.com"
GROUP BY mood_bucket
ORDER BY mood_bucket ;

/* distribution of moods of saved songs optimized: 0.110 WITH INDEX ON SS.EMAIL OR S.MOOD*/
SELECT count(ss.song_id), CEIL((mm.mood * 10)) AS mood_bucket
FROM SavedSongs ss 
JOIN Songs s ON s.spotify_id = ss.song_id 
JOIN MoodMetrics mm ON mm.song_id = ss.song_id 
WHERE ss.email = "aoconnell@pfeffer.com"
GROUP BY mood_bucket
ORDER BY mood_bucket ;


/* distribution of dancebility of saved songs */
SELECT count(ss.song_id) AS num_songs, CEIL((s.danceability * 10)) AS dancebility_bucket
FROM SavedSongs ss 
JOIN Songs s ON s.spotify_id = ss.song_id 
WHERE ss.email = "aoconnell@pfeffer.com"
GROUP BY dancebility_bucket
ORDER BY dancebility_bucket;


/* most listened to artist, with metrics unoptimized: 0.454 sec WITHOUT INDEX*/
WITH artistid_songcount AS (
	SELECT ats.artist_id , count(ss.song_id) AS num_saved_songs
	FROM SavedSongs ss 
	JOIN ArtistsSongs ats ON ats.song_id = ss.song_id
	WHERE ss.email = "aoconnell@pfeffer.com"
	GROUP BY ats.artist_id 
)
SELECT a.name, num_saved_songs, a.popularity, a.avg_popularity
FROM artistid_songcount atsng
JOIN Artists a ON a.artist_id = atsng.artist_id
ORDER BY num_saved_songs, a.popularity DESC
LIMIT 10;

/* most listened to artist, with metrics: 0.156 sec WITH INDEX */
WITH artistid_songcount AS (
	SELECT ats.artist_id , count(ss.song_id) AS num_saved_songs
	FROM SavedSongs ss 
	JOIN ArtistsSongs ats ON ats.song_id = ss.song_id
	WHERE ss.email = "aoconnell@pfeffer.com"
	GROUP BY ats.artist_id 
)
SELECT a.name, num_saved_songs, a.popularity, a.avg_popularity
FROM artistid_songcount atsng
JOIN Artists a ON a.artist_id = atsng.artist_id
ORDER BY num_saved_songs, a.popularity DESC
LIMIT 10;

/* Danceability metrics for certain music keys of a certain mood threshold grouped by key unoptimized: 0.828 sec WITHOUT INDEX */
SELECT COUNT(s.spotify_id) as num_songs, MIN(s.danceability) AS min_danceability, 
	AVG(s.danceability) AS avg_danceability, MAX(s.danceability) AS max_danceability
FROM Songs as s
WHERE s.music_key > 3 AND s.mood < .5
GROUP BY s.music_key;

/* Danceability metrics for certain music keys of a certain mood threshold grouped by key Optimized: 0.266 sec WITH INDEX */
SELECT COUNT(s.spotify_id) as num_songs, MIN(s.danceability) AS min_danceability, 
	AVG(s.danceability) AS avg_danceability, MAX(s.danceability) AS max_danceability
FROM Songs as s
WHERE s.music_key > 3 AND s.mood < .5
GROUP BY s.music_key;

/* Get artists which are similar to the goal artist, but unkown, then return popular songs that are over 75% unoptimated 6.891 sec WITHOUT INDEX*/
/* Get artists which are similar to the goal artist, but unkown, then return popular songs that are over 75% Optimized 0.047 sec WITH INDEX*/
WITH goal_artist AS (
	SELECT a.artist_id, a.avg_tempo, a.avg_energy
	FROM Artists a
	WHERE a.name = "Fergie"
	LIMIT 1
),
similar_unknown_artists AS (
	SELECT a.artist_id, a.name
	FROM Artists a
	WHERE a.artist_id NOT IN (
		SELECT DISTINCT ga.artist_id 
		FROM goal_artist ga
	)
    AND a.avg_tempo BETWEEN 
		(SELECT ga.avg_tempo 
		FROM goal_artist ga) - 20 
        AND 
        (SELECT ga.avg_tempo 
		FROM goal_artist ga) + 20
	AND a.avg_energy BETWEEN 
		(SELECT ga.avg_energy   
		FROM goal_artist ga) - .15
        AND 
        (SELECT ga.avg_energy
		FROM goal_artist ga) + .15),
popular_songs AS (
	SELECT s.title, s.spotify_id, s.explicit, s.popularity
    FROM Songs s
    WHERE s.popularity > 75
)        
SELECT ps.title, ps.spotify_id, sua.name, ps.explicit
FROM popular_songs ps
JOIN ArtistsSongs ats ON ps.spotify_id = ats.song_id
JOIN similar_unknown_artists sua on ats.artist_id = sua.artist_id
ORDER BY ps.popularity
LIMIT 100; 

/* best songs query (unoptimized) */
WITH DesiredSongs AS (
	SELECT DISTINCT s.spotify_id, s.title, a.name, ag.genre, s.popularity
	FROM Songs s
	JOIN ArtistsSongs as2
	ON s.spotify_id = as2.song_id
	JOIN ArtistsGenres ag
	ON as2.artist_id = ag.artist_id
	JOIN Artists a
	ON as2.artist_id = a.artist_id
	WHERE ag.genre like 'pop' AND YEAR(s.release_year) >= 2000 AND YEAR(s.release_year) <= 2009
), SongsInDecade AS (
   SELECT spotify_id, popularity
   FROM Songs s
   WHERE YEAR(s.release_year) >= 2000 AND YEAR(s.release_year) <= 2009
), GenresAveragePopularity AS (
   SELECT dsg.spotify_id, dsg.genre, dsg.popularity, AVG(s.popularity) AS avg_popularity
   FROM DesiredSongs dsg
   JOIN ArtistsGenres ag
   ON dsg.genre = ag.genre
   JOIN ArtistsSongs as2 
   ON ag.artist_id = as2.artist_id
   JOIN SongsInDecade s
   ON as2.song_id = s.spotify_id
   GROUP BY dsg.spotify_id, dsg.genre
)
SELECT spotify_id, title, name, popularity
FROM DesiredSongs
WHERE spotify_id 
	NOT IN 
      (SELECT spotify_id
      FROM GenresAveragePopularity
      WHERE popularity <= avg_popularity)
ORDER BY title ASC
LIMIT 100


/* best songs query (optimized) */
WITH DesiredSongs AS (
	SELECT DISTINCT s.spotify_id, s.title, a.name, ag.genre, s.popularity
	FROM Songs s
	JOIN ArtistsSongs as2
	ON s.spotify_id = as2.song_id
	JOIN ArtistsGenres ag
	ON as2.artist_id = ag.artist_id
	JOIN Artists a
	ON as2.artist_id = a.artist_id
	WHERE ag.genre like 'pop' AND YEAR(s.release_year) >= 2010 AND YEAR(s.release_year) <= 2019
), SongsInDecade AS (
   SELECT spotify_id, popularity
   FROM Songs s
   WHERE YEAR(s.release_year) >= 2010 AND YEAR(s.release_year) <= 2019
), AvgPopularityGenre AS (
   SELECT ag.genre, AVG(s.popularity) AS avg_popularity
   FROM ArtistsGenres ag
   JOIN ArtistsSongs as2 
   ON ag.artist_id = as2.artist_id
   JOIN SongsInDecade s
   ON as2.song_id = s.spotify_id
   WHERE ag.genre = 'pop'
   GROUP BY ag.genre
), GenresAveragePopularity AS (
   SELECT dsg.spotify_id, dsg.genre, dsg.popularity, apg.avg_popularity
   FROM DesiredSongs dsg
   JOIN AvgPopularityGenre apg
   ON dsg.genre = apg.genre
)
SELECT spotify_id, title, name, popularity
FROM DesiredSongs
WHERE spotify_id 
	NOT IN 
      (SELECT spotify_id
      FROM GenresAveragePopularity
      WHERE popularity <= avg_popularity)
ORDER BY title ASC
LIMIT 100
